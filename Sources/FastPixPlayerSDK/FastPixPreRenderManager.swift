import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Pre-render Status
//
// Distinct from `PreloadStatus` (Decision 4 in design.md): pre-rendering adds a
// `.buffering` sub-state (bytes warm, first frame not yet decoded) and an explicit
// `.frameReady` state so the "picture is ready" moment — the whole point of the
// feature — is observable and testable.

public enum PreRenderStatus {
    /// No pre-render scheduled for this id.
    case idle
    /// Shadow item created; asset still loading.
    case loading
    /// Asset ready to play; first displayable frame not yet decoded.
    case buffering
    /// First displayable frame decoded and retained — promotion is now instant.
    case frameReady
    case failed(Error?)
    case cancelled
}

extension PreRenderStatus: Equatable {
    public static func == (lhs: PreRenderStatus, rhs: PreRenderStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.loading, .loading),
             (.buffering, .buffering),
             (.frameReady, .frameReady),
             (.cancelled, .cancelled):
            return true
        case (.failed, .failed):
            return true   // compare by case only, not the associated Error (match PreloadStatus)
        default:
            return false
        }
    }
}

// MARK: - Pre-render Delegate
// Mirrors `PreloadManagerDelegate` so controller wiring and host mental model stay consistent.

public protocol FastPixPreRenderManagerDelegate: AnyObject {
    func videoPreRenderDidStart(forId id: String)
    func videoPreRenderDidBecomeReady(forId id: String)
    func videoPreRenderDidFail(forId id: String, error: Error?)
    func videoPreRenderDidCancel(forId id: String)
}

// MARK: - Internal Pre-render Entry
//
// Follows PreloadManager's shadow-then-fresh pattern: a shadow item/player warm the
// pipeline and drive decode, but `freshItem()` always vends a brand-new AVPlayerItem
// from the same URL so the caller never receives an item already bonded to a player
// (avoids AVFoundation single-owner violations). Adds an AVPlayerItemVideoOutput to
// pull and retain the first displayable CVPixelBuffer (Decision 1, Option A).

private final class PreRenderEntry {
    let sourceURL: URL
    let isDRM: Bool

    private let shadowItem: AVPlayerItem
    let shadowPlayer: AVPlayer
    let videoOutput: AVPlayerItemVideoOutput

    var statusObserver: NSKeyValueObservation?
    /// Polls for the first decoded frame after the item is ready to play.
    var frameTimer: Timer?
    var status: PreRenderStatus = .loading

    /// The retained first displayable frame. Its presence is proof-of-decode and it
    /// can be vended as a one-frame bridging poster to mask the real item's first decode.
    private(set) var firstFrame: CVPixelBuffer?

    init(playerItem: AVPlayerItem) {
        // Extract the source URL for fresh-item vending; fall back gracefully.
        if let asset = playerItem.asset as? AVURLAsset {
            self.sourceURL = asset.url
        } else {
            self.sourceURL = URL(string: "about:blank")!
        }
        // Decision 3: DRM first-frame decode is out of scope for v1. Detect protection so
        // the manager can degrade to preload-only rather than spinning a decode that needs
        // an attached content key.
        self.isDRM = playerItem.asset.hasProtectedContent

        self.shadowItem = playerItem
        shadowItem.preferredForwardBufferDuration = 10

        // BGRA output — a widely supported pixel format for a retained bridging frame.
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        self.videoOutput = AVPlayerItemVideoOutput(pixelBufferAttributes: attrs)
        shadowItem.add(videoOutput)

        self.shadowPlayer = AVPlayer(playerItem: shadowItem)
        self.shadowPlayer.automaticallyWaitsToMinimizeStalling = true
        // Rate 0 → establishes the decode pipeline without audible playback.
        self.shadowPlayer.playImmediately(atRate: 0.0)
    }

    /// Attempts to pull and retain the first displayable frame at (or near) time 0.
    /// Returns true once a frame has been captured.
    @discardableResult
    func captureFirstFrameIfAvailable() -> Bool {
        if firstFrame != nil { return true }
        let time = shadowItem.currentTime()
        guard videoOutput.hasNewPixelBuffer(forItemTime: time),
              let buffer = videoOutput.copyPixelBuffer(forItemTime: time, itemTimeForDisplay: nil)
        else { return false }
        firstFrame = buffer
        return true
    }

