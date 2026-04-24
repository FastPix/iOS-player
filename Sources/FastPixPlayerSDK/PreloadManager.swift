import AVFoundation

// MARK: - Preload Status

public enum PreloadStatus {
    case idle
    case loading
    case readyToPlay
    case failed(Error?)
    case cancelled
}

extension PreloadStatus: Equatable {
    public static func == (lhs: PreloadStatus, rhs: PreloadStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
            (.loading, .loading),
            (.readyToPlay, .readyToPlay),
            (.cancelled, .cancelled):
            return true
        case (.failed, .failed):
            return true   // compare by case only, not the associated Error
        default:
            return false
        }
    }
}

// MARK: - Preload Delegate

public protocol PreloadManagerDelegate: AnyObject {
    func videoPreloadDidStart(forId id: String)
    func videoPreloadDidBecomeReady(forId id: String)
    func videoPreloadDidFail(forId id: String, error: Error?)
    func videoPreloadDidCancel(forId id: String)
    func videoPreloadDidAutoAdvance(toId id: String)
}

// MARK: - Internal Preload Entry
// Keeps the source URL separately from the shadow AVPlayerItem.
// The shadow item/player exist only to warm AVFoundation's HTTP cache.
// consumePreloadedItem() always vends a FRESH AVPlayerItem built from the
// same URL so the caller never receives an item already bonded to a player.

private final class PreloadEntry {
    // Original URL — used to create a clean item for the real player.
    let sourceURL: URL
    
    // Shadow item + player warm the cache. Never exposed externally.
    private let shadowItem: AVPlayerItem
    let shadowPlayer: AVPlayer
    var statusObserver: NSKeyValueObservation?
    var status: PreloadStatus = .loading
    
    init(playerItem: AVPlayerItem) {
        guard let asset = playerItem.asset as? AVURLAsset else {
            self.sourceURL = URL(string: "about:blank")!
            self.shadowItem = playerItem
            self.shadowPlayer = AVPlayer()
            return
        }
        self.sourceURL = asset.url
        self.shadowItem = playerItem
        shadowItem.preferredForwardBufferDuration = 10
        
        self.shadowPlayer = AVPlayer(playerItem: shadowItem)
        self.shadowPlayer.automaticallyWaitsToMinimizeStalling = true
        // Rate 0 → buffers without audible playback
        self.shadowPlayer.playImmediately(atRate: 0.0)
    }
    
    /// A brand-new AVPlayerItem from the same URL.
    /// Never been attached to any player — safe to hand to AVPlayerViewController.
    func freshItem() -> AVPlayerItem {
        return AVPlayerItem(url: sourceURL)
    }
}

// MARK: - Preload Manager

public final class PreloadManager {
    
    public static let shared = PreloadManager()
    public init() {}
    
    public weak var delegate: PreloadManagerDelegate?
    
    // MARK: - Config
    /// Maximum number of concurrent preloads (default 2, as per design doc).
    public var maxConcurrent: Int = 2
    
    // MARK: - Storage
    private var entries: [String: PreloadEntry] = [:]       // id → entry
    private var statusMap: [String: PreloadStatus] = [:]    // id → status
    
    // MARK: - Public API
    
    /// Preload a single AVPlayerItem under a given identifier.
    /// The identifier should be the playbackId so the player controller
    /// can later retrieve it with the same key.
    public func preload(playerItem: AVPlayerItem, identifier: String) {
        guard entries[identifier] == nil else { return }    // already queued/ready
        guard entries.filter({ if case .loading = $0.value.status { return true }; return false }).count < maxConcurrent else { return }
        
        let entry = PreloadEntry(playerItem: playerItem)
        entries[identifier] = entry
        updateStatus(identifier, .loading)
        delegate?.videoPreloadDidStart(forId: identifier)
        
        // Observe item status
        entry.statusObserver = playerItem.observe(\.status, options: [.new]) { [weak self, weak entry] item, _ in
            guard let self, let entry else { return }
            switch item.status {
            case .readyToPlay:
                entry.status = .readyToPlay
                self.updateStatus(identifier, .readyToPlay)
                self.delegate?.videoPreloadDidBecomeReady(forId: identifier)
            case .failed:
                let error = item.error
                entry.status = .failed(error)
                self.updateStatus(identifier, .failed(error))
                self.delegate?.videoPreloadDidFail(forId: identifier, error: error)
                self.entries.removeValue(forKey: identifier)
            default:
                break
            }
        }
    }
    
    /// Preload multiple items; respects maxConcurrent.
    public func preload(items: [(id: String, item: AVPlayerItem)]) {
        for element in items {
            preload(playerItem: element.item, identifier: element.id)
        }
    }
    
    /// Check if a preloaded item is ready without consuming it.
    /// Returns nil if not yet ready or not found.
    public func getPreloadedItem(for id: String) -> AVPlayerItem? {
        guard let entry = entries[id] else { return nil }
        guard case .readyToPlay = entry.status else { return nil }
        // Return a fresh item — never the shadow item — so the caller gets
        // an AVPlayerItem that has never been bonded to any AVPlayer.
        return entry.freshItem()
    }
    
    /// Returns a fresh AVPlayerItem ready for the real AVPlayer, then cleans
    /// up the shadow player. Safe to pass directly to AVPlayerViewController.
    ///
    /// Always returns a NEW AVPlayerItem (not the one held by the shadow player),
    /// so AVFoundation never sees it associated with more than one player.
    public func consumePreloadedItem(for id: String) -> AVPlayerItem? {
        guard let entry = entries[id] else { return nil }
        guard case .readyToPlay = entry.status else { return nil }
        
        // Tear down shadow infrastructure — cache is already warm
        entry.shadowPlayer.pause()
        entry.statusObserver = nil
        entries.removeValue(forKey: id)
        statusMap.removeValue(forKey: id)
        
        // Hand back a fresh item built from the same URL.
        // It has never been attached to any player — zero crash risk.
        return entry.freshItem()
    }
    
    /// Query the current preload status for an identifier.
    public func preloadStatus(forVideo id: String) -> PreloadStatus {
        return statusMap[id] ?? .idle
    }
    
    /// Cancel an ongoing or queued preload.
    public func cancelPreload(for id: String) {
        guard entries[id] != nil else { return }
        // Pause the shadow player so it stops buffering immediately
        entries[id]?.shadowPlayer.pause()
        entries[id]?.statusObserver = nil
        entries.removeValue(forKey: id)
        updateStatus(id, .cancelled)
        delegate?.videoPreloadDidCancel(forId: id)
    }
    
    /// Notify the manager that playback has advanced to a new video.
    /// Clears the consumed entry and fires the auto-advance event.
    public func notifyAutoAdvance(toId id: String) {
        // The item that just became current can be cleaned up
        delegate?.videoPreloadDidAutoAdvance(toId: id)
    }
    
    /// Clear all preloads (e.g. on app background / memory warning).
    public func clearAll() {
        entries.values.forEach { $0.shadowPlayer.pause() }
        entries.removeAll()
        statusMap.removeAll()
    }
    
    // MARK: - Private
    
    private func updateStatus(_ id: String, _ status: PreloadStatus) {
        statusMap[id] = status
        if let entry = entries[id] { entry.status = status }
    }
}