    /// A brand-new AVPlayerItem from the same URL. Never attached to any player —
    /// safe to hand to the visible AVPlayer/AVPlayerViewController.
    ///
    /// Rebuilt through the back buffer for the same reason as `PreloadManager.freshItem()`: with the
    /// back buffer on, `sourceURL` carries the custom scheme, and an item built from it without the
    /// resource-loader delegate cannot be resolved by AVFoundation at all.
    func freshItem() -> AVPlayerItem {
        return AVPlayerItem(asset: FastPixBackBufferManager.shared.makeAsset(rebuildingFrom: sourceURL))
    }

    /// Tear down the shadow decode pipeline and release the retained frame.
    func teardown() {
        frameTimer?.invalidate()
        frameTimer = nil
        statusObserver = nil
        shadowPlayer.pause()
        shadowItem.remove(videoOutput)
        firstFrame = nil
    }
}

// MARK: - Pre-render Manager

public final class FastPixPreRenderManager {

    public static let shared = FastPixPreRenderManager()
    public init() {
        #if canImport(UIKit)
        observeAppLifecycle()
        #endif
    }

    public weak var delegate: FastPixPreRenderManagerDelegate?

    /// Optional preload manager used for the composition/degrade path (Requirement:
    /// "Composition with preloading"). When the bytes for an item are not yet warm — or
    /// the item is DRM-protected (v1 scope) — pre-render falls back to preload-only.
    public weak var preloadManager: PreloadManager?

    // MARK: - Config
    /// Maximum number of concurrent pre-renders (Decision 2: default 1 — heavier than
    /// preload's byte warming, and typically only the next item needs an instant picture).
    public var maxConcurrent: Int = 1

    // MARK: - Storage
    private var entries: [String: PreRenderEntry] = [:]
    private var statusMap: [String: PreRenderStatus] = [:]

    // Polling cadence for pulling the first decoded frame once the item is ready.
    private let framePollInterval: TimeInterval = 1.0 / 30.0

    // MARK: - Public API

    /// Schedule pre-rendering for a single item under `identifier` (use the playbackId so
    /// the controller can retrieve it with the same key). No-op if already queued/ready.
    public func preRender(playerItem: AVPlayerItem, identifier: String) {
        guard entries[identifier] == nil else { return }

        // Enforce the concurrency cap (Requirement: "Bounded concurrency").
        let inFlight = entries.values.filter {
            switch $0.status {
            case .loading, .buffering: return true
            default: return false
            }
        }.count
        guard inFlight < maxConcurrent else { return }

        let entry = PreRenderEntry(playerItem: playerItem)

        // Decision 3 / Requirement: DRM items degrade to preload-only, no error raised.
        if entry.isDRM {
            entry.teardown()
            preloadManager?.preload(playerItem: playerItem, identifier: identifier)
            updateStatus(identifier, .buffering)
            return
        }

        entries[identifier] = entry
        updateStatus(identifier, .loading)
        delegate?.videoPreRenderDidStart(forId: identifier)

        entry.statusObserver = playerItem.observe(\.status, options: [.new]) { [weak self, weak entry] item, _ in
            guard let self, let entry else { return }
            switch item.status {
            case .readyToPlay:
                // Bytes are warm; now wait for the first decoded frame.
                if case .loading = entry.status {
                    entry.status = .buffering
                    self.updateStatus(identifier, .buffering)
                }
                self.startFramePolling(identifier: identifier, entry: entry)
            case .failed:
                self.failEntry(identifier, entry: entry, error: item.error)
            default:
                break
            }
        }
    }

    /// Schedule pre-rendering for multiple items; respects `maxConcurrent`.
    public func preRender(items: [(id: String, item: AVPlayerItem)]) {
        for element in items {
            preRender(playerItem: element.item, identifier: element.id)
        }
    }

    /// Non-consuming check: returns a fresh, ready-to-attach item only when the first
    /// frame has been decoded (`.frameReady`); otherwise nil.
    public func getPreRenderedItem(for id: String) -> AVPlayerItem? {
        guard let entry = entries[id], case .frameReady = entry.status else { return nil }
        return entry.freshItem()
    }

    /// The retained first frame for `id`, if decoded — usable as a one-frame bridging
    /// poster on the visible layer to mask the real item's first decode.
    public func firstFramePixelBuffer(for id: String) -> CVPixelBuffer? {
        guard let entry = entries[id], case .frameReady = entry.status else { return nil }
        return entry.firstFramePixelBufferCopy
    }

    /// Consume a pre-rendered item: tear down the shadow pipeline, release the retained
    /// frame, and return a brand-new AVPlayerItem (never bonded to the shadow player).
    public func consumePreRenderedItem(for id: String) -> AVPlayerItem? {
        guard let entry = entries[id], case .frameReady = entry.status else { return nil }
        let fresh = entry.freshItem()
        entry.teardown()
        entries.removeValue(forKey: id)
        statusMap.removeValue(forKey: id)
        return fresh
    }

    /// Current pre-render status for an identifier.
    public func preRenderStatus(forId id: String) -> PreRenderStatus {
        return statusMap[id] ?? .idle
    }

    /// Cancel an in-flight or ready pre-render and release its resources.
    public func cancel(for id: String) {
        guard let entry = entries[id] else { return }
        entry.teardown()
        entries.removeValue(forKey: id)
        updateStatus(id, .cancelled)
        delegate?.videoPreRenderDidCancel(forId: id)
    }

    /// Release everything (e.g. on memory pressure / app background).
    public func clearAll() {
        entries.values.forEach { $0.teardown() }
        entries.removeAll()
        statusMap.removeAll()
    }

    // MARK: - Private

    private func startFramePolling(identifier: String, entry: PreRenderEntry) {
        entry.frameTimer?.invalidate()
        // Try immediately, then poll until the first frame is available.
        if entry.captureFirstFrameIfAvailable() {
            markReady(identifier: identifier, entry: entry)
            return
        }
        let timer = Timer(timeInterval: framePollInterval, repeats: true) { [weak self, weak entry] t in
            guard let self, let entry else { t.invalidate(); return }
            if entry.captureFirstFrameIfAvailable() {
                t.invalidate()
                self.markReady(identifier: identifier, entry: entry)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        entry.frameTimer = timer
    }

    private func markReady(identifier: String, entry: PreRenderEntry) {
        entry.frameTimer?.invalidate()
        entry.frameTimer = nil
        // The real player will re-decode from the fresh item; the shadow player's job is
        // done. Pause it to free the decoder while we retain only the first frame.
        entry.shadowPlayer.pause()
        entry.status = .frameReady
        updateStatus(identifier, .frameReady)
        delegate?.videoPreRenderDidBecomeReady(forId: identifier)
    }

    private func failEntry(_ identifier: String, entry: PreRenderEntry, error: Error?) {
        entry.teardown()
        entries.removeValue(forKey: identifier)
        updateStatus(identifier, .failed(error))
        delegate?.videoPreRenderDidFail(forId: identifier, error: error)
    }

    private func updateStatus(_ id: String, _ status: PreRenderStatus) {
        statusMap[id] = status
        entries[id]?.status = status
    }

    #if canImport(UIKit)
    private func observeAppLifecycle() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(handleResourcePressure),
                       name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleResourcePressure),
                       name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    @objc private func handleResourcePressure() {
        // Requirement: "Resource lifecycle and release" — release all and reset ready
        // items to non-ready on memory pressure / background.
        clearAll()
    }
    #endif

    deinit {
        #if canImport(UIKit)
        NotificationCenter.default.removeObserver(self)
        #endif
        clearAll()
    }
}

private extension PreRenderEntry {
    /// Deep-copyable accessor for the retained frame (returns the retained buffer; callers
    /// treat it as read-only for poster bridging).
    var firstFramePixelBufferCopy: CVPixelBuffer? { firstFrame }
}
