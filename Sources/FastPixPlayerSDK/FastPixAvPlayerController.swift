import Foundation
import AVKit
import FastpixVideoDataAVPlayer

public protocol FastPixPlayerDelegate: AnyObject {
    func playerDidStartPlaying(_ player: AVPlayerViewController)
    func playerDidPause(_ player: AVPlayerViewController)
    func playerDidFinish(_ player: AVPlayerViewController)
    func playerDidFail(_ player: AVPlayerViewController, error: Error)
    
    // New Features
    func onVolumeChanged(_ player: AVPlayerViewController, volume: Float)
    func onMute(_ player: AVPlayerViewController, isMuted: Bool)
    func onPlaybackRateChanged(_ player: AVPlayerViewController, rate: Float)
    func onCompleted(_ player: AVPlayerViewController)
}

// MARK: - Playlist Classes
public struct FastPixPlaylistItem {
    
    public let playbackId: String
    public let title: String
    public let description: String
    public let thumbnail: String
    public let duration: String
    public let token: String
    public let drmToken: String
    public let customDomain: String
    public let skipSegments: [SkipSegment]
    
    public init(
        playbackId: String,
        title: String,
        description: String = "",
        thumbnail: String = "",
        duration: String = "",
        token: String = "",
        drmToken: String = "",
        customDomain: String = "",
        skipSegments: [SkipSegment] = []
    ) {
        self.playbackId = playbackId
        self.title = title
        self.description = description
        self.thumbnail = thumbnail
        self.duration = duration
        self.token = token
        self.drmToken = drmToken
        self.customDomain = customDomain
        self.skipSegments = skipSegments
    }
}

public class FastPixPlaylistManager {
    
    public var items: [FastPixPlaylistItem]
    public var currentIndex: Int = 0
    
    public init(items: [FastPixPlaylistItem]) {
        self.items = items
    }
    
    public var currentItem: FastPixPlaylistItem? {
        guard currentIndex >= 0 && currentIndex < items.count else { return nil }
        return items[currentIndex]
    }
    
    public func nextItem() -> FastPixPlaylistItem? {
        guard currentIndex + 1 < items.count else { return nil }
        currentIndex += 1
        return currentItem
    }
    
    public func previousItem() -> FastPixPlaylistItem? {
        guard currentIndex - 1 >= 0 else { return nil }
        currentIndex -= 1
        return currentItem
    }
    
    public var isAtFirst: Bool {
        return currentIndex == 0
    }
    
    public var isAtLast: Bool {
        return currentIndex == items.count - 1
    }
}

private struct FastPixLayerKeys {
    static var playerLayer = "fastpix_player_layer"
}

private struct FastPixPiPConfigKey {
    static var pipEnabled = "fastpix_pip_enabled"
}

private struct FastPixLoopKey {
    static var isLoopEnabled = "fastpix_is_loop_enabled"
}

extension AVPlayerViewController {
    
    public var isLoopEnabled: Bool {
        get {
            (objc_getAssociatedObject(self, &FastPixLoopKey.isLoopEnabled) as? Bool) ?? false
        }
        set {
            objc_setAssociatedObject(
                self,
                &FastPixLoopKey.isLoopEnabled,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}

extension AVPlayerViewController {
    
    private var fastpixInternalLayer: AVPlayerLayer? {
        get {
            objc_getAssociatedObject(self, &FastPixLayerKeys.playerLayer) as? AVPlayerLayer
        }
        set {
            objc_setAssociatedObject(self,
                                     &FastPixLayerKeys.playerLayer,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    /// SDK-level switch to allow/disallow PiP for this player.
    public var enablePiP: Bool {
        get {
            (objc_getAssociatedObject(self, &FastPixPiPConfigKey.pipEnabled) as? Bool) ?? true
        }
        set {
            objc_setAssociatedObject(self,
                                     &FastPixPiPConfigKey.pipEnabled,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            
            allowsPictureInPicturePlayback = newValue
            if #available(iOS 14.2, *) {
                canStartPictureInPictureAutomaticallyFromInline = newValue
            }
            fastPixPiPManager?.isEnabled = newValue
            
            if newValue == false {
                fastPixPiPManager?.exitPiP()
                NotificationCenter.default.post(
                    name: Notification.Name("FastPixPiPAvailabilityChangedNotification"),
                    object: self,
                    userInfo: ["isAvailable": false]
                )
            }
        }
    }
    
    func fastpix_attachPlayerLayerIfNeeded() {
        guard let player = player else { return }
        if fastpixInternalLayer != nil { return }
        
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspect
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        fastpixInternalLayer = layer
    }
    
    public var fastpixPlayerLayer: AVPlayerLayer? {
        return fastpixInternalLayer
    }
}

// MARK: - Auto-Play Extension
extension AVPlayerViewController {
    
    private static var autoPlayObservers: [ObjectIdentifier: NSObjectProtocol] = [:]
    private static var autoPlayEnabled: [ObjectIdentifier: Bool] = [:]
    
    public var isAutoPlayEnabled: Bool {
        get {
            let id = ObjectIdentifier(self)
            return Self.autoPlayEnabled[id] ?? false
        }
        set {
            let id = ObjectIdentifier(self)
            Self.autoPlayEnabled[id] = newValue
        }
    }
    
    private func setupAutoPlayObserver() {
        removeAutoPlayObserver()
        
        let id = ObjectIdentifier(self)
        let observer = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAutoPlay(notification)
        }
        Self.autoPlayObservers[id] = observer
    }
    
    private func removeAutoPlayObserver() {
        let id = ObjectIdentifier(self)
        if let observer = Self.autoPlayObservers[id] {
            NotificationCenter.default.removeObserver(observer)
            Self.autoPlayObservers.removeValue(forKey: id)
        }
    }
    
    private func handleAutoPlay(_ notification: Notification) {
        guard let finishedItem = notification.object as? AVPlayerItem,
              finishedItem == player?.currentItem else { return }
        
        guard hasPlaylist && canGoNext else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.next() {
                self.notifyPlaylistStateChanged()
            }
        }
    }
    
    private func notifyPlaylistStateChanged() {
        NotificationCenter.default.post(
            name: Notification.Name("FastPixPlaylistStateChanged"),
            object: self,
            userInfo: [
                "currentIndex": currentPlaylistIndex,
                "canGoNext": canGoNext,
                "canGoPrevious": canGoPrevious,
                "currentItem": currentPlaylistItem as Any
            ]
        )
    }
    
    public func cleanupAutoPlay() {
        removeAutoPlayObserver()
        let id = ObjectIdentifier(self)
        Self.autoPlayEnabled.removeValue(forKey: id)
    }
}

private var playlistStorage: [ObjectIdentifier: FastPixPlaylistManager] = [:]

private struct FastPixStallKeys {
    static var lastStalledTime = "fastpix_last_stalled_time"
}

extension AVPlayerViewController {
    private var fastpixLastStalledTime: CMTime? {
        get { objc_getAssociatedObject(self, &FastPixStallKeys.lastStalledTime) as? CMTime }
        set { objc_setAssociatedObject(self, &FastPixStallKeys.lastStalledTime, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

extension AVPlayerViewController {
    
    public convenience init(playbackID: String) {
        self.init()
        guard !playbackID.isEmpty else { return }
        let playerItem = AVPlayerItem(playbackID: playbackID)
        let player = AVPlayer(playerItem: playerItem)
        self.player = player
    }
    
    public convenience init(playbackID: String, playbackOptions: PlaybackOptions) {
        self.init()
        guard !playbackID.isEmpty else { return }
        
        let playerItem: AVPlayerItem
        if let drmOptions = playbackOptions.drmOptions {
            playerItem = AVPlayerItem(
                playbackID: playbackID,
                playbackOptions: playbackOptions,
                licenseServerUrl: drmOptions.licenseURL,
                certificateUrl: drmOptions.certificateURL
            )
        } else {
            playerItem = AVPlayerItem(
                playbackID: playbackID,
                playbackOptions: playbackOptions
            )
        }
        let player = AVPlayer(playerItem: playerItem)
        self.player = player
    }
    
    public func prepare(playbackID: String) {
        prepare(playerItem: AVPlayerItem(playbackID: playbackID))
    }
    
    public func prepare(playbackID: String, playbackOptions: PlaybackOptions) {
        let playerItem: AVPlayerItem
        if let drmOptions = playbackOptions.drmOptions {
            playerItem = AVPlayerItem(
                playbackID: playbackID,
                playbackOptions: playbackOptions,
                licenseServerUrl: drmOptions.licenseURL,
                certificateUrl: drmOptions.certificateURL
            )
        } else {
            playerItem = AVPlayerItem(
                playbackID: playbackID,
                playbackOptions: playbackOptions
            )
        }
        prepare(playerItem: playerItem)
    }
    
    // MARK: - Core prepare — preload/precache integrated
    internal func prepare(playerItem: AVPlayerItem) {
        
        var itemToUse = playerItem
        
        if let urlAsset = playerItem.asset as? AVURLAsset,
           let pid = fastpixExtractPlaybackID(from: urlAsset),
           let cachedItem = preloadManager?.getPreloadedItem(for: pid) {
            itemToUse = cachedItem
            preloadManager?.notifyAutoAdvance(toId: pid)
        } else { }
        
        // Attach item to player
        if let player {
            player.replaceCurrentItem(with: itemToUse)
        } else {
            player = AVPlayer(playerItem: itemToUse)
        }
        
        // Start precaching the current item's HLS segments in the background
        if let urlAsset = itemToUse.asset as? AVURLAsset {
            precacheManager?.startPrecaching(url: urlAsset.url)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            guard let metadata = self.analyticsMetadata else { return }
            self.fastpix_attachPlayerLayerIfNeeded()
            self.analyticsManager?.startTracking(
                playerLayer: self.fastpixPlayerLayer,
                metadata: metadata
            )
        }
        
        if fastpixPlaybackRateManager == nil {
            fastpixPlaybackRateManager = FastPixPlaybackRateManager(player: player)
        } else {
            fastpixPlaybackRateManager?.attach(player: player)
        }
        
        if audioTrackManager == nil {
            audioTrackManager = FastPixAudioTrackManager(player: player)
        } else {
            audioTrackManager?.attach(player: player)
        }
        audioTrackManager?.delegate = audioTrackDelegate
        
        if subtitleTrackManager == nil {
            subtitleTrackManager = FastPixSubtitleTrackManager(player: player)
        } else {
            subtitleTrackManager?.attach(player: player)
        }
        subtitleTrackManager?.delegate = subtitleTrackDelegate
        
        if qualityManager == nil {
            qualityManager = FastPixQualityManager(player: player)
        } else {
            qualityManager?.attach(player: player)
        }
        qualityManager?.delegate = qualityDelegate
        
        setupVolumeManager()
        setupEndObserver()
        observeItemStallAndFailure(itemToUse)
        seekManager?.refreshBufferObservation()
    }
    
    private func observeItemStallAndFailure(_ item: AVPlayerItem) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePlaybackStalled(_:)),
            name: .AVPlayerItemPlaybackStalled,
            object: item
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleItemFailed(_:)),
            name: .AVPlayerItemFailedToPlayToEndTime,
            object: item
        )
    }
    
    @objc private func handlePlaybackStalled(_ notification: Notification) {
        guard let player = player,
              let item = notification.object as? AVPlayerItem,
              item == player.currentItem else { return }
        
        fastpixLastStalledTime = player.currentTime()
        NotificationCenter.default.post(name: Notification.Name("PlaybackStalled"), object: self)
        retryResumePlaybackIfBuffering(player, attempt: 0)
        qualityManager?.reapplyQualityIfNeeded()
    }
    
    private func retryResumePlaybackIfBuffering(_ player: AVPlayer, attempt: Int) {
        let maxAttempts = 10
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self else { return }
            guard let currentItem = player.currentItem else { return }
            
            if currentItem.isPlaybackLikelyToKeepUp {
                self.fastpixLastStalledTime = nil
                NotificationCenter.default.post(name: Notification.Name("PlaybackResumed"), object: self)
                self.play()
                return
            }
            if attempt + 1 >= maxAttempts {
                self.reloadCurrentPlaylistItemAfterStall()
                return
            }
            self.retryResumePlaybackIfBuffering(player, attempt: attempt + 1)
        }
    }
    
    private func reloadCurrentPlaylistItemAfterStall() {
        guard let stalledTime = fastpixLastStalledTime else {
            loadCurrentPlaylistItem()
            player?.play()
            return
        }
        loadCurrentPlaylistItem()
        guard let player = player else { return }
        let seconds = max(CMTimeGetSeconds(stalledTime) - 2.0, 0)
        let target = CMTimeMakeWithSeconds(seconds, preferredTimescale: stalledTime.timescale)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            self?.fastpixLastStalledTime = nil
            self?.qualityManager?.reapplyQualityIfNeeded()
            NotificationCenter.default.post(name: Notification.Name("PlaybackResumed"), object: self)
            self?.play()
        }
    }
    
    @objc private func handleItemFailed(_ notification: Notification) {
        guard let player = player,
              let item = notification.object as? AVPlayerItem,
              item == player.currentItem else { return }
        
        if fastpixLastStalledTime == nil {
            fastpixLastStalledTime = player.currentTime()
        }
        retryResumePlaybackIfBuffering(player, attempt: 0)
    }
}

// MARK: - Playlist Extension
extension AVPlayerViewController {
    
    private var playlistManager: FastPixPlaylistManager? {
        get {
            let id = ObjectIdentifier(self)
            return playlistStorage[id]
        }
        set {
            let id = ObjectIdentifier(self)
            if let newValue = newValue {
                playlistStorage[id] = newValue
            } else {
                playlistStorage.removeValue(forKey: id)
            }
        }
    }
    
    public var hasPlaylist: Bool { return playlistManager != nil }
    
    public func playlistItem(at index: Int) -> FastPixPlaylistItem? {
        guard index >= 0 && index < playlistManager?.items.count ?? 0 else { return nil }
        return playlistManager?.items[index]
    }
    
    public var currentPlaylistItem: FastPixPlaylistItem? { return playlistManager?.currentItem }
    
    public var hideDefaultControls: Bool {
        get { return !showsPlaybackControls }
        set { showsPlaybackControls = !newValue }
    }
    
    public func updatePlaylistButtonVisibility(prevButton: UIButton?, nextButton: UIButton?) {
        guard hasPlaylist else {
            prevButton?.isHidden = true
            nextButton?.isHidden = true
            return
        }
        prevButton?.isHidden = !canGoPrevious
        nextButton?.isHidden = !canGoNext
        prevButton?.isEnabled = canGoPrevious
        nextButton?.isEnabled = canGoNext
    }
    
    // MARK: - Playlist Methods
    
    public func addPlaylist(_ items: [FastPixPlaylistItem]) {
        guard !items.isEmpty else { return }
        setupPreloading()
        playlistManager = FastPixPlaylistManager(items: items)
        loadCurrentPlaylistItem()
    }
    
    @discardableResult
    public func next() -> Bool {
        guard let manager = playlistManager,
              let _ = manager.nextItem() else { return false }
        loadCurrentPlaylistItem()
        return true
    }
    
    @discardableResult
    public func previous() -> Bool {
        guard let manager = playlistManager,
              let _ = manager.previousItem() else { return false }
        loadCurrentPlaylistItem()
        return true
    }
    
    @discardableResult
    public func jumpTo(index: Int) -> Bool {
        guard let manager = playlistManager,
              index >= 0 && index < manager.items.count else { return false }
        manager.currentIndex = index
        loadCurrentPlaylistItem()
        return true
    }
    
    public var currentPlaylistIndex: Int { return playlistManager?.currentIndex ?? 0 }
    public var playlistCount: Int { return playlistManager?.items.count ?? 0 }
    public var canGoNext: Bool { return !(playlistManager?.isAtLast ?? true) }
    public var canGoPrevious: Bool { return !(playlistManager?.isAtFirst ?? true) }
    
    private func loadCurrentPlaylistItem() {
        
        analyticsManager?.reset()
        
        guard let current = playlistManager?.currentItem else { return }
        
        var options = PlaybackOptions()
        
        if !current.customDomain.isEmpty {
            options.customDomain = current.customDomain
        }
        
        if !current.token.isEmpty {
            options.playbackPolicy = .signed(.init(playbackToken: current.token))
            
            let base = "https://api.fastpix.co/v1/on-demand/drm"
            let licence = "\(base)/license/fairplay/\(current.playbackId)?token=\(current.token)"
            let cert    = "\(base)/cert/fairplay/\(current.playbackId)?token=\(current.token)"
            
            if let licenceURL = URL(string: licence),
               let certURL    = URL(string: cert) {
                options.drmOptions = DRMOptions(licenseURL: licenceURL, certificateURL: certURL)
            }
        }
        
        prepare(playbackID: current.playbackId, playbackOptions: options)
        
        if let playerItem = player?.currentItem {
            applySkipSegmentsWhenReady(playerItem, segments: current.skipSegments)
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if self.isAutoPlayEnabled || self.isLoopEnabled {
                self.play()
            }
        }
        
        if let manager = playlistManager {
            fastpixPreloadNextItems(from: manager, currentIndex: currentPlaylistIndex)
        }
    }
    
    public func cleanupPlaylist() {
        let id = ObjectIdentifier(self)
        playlistStorage.removeValue(forKey: id)
        cleanupAutoPlay()
    }
}

// MARK: - Preload / Precache Public API
extension AVPlayerViewController {
    
    private struct FastPixPreloadKeys {
        static var preloadManager  = "fastpix_preload_manager"
        static var precacheManager = "fastpix_precache_manager"
    }
    
    public var preloadManager: PreloadManager? {
        get { objc_getAssociatedObject(self, &FastPixPreloadKeys.preloadManager) as? PreloadManager }
        set { objc_setAssociatedObject(self, &FastPixPreloadKeys.preloadManager, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    public var precacheManager: PrecacheManager? {
        get { objc_getAssociatedObject(self, &FastPixPreloadKeys.precacheManager) as? PrecacheManager }
        set { objc_setAssociatedObject(self, &FastPixPreloadKeys.precacheManager, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    /// Lazily initialises PreloadManager and PrecacheManager.
    /// Safe to call multiple times.
    public func setupPreloading() {
        if preloadManager == nil { preloadManager = PreloadManager() }
        if precacheManager == nil { precacheManager = PrecacheManager() }
    }
    
    /// Enable or disable video segment caching.
    public func enableVideoCaching(_ enabled: Bool) {
        precacheManager?.enableVideoCaching(enabled)
    }
    
    /// Set the maximum disk cache size in megabytes (default 200 MB).
    public func configureVideoCacheSize(_ sizeInMB: Int) {
        precacheManager?.configureVideoCacheSize(sizeInMB)
    }
    
    /// Returns true if any segments are cached on disk for the given URL.
    public func isVideoCached(url: URL) -> Bool {
        return precacheManager?.isVideoCached(withURL: url) ?? false
    }
    
    /// Clear all cached segments, or segments for a specific URL.
    public func clearVideoCache(forURL url: URL? = nil) {
        if let url = url {
            precacheManager?.clearVideoCache(forURL: url)
        } else {
            precacheManager?.clearVideoCache()
        }
    }
    
    /// Returns the current preload status for a given playbackId.
    public func preloadStatus(forId id: String) -> PreloadStatus {
        return preloadManager?.preloadStatus(forVideo: id) ?? .idle
    }
    
    /// Manually cancel a preload for a given playbackId.
    public func cancelPreload(forId id: String) {
        preloadManager?.cancelPreload(for: id)
    }
    
    // MARK: - Internal Helpers
    
    /// Extracts the playbackId from an AVURLAsset URL.
    /// Pattern: https://stream.fastpix.io/{playbackId}.m3u8
    internal func fastpixExtractPlaybackID(from asset: AVURLAsset) -> String? {
        let id = asset.url.deletingPathExtension().lastPathComponent
        return id.isEmpty ? nil : id
    }
    
    /// Queues preloads for the next N items ahead of currentIndex.
    /// Cancels preloads for items that have scrolled past.
    internal func fastpixPreloadNextItems(from manager: FastPixPlaylistManager, currentIndex: Int) {
        setupPreloading()
        
        let maxAhead = preloadManager?.maxConcurrent ?? 2
        let end = min(currentIndex + maxAhead + 1, manager.items.count)
        
        guard currentIndex + 1 < manager.items.count else { return }
        
        let nextSlice = manager.items[(currentIndex + 1)..<end]
        
        for nextItem in nextSlice {
            // Only queue if genuinely idle (not already loading or ready)
            if case .idle = preloadManager?.preloadStatus(forVideo: nextItem.playbackId) ?? .idle {
                var options = PlaybackOptions()
                if !nextItem.customDomain.isEmpty { options.customDomain = nextItem.customDomain }
                if !nextItem.token.isEmpty {
                    options.playbackPolicy = .signed(.init(playbackToken: nextItem.token))
                }
                
                let item = AVPlayerItem(
                    playbackID: nextItem.playbackId,
                    playbackOptions: options
                )
                
                // This matches the lookup key used in prepare(playerItem:)
                preloadManager?.preload(playerItem: item, identifier: nextItem.playbackId)
            }
        }
        
        // Cancel stale preload for the item before current to free memory
        if currentIndex > 0 {
            let stale = manager.items[currentIndex - 1]
            if case .loading = preloadManager?.preloadStatus(forVideo: stale.playbackId) ?? .idle {
                preloadManager?.cancelPreload(for: stale.playbackId)
            }
        }
    }
}

// MARK: - Playback Control Methods
extension AVPlayerViewController {
    
    public func play() {
        player?.play()
        let rate = fastpixPlaybackRateManager?.currentRate() ?? 1.0
        player?.rate = rate
    }
    
    public func pause() {
        player?.pause()
    }
    
    public func togglePlayPause() {
        if player?.timeControlStatus == .playing { pause() } else { play() }
    }
    
    public var isPlaying: Bool { return player?.timeControlStatus == .playing }
    public var isPaused: Bool { return player?.timeControlStatus == .paused }
}

public enum FastPixPlaybackState {
    case idle
    case loading
    case playing
    case paused
    case stopped
    case buffering
    case failed(Error)
}

extension AVPlayerViewController {
    
    public var playbackState: FastPixPlaybackState {
        guard let player = player else { return .idle }
        switch player.timeControlStatus {
        case .playing:                          return .playing
        case .paused:                           return player.currentItem == nil ? .stopped : .paused
        case .waitingToPlayAtSpecifiedRate:     return .buffering
        @unknown default:                       return .idle
        }
    }
}

extension AVPlayerViewController {
    
    private static var delegateKey = "FastPixPlayerDelegate"
    
    public weak var fastPixDelegate: FastPixPlayerDelegate? {
        get { return objc_getAssociatedObject(self, &Self.delegateKey) as? FastPixPlayerDelegate }
        set { objc_setAssociatedObject(self, &Self.delegateKey, newValue, .OBJC_ASSOCIATION_ASSIGN) }
    }
    
    private func setupEndObserver() {
        NotificationCenter.default.removeObserver(
            self,
            name: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem
        )
    }
    
    @objc private func playerDidFinishPlaying() {
        if isLoopEnabled {
            player?.seek(to: .zero) { [weak self] _ in self?.play() }
        } else {
            fastPixDelegate?.playerDidFinish(self)
            fastPixDelegate?.onCompleted(self)
        }
    }
}

extension AVPlayerViewController {
    
    private static var seekManagerKey = "FastPixSeekManager"
    
    public var seekManager: FastPixSeekManager? {
        get { return objc_getAssociatedObject(self, &Self.seekManagerKey) as? FastPixSeekManager }
        set { objc_setAssociatedObject(self, &Self.seekManagerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    public func setupSeekManager(delegate: FastPixSeekDelegate? = nil) {
        guard let player = player else { return }
        seekManager = FastPixSeekManager(player: player)
        seekManager?.delegate = delegate
    }
    
    public func getCurrentTime() -> TimeInterval { return seekManager?.getCurrentTime() ?? 0 }
    public func getDuration() -> TimeInterval { return seekManager?.getDuration() ?? 0 }
    public func setStartTime(_ time: TimeInterval) { seekManager?.setStartTime(time) }
    public func enableStartTimeResume(_ enable: Bool) { seekManager?.enableStartTimeResume(enable) }
    
    public func seek(to time: TimeInterval, completion: ((Bool) -> Void)? = nil) {
        seekManager?.seekTo(time: time, completion: completion)
        qualityManager?.reapplyQualityIfNeeded()
    }
    
    public func seek(toPercentage percentage: Double, completion: ((Bool) -> Void)? = nil) {
        seekManager?.seekToPercentage(percentage, completion: completion)
    }
    
    public func seekForward(by seconds: TimeInterval = 10) { seekManager?.seekForward(by: seconds) }
    public func seekBackward(by seconds: TimeInterval = 10) { seekManager?.seekBackward(by: seconds) }
}

// MARK: - Fullscreen & PiP
private struct FastPixAssociatedKeys {
    static var fullscreenManager = "fastpix_fullscreen_manager"
    static var pipManager = "fastpix_pip_manager"
}

private struct FastPixPlaybackRateKeys {
    static var manager = "fastpix_playback_rate_manager"
}

public enum FastPixPlayerOrientation {
    case portrait
    case landscape
}

private struct FastPixSeekButtonsConfig {
    var enablePortrait: Bool = false
    var enableLandscape: Bool = true
    var forwardIncrement: TimeInterval = 10
    var backwardIncrement: TimeInterval = 10
    var enabled: Bool = true
}

private struct FastPixSeekButtonsKeys {
    static var config = "FastPixSeekButtonsConfigKey"
    static var forwardButton = "FastPixForwardButtonKey"
    static var backwardButton = "FastPixBackwardButtonKey"
    static var gesturesEnabled = "FastPixSeekGesturesEnabledKey"
    static var featureEnabled = "FastPixSeekFeatureEnabledKey"
}

private struct FastpixOverlayKeys {
    static var leftOverlay = "fastpix.leftOverlay"
    static var rightOverlay = "fastpix.rightOverlay"
}

extension AVPlayerViewController: UIGestureRecognizerDelegate {
    
    var leftSeekOverlay: UIView? {
        get { objc_getAssociatedObject(self, &FastpixOverlayKeys.leftOverlay) as? UIView }
        set { objc_setAssociatedObject(self, &FastpixOverlayKeys.leftOverlay, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    var rightSeekOverlay: UIView? {
        get { objc_getAssociatedObject(self, &FastpixOverlayKeys.rightOverlay) as? UIView }
        set { objc_setAssociatedObject(self, &FastpixOverlayKeys.rightOverlay, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    private var fastpixSeekButtonsConfig: FastPixSeekButtonsConfig {
        get { (objc_getAssociatedObject(self, &FastPixSeekButtonsKeys.config) as? FastPixSeekButtonsConfig) ?? FastPixSeekButtonsConfig() }
        set { objc_setAssociatedObject(self, &FastPixSeekButtonsKeys.config, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    public var fastpixForwardButton: UIButton? {
        get { objc_getAssociatedObject(self, &FastPixSeekButtonsKeys.forwardButton) as? UIButton }
        set { objc_setAssociatedObject(self, &FastPixSeekButtonsKeys.forwardButton, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    public var fastpixBackwardButton: UIButton? {
        get { objc_getAssociatedObject(self, &FastPixSeekButtonsKeys.backwardButton) as? UIButton }
        set { objc_setAssociatedObject(self, &FastPixSeekButtonsKeys.backwardButton, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    private var fastpixSeekGesturesEnabled: Bool {
        get { (objc_getAssociatedObject(self, &FastPixSeekButtonsKeys.gesturesEnabled) as? Bool) ?? false }
        set { objc_setAssociatedObject(self, &FastPixSeekButtonsKeys.gesturesEnabled, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    private var fastpixSeekFeatureEnabled: Bool {
        get { (objc_getAssociatedObject(self, &FastPixSeekButtonsKeys.featureEnabled) as? Bool) ?? false }
        set { objc_setAssociatedObject(self, &FastPixSeekButtonsKeys.featureEnabled, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    public func configureSeekButtons(
        enablePortrait: Bool,
        enableLandscape: Bool,
        forwardIncrement: TimeInterval,
        backwardIncrement: TimeInterval
    ) {
        guard fastpixSeekFeatureEnabled else { return }
        var config = fastpixSeekButtonsConfig
        config.enablePortrait = enablePortrait
        config.enableLandscape = enableLandscape
        config.forwardIncrement = forwardIncrement
        config.backwardIncrement = backwardIncrement
        fastpixSeekButtonsConfig = config
        fastpix_updateSeekButtonsVisibilityForCurrentOrientation()
    }
    
    public func setSeekIncrement(forward: TimeInterval, backward: TimeInterval) {
        guard fastpixSeekFeatureEnabled else { return }
        var config = fastpixSeekButtonsConfig
        config.forwardIncrement = forward
        config.backwardIncrement = backward
        fastpixSeekButtonsConfig = config
    }
    
    public func enableSeekButtons(enabled: Bool, orientation: FastPixPlayerOrientation? = nil) {
        guard fastpixSeekFeatureEnabled else { return }
        var config = fastpixSeekButtonsConfig
        config.enabled = enabled
        fastpixSeekButtonsConfig = config
        fastpix_updateSeekButtonsVisibility(for: orientation)
    }
    
    private func fastpix_ensureSeekManager() {
        if seekManager == nil, let player = player {
            seekManager = FastPixSeekManager(player: player)
        }
    }
    
    @objc private func fastpix_onForwardSeekTapped() {
        guard fastpixSeekButtonsConfig.enabled else { return }
        fastpix_ensureSeekManager()
        seekManager?.seekForward(by: fastpixSeekButtonsConfig.forwardIncrement)
    }
    
    @objc private func fastpix_onBackwardSeekTapped() {
        guard fastpixSeekButtonsConfig.enabled else { return }
        fastpix_ensureSeekManager()
        seekManager?.seekBackward(by: fastpixSeekButtonsConfig.backwardIncrement)
    }
    
    public func setupDefaultSeekButtonsUI() {
        guard fastpixSeekFeatureEnabled else { return }
        guard fastpixForwardButton == nil, fastpixBackwardButton == nil else { return }
        guard let overlay = contentOverlayView else { return }
        
        let forward = UIButton(type: .system)
        let backward = UIButton(type: .system)
        forward.setTitle("+10", for: .normal)
        backward.setTitle("-10", for: .normal)
        forward.tintColor = .white
        backward.tintColor = .white
        forward.addTarget(self, action: #selector(fastpix_onForwardSeekTapped), for: .touchUpInside)
        backward.addTarget(self, action: #selector(fastpix_onBackwardSeekTapped), for: .touchUpInside)
        fastpixForwardButton = forward
        fastpixBackwardButton = backward
        overlay.addSubview(forward)
        overlay.addSubview(backward)
        forward.translatesAutoresizingMaskIntoConstraints = false
        backward.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            forward.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            backward.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            forward.leadingAnchor.constraint(equalTo: overlay.centerXAnchor, constant: 60),
            backward.trailingAnchor.constraint(equalTo: overlay.centerXAnchor, constant: -60)
        ])
        fastpix_updateSeekButtonsVisibilityForCurrentOrientation()
    }
    
    private func fastpix_updateSeekButtonsVisibilityForCurrentOrientation() {
        let isLandscape = view.bounds.width > view.bounds.height
        fastpix_updateSeekButtonsVisibility(for: isLandscape ? .landscape : .portrait)
    }
    
    private func fastpix_updateSeekButtonsVisibility(for orientation: FastPixPlayerOrientation?) {
        let config = fastpixSeekButtonsConfig
        guard let f = fastpixForwardButton, let b = fastpixBackwardButton else { return }
        f.isHidden = !config.enabled
        b.isHidden = !config.enabled
        f.isEnabled = config.enabled
        b.isEnabled = config.enabled
    }
    
    public func fastpix_setupSeekButtons() {
        fastpixSeekFeatureEnabled = true
        guard let overlay = contentOverlayView else { return }
        fastpixForwardButton?.removeFromSuperview()
        fastpixBackwardButton?.removeFromSuperview()
        fastpixForwardButton = nil
        fastpixBackwardButton = nil
        
        let forward = UIButton(type: .system)
        let backward = UIButton(type: .system)
        
        if #available(iOS 13.0, *) {
            let cfg = UIImage.SymbolConfiguration(pointSize: 22, weight: .bold)
            forward.setImage(UIImage(systemName: "goforward.10", withConfiguration: cfg), for: .normal)
            backward.setImage(UIImage(systemName: "gobackward.10", withConfiguration: cfg), for: .normal)
        }
        
        for btn in [forward, backward] {
            btn.tintColor = .white
            btn.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            btn.layer.cornerRadius = 24
            btn.clipsToBounds = true
            btn.setTitle(nil, for: .normal)
        }
        
        forward.addTarget(self, action: #selector(fastpix_onForwardSeekTapped), for: .touchUpInside)
        backward.addTarget(self, action: #selector(fastpix_onBackwardSeekTapped), for: .touchUpInside)
        fastpixForwardButton = forward
        fastpixBackwardButton = backward
        overlay.addSubview(forward)
        overlay.addSubview(backward)
        forward.translatesAutoresizingMaskIntoConstraints = false
        backward.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            forward.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            backward.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            forward.widthAnchor.constraint(equalToConstant: 48),
            forward.heightAnchor.constraint(equalToConstant: 48),
            backward.widthAnchor.constraint(equalToConstant: 48),
            backward.heightAnchor.constraint(equalToConstant: 48),
            forward.leadingAnchor.constraint(equalTo: overlay.centerXAnchor, constant: 70),
            backward.trailingAnchor.constraint(equalTo: overlay.centerXAnchor, constant: -70)
        ])
        var config = fastpixSeekButtonsConfig
        config.enabled = true
        fastpixSeekButtonsConfig = config
    }
    
    public func enableSeekGestures(on view: UIView,
                                   forwardSeconds: TimeInterval = 10,
                                   backwardSeconds: TimeInterval = 10) {
        fastpixSeekFeatureEnabled = true
        fastpixSeekGesturesEnabled = true
        var config = fastpixSeekButtonsConfig
        config.forwardIncrement = forwardSeconds
        config.backwardIncrement = backwardSeconds
        config.enabled = true
        fastpixSeekButtonsConfig = config
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(fastpix_handleSeekDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.cancelsTouchesInView = false
        doubleTap.delegate = self
        view.addGestureRecognizer(doubleTap)
    }
    
    @objc private func fastpix_handleSeekDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard let hostView = gesture.view else { return }
        let location = gesture.location(in: hostView)
        fastpix_ensureSeekManager()
        if location.x < hostView.bounds.midX {
            seekManager?.seekBackward(by: fastpixSeekButtonsConfig.backwardIncrement)
            showSeekFeedback(isForward: false)
            NotificationCenter.default.post(name: Notification.Name("fastpixSeekGesture"), object: nil, userInfo: ["direction": "backward"])
        } else {
            seekManager?.seekForward(by: fastpixSeekButtonsConfig.forwardIncrement)
            showSeekFeedback(isForward: true)
            NotificationCenter.default.post(name: Notification.Name("fastpixSeekGesture"), object: nil, userInfo: ["direction": "forward"])
        }
    }
    
    private func showSeekFeedback(isForward: Bool) {
        let overlay = isForward ? rightSeekOverlay : leftSeekOverlay
        guard let view = overlay else { return }
        view.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        view.alpha = 0
        UIView.animate(withDuration: 0.15) { view.alpha = 1; view.transform = .identity }
        UIView.animate(withDuration: 0.25, delay: 0.45) { view.alpha = 0 }
    }
    
    private var fastPixFullscreenManager: FastPixFullscreenManager? {
        get { return objc_getAssociatedObject(self, &FastPixAssociatedKeys.fullscreenManager) as? FastPixFullscreenManager }
        set { objc_setAssociatedObject(self, &FastPixAssociatedKeys.fullscreenManager, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    private var fastPixPiPManager: FastPixPiPManager? {
        get { return objc_getAssociatedObject(self, &FastPixAssociatedKeys.pipManager) as? FastPixPiPManager }
        set { objc_setAssociatedObject(self, &FastPixAssociatedKeys.pipManager, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    public func setupFullscreen(parent: UIViewController, container: UIView) {
        let fs = FastPixFullscreenManager(playerView: container, parentViewController: parent)
        fs.delegate = self
        fastPixFullscreenManager = fs
    }
    
    public func toggleFullscreen() { fastPixFullscreenManager?.toggleFullscreen() }
    public func enterFullscreen() { fastPixFullscreenManager?.enterFullscreen() }
    public func exitFullscreen() { fastPixFullscreenManager?.exitFullscreen() }
    public func isFullscreen() -> Bool { return fastPixFullscreenManager?.isFullscreen() ?? false }
    public func setFullscreenAutoRotate(enabled: Bool) { fastPixFullscreenManager?.setFullscreenAutoRotate(enabled: enabled) }
    public func setControlAutoHideTimeout(seconds: Double) { fastPixFullscreenManager?.setControlAutoHideTimeout(seconds: seconds) }
    
    public func setupPiP(parent: UIViewController) {
        guard enablePiP else { return }
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
        fastpix_attachPlayerLayerIfNeeded()
        guard let realLayer = fastpixPlayerLayer else { return }
        let pipManager = FastPixPiPManager(playerLayer: realLayer, parent: parent)
        pipManager.delegate = self
        pipManager.isEnabled = enablePiP
        fastPixPiPManager = pipManager
        NotificationCenter.default.post(
            name: Notification.Name("FastPixPiPAvailabilityChangedNotification"),
            object: self,
            userInfo: ["isAvailable": pipManager.isPiPAvailable()]
        )
    }
    
    public func togglePiP() { guard enablePiP else { return }; fastPixPiPManager?.togglePiP() }
    public func enterPiP() { fastPixPiPManager?.enterPiP() }
    public func exitPiP() { fastPixPiPManager?.exitPiP() }
    public func isPiPAvailable() -> Bool { return fastPixPiPManager?.isPiPAvailable() ?? false }
    public func isPiPActive() -> Bool { return fastPixPiPManager?.isPiPActive() ?? false }
    public func setPiPAudioBehavior(mixWithOthers: Bool) { fastPixPiPManager?.setPiPAudioBehavior(mixWithOthers: mixWithOthers) }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { return true }
    
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldReceive touch: UITouch) -> Bool { return !(touch.view is UIControl) }
}

// MARK: - Fullscreen / PiP Delegate Bridging
extension AVPlayerViewController: FastPixFullscreenDelegate, FastPixPiPDelegate {
    
    public func onFullscreenEnter() {
        NotificationCenter.default.post(name: Notification.Name("FastPixFullscreenDidEnterNotification"), object: self)
    }
    public func onFullscreenExit() {
        NotificationCenter.default.post(name: Notification.Name("FastPixFullscreenDidExitNotification"), object: self)
    }
    public func onFullscreenStateChanged(isFullscreen: Bool) {
        NotificationCenter.default.post(name: Notification.Name("FastPixFullscreenStateChangedNotification"), object: self, userInfo: ["isFullscreen": isFullscreen])
    }
    public func onFullscreenOrientationChanged(isLandscape: Bool) {
        NotificationCenter.default.post(name: Notification.Name("FastPixFullscreenOrientationChangedNotification"), object: self, userInfo: ["isLandscape": isLandscape])
        fastpix_updateSeekButtonsVisibilityForCurrentOrientation()
    }
    public func onPiPEnter() {
        NotificationCenter.default.post(name: Notification.Name("FastPixPiPDidEnterNotification"), object: self)
    }
    public func onPiPExit() {
        NotificationCenter.default.post(name: Notification.Name("FastPixPiPDidExitNotification"), object: self)
    }
    public func onPiPStateChanged(isActive: Bool) {
        NotificationCenter.default.post(name: Notification.Name("FastPixPiPStateChangedNotification"), object: self, userInfo: ["isActive": isActive])
    }
    public func onPiPAvailabilityChanged(isAvailable: Bool) {
        NotificationCenter.default.post(name: Notification.Name("FastPixPiPAvailabilityChangedNotification"), object: self, userInfo: ["isAvailable": isAvailable])
    }
    public func onPiPSessionError(error: Error) {
        NotificationCenter.default.post(name: Notification.Name("FastPixPiPSessionErrorNotification"), object: self, userInfo: ["error": error])
    }
}

// MARK: - Spritesheet
extension AVPlayerViewController {
    
    private static var spritesheetManagerKey = "FastPixSpritesheetManagerKey"
    
    public var fastpixSpritesheetManager: FastPixSpritesheetManager? {
        get { objc_getAssociatedObject(self, &Self.spritesheetManagerKey) as? FastPixSpritesheetManager }
        set { objc_setAssociatedObject(self, &Self.spritesheetManagerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    public func loadSpritesheet(url: URL? = nil, previewEnable: Bool = true, config: FastPixSeekPreviewConfig) {
        guard previewEnable else { fastpixSpritesheetManager?.previewMode = .timestamp; return }
        if fastpixSpritesheetManager == nil { fastpixSpritesheetManager = FastPixSpritesheetManager(player: player) }
        fastpixSpritesheetManager?.load(url: url, config: config)
    }
    
    public func setFallbackMode(_ mode: FastPixPreviewFallbackMode) {
        if fastpixSpritesheetManager == nil { fastpixSpritesheetManager = FastPixSpritesheetManager(player: player) }
        fastpixSpritesheetManager?.setFallbackMode(mode)
    }
    
    public func clearSpritesheet() {
        fastpixSpritesheetManager?.clearCache()
        fastpixSpritesheetManager?.previewMode = .timestamp
    }
    
    public func getCurrentPreviewMode() -> FastPixPreviewMode {
        return fastpixSpritesheetManager?.previewMode ?? .timestamp
    }
    
    public func fastpixThumbnailForPreview(at time: TimeInterval) -> (image: UIImage?, useTimestamp: Bool) {
        guard let manager = fastpixSpritesheetManager else { return (nil, true) }
        switch manager.previewMode {
        case .thumbnail:
            if let image = manager.thumbnail(for: time) { return (image, false) }
            return (nil, manager.fallbackMode == .timestamp)
        case .timestamp:
            return (nil, manager.fallbackMode == .timestamp)
        }
    }
}

// MARK: - Playback Rate
extension AVPlayerViewController {
    
    private var fastpixPlaybackRateManager: FastPixPlaybackRateManager? {
        get { objc_getAssociatedObject(self, &FastPixPlaybackRateKeys.manager) as? FastPixPlaybackRateManager }
        set { objc_setAssociatedObject(self, &FastPixPlaybackRateKeys.manager, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    public func setPlaybackSpeed(_ rate: FastPixPlaybackRateManager.PlaybackRate) {
        fastpixPlaybackRateManager?.setPlaybackSpeed(rate)
        fastPixDelegate?.onPlaybackRateChanged(self, rate: rate.rawValue)
    }
    
    public func incrementPlaybackRate() {
        fastpixPlaybackRateManager?.incrementPlaybackRate()
        fastPixDelegate?.onPlaybackRateChanged(self, rate: currentPlaybackRate())
    }
    
    public func decrementPlaybackRate() {
        fastpixPlaybackRateManager?.decrementPlaybackRate()
        fastPixDelegate?.onPlaybackRateChanged(self, rate: currentPlaybackRate())
    }
    
    public func currentPlaybackRate() -> Float { return fastpixPlaybackRateManager?.currentRate() ?? 1.0 }
}

// MARK: - Skip Manager
private struct FastPixSkipKeys { static var skipManager = "fastpix_skip_manager" }

extension AVPlayerViewController {
    
    public var skipManager: FastPixSkipManager? {
        get { objc_getAssociatedObject(self, &FastPixSkipKeys.skipManager) as? FastPixSkipManager }
        set { objc_setAssociatedObject(self, &FastPixSkipKeys.skipManager, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    public func setupSkipManager(delegate: FastPixSkipDelegate) {
        guard let player = self.player else { return }
        if skipManager == nil { skipManager = FastPixSkipManager(player: player) }
        skipManager?.delegate = delegate
    }
}

private struct FastPixSkipObserverKeys { static var skipItemObserver = "fastpix_skip_item_observer" }

extension AVPlayerViewController {
    
    private var skipItemStatusObserver: NSKeyValueObservation? {
        get { objc_getAssociatedObject(self, &FastPixSkipObserverKeys.skipItemObserver) as? NSKeyValueObservation }
        set { objc_setAssociatedObject(self, &FastPixSkipObserverKeys.skipItemObserver, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    func applySkipSegmentsWhenReady(_ item: AVPlayerItem, segments: [SkipSegment]) {
        skipItemStatusObserver = nil
        skipManager?.setSkipSegments([])
        guard !segments.isEmpty else { return }
        if item.status == .readyToPlay { skipManager?.setSkipSegments(segments); return }
        skipItemStatusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self else { return }
            if item.status == .readyToPlay {
                DispatchQueue.main.async {
                    self.skipManager?.setSkipSegments(segments)
                    self.skipItemStatusObserver = nil
                }
            }
        }
    }
    
    public func setSkipSegments(_ segments: [SkipSegment]) { skipManager?.setSkipSegments(segments) }
    public func skipCurrentSegment() { skipManager?.skipCurrentSegment() }
}

// MARK: - Audio Track Manager
extension AVPlayerViewController {
    
    private static var audioTrackManagerKey = "FastPixAudioTrackManager"
    private static var audioTrackDelegateKey = "FastPixAudioTrackDelegate"
    
    public var audioTrackManager: FastPixAudioTrackManager? {
        get { return objc_getAssociatedObject(self, &Self.audioTrackManagerKey) as? FastPixAudioTrackManager }
        set { objc_setAssociatedObject(self, &Self.audioTrackManagerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    public weak var audioTrackDelegate: FastPixAudioTrackDelegate? {
        get { return objc_getAssociatedObject(self, &Self.audioTrackDelegateKey) as? FastPixAudioTrackDelegate }
        set { objc_setAssociatedObject(self, &Self.audioTrackDelegateKey, newValue, .OBJC_ASSOCIATION_ASSIGN) }
    }
    
    public func getAudioTracks() -> [AudioTrack] { return audioTrackManager?.fetchAudioTracks() ?? [] }
    public func getCurrentAudioTrack() -> AudioTrack? { return audioTrackManager?.getCurrentTrack() }
    
    public func setAudioTrack(trackId: String) {
        do {
            try audioTrackManager?.selectTrack(trackId: trackId)
            if let track = getCurrentAudioTrack() { audioTrackDelegate?.onAudioTrackChange(selectedTrack: track) }
        } catch {
            fastPixDelegate?.playerDidFail(self, error: error)
        }
    }
    
    public func setPreferredAudioTrack(_ languageName: String?) {
        audioTrackManager?.setPreferredAudioTrack(languageName: languageName)
    }
}

extension AVPlayerViewController: FastPixAudioTrackDelegate {
    public func onAudioTracksUpdated(tracks: [AudioTrack]) {}
    public func onAudioTrackChange(selectedTrack: AudioTrack) {}
    public func onAudioTrackFailed(error: AudioTrackError) {}
    public func onAudioTrackSwitching(isSwitching: Bool) {}
}

// MARK: - Subtitle Track Manager
extension AVPlayerViewController {
    
    private static var subtitleTrackManagerKey = "FastPixSubtitleTrackManager"
    private static var subtitleTrackDelegateKey = "FastPixSubtitleTrackDelegate"
    
    public var subtitleTrackManager: FastPixSubtitleTrackManager? {
        get { return objc_getAssociatedObject(self, &Self.subtitleTrackManagerKey) as? FastPixSubtitleTrackManager }
        set { objc_setAssociatedObject(self, &Self.subtitleTrackManagerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    public weak var subtitleTrackDelegate: FastPixSubtitleTrackDelegate? {
        get { return objc_getAssociatedObject(self, &Self.subtitleTrackDelegateKey) as? FastPixSubtitleTrackDelegate }
        set { objc_setAssociatedObject(self, &Self.subtitleTrackDelegateKey, newValue, .OBJC_ASSOCIATION_ASSIGN) }
    }
    
    public func getSubtitleTracks() -> [SubtitleTrack] { return subtitleTrackManager?.getSubtitleTracks() ?? [] }
    public func getCurrentSubtitleTrack() -> SubtitleTrack? { return subtitleTrackManager?.getCurrentSubtitleTrack() }
    
    public func setSubtitleTrack(trackId: String) {
        do { try subtitleTrackManager?.setSubtitleTrack(trackId: trackId) }
        catch { print("Subtitle switching failed:", error) }
    }
    
    public func setPreferredSubtitleTrack(_ languageName: String?) {
        subtitleTrackManager?.setPreferredSubtitleTrack(languageName: languageName)
    }
    
    public func disableSubtitles() { subtitleTrackManager?.disableSubtitles() }
}

extension AVPlayerViewController: FastPixSubtitleTrackDelegate {
    public func onSubtitlesLoaded(tracks: [SubtitleTrack]) {}
    public func onSubtitleChange(track: SubtitleTrack?) {}
    public func onSubtitlesLoadedFailed(error: SubtitleTrackError) {}
    public func onSubtitleCueChange(information: SubtitleRenderInfo) {}
}

// MARK: - Quality Manager
extension AVPlayerViewController {
    
    private static var qualityManagerKey = "FastPixQualityManagerKey"
    private static var qualityDelegateKey = "FastPixQualityDelegate"
    
    public var qualityManager: FastPixQualityManager? {
        get { return objc_getAssociatedObject(self, &Self.qualityManagerKey) as? FastPixQualityManager }
        set { objc_setAssociatedObject(self, &Self.qualityManagerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    public weak var qualityDelegate: FastPixQualityDelegate? {
        get { return objc_getAssociatedObject(self, &Self.qualityDelegateKey) as? FastPixQualityDelegate }
        set { objc_setAssociatedObject(self, &Self.qualityDelegateKey, newValue, .OBJC_ASSOCIATION_ASSIGN) }
    }
    
    public func setupQualityManager(delegate: FastPixQualityDelegate? = nil) {
        guard let player = self.player else { return }
        let manager = FastPixQualityManager(player: player)
        manager.delegate = qualityDelegate
        manager.attach(player: player)
        qualityManager = manager
    }
    
    public func getResolutionLevels() -> [QualityLevel] { return qualityManager?.getResolutionLevels() ?? [] }
    public func getCurrentResolutionLevel() -> QualityLevel? { return qualityManager?.getCurrentResolutionLevel() }
    public func setResolutionLevel(_ level: QualityLevel) { qualityManager?.setResolutionLevel(level) }
    public func setInitialResolutionLevel(_ level: QualityLevel) { qualityManager?.setInitialResolutionLevel(level) }
    public func resetToAuto() { qualityManager?.resetToAuto() }
    public func getAutoQualityLevel() -> QualityLevel? { return qualityManager?.getAutoQualityLevel() }
    public func setABREnabled(_ enabled: Bool) { qualityManager?.setABREnabled(enabled) }
    public func isABREnabled() -> Bool { return qualityManager?.isABREnabled() ?? true }
}

// MARK: - Analytics
final class FastPixAnalyticsManager {
    
    private var dataSDK = initAvPlayerTracking()
    private var isTrackingStarted = false
    
    func startTracking(playerLayer: AVPlayerLayer?, metadata: [String: Any]) {
        guard let layer = playerLayer else { return }
        guard !isTrackingStarted else { return }
        dataSDK.trackAvPlayerLayer(playerLayer: layer, customMetadata: ["data": metadata])
        isTrackingStarted = true
    }
    
    func reset() { isTrackingStarted = false }
}

private struct FastPixAnalyticsKeys {
    static var manager  = "fastpix_analytics_manager"
    static var metadata = "fastpix_analytics_metadata"
}

extension AVPlayerViewController {
    
    private var analyticsManager: FastPixAnalyticsManager? {
        get { objc_getAssociatedObject(self, &FastPixAnalyticsKeys.manager) as? FastPixAnalyticsManager }
        set { objc_setAssociatedObject(self, &FastPixAnalyticsKeys.manager, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    private var analyticsMetadata: [String: Any]? {
        get { objc_getAssociatedObject(self, &FastPixAnalyticsKeys.metadata) as? [String: Any] }
        set { objc_setAssociatedObject(self, &FastPixAnalyticsKeys.metadata, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    public func enableAnalytics(metadata: [String: Any]) {
        analyticsMetadata = enrichMetadata(metadata)
        if analyticsManager == nil { analyticsManager = FastPixAnalyticsManager() }
    }
    
    private func enrichMetadata(_ metadata: [String: Any]) -> [String: Any] {
        var enriched = metadata
        enriched["player_name"] = "AVPlayer"
        enriched["player_version"] = "1.0.0"
        enriched["player_software_name"] = "AVPlayer"
        enriched["player_software_version"] = "1.0.0"
        enriched["player_fastpix_sdk_name"] = "fastpix-ios-player"
        enriched["player_fastpix_sdk_version"] = "1.0.0"
        if enriched["video_stream_type"] == nil { enriched["video_stream_type"] = "on-demand" }
        return enriched
    }
}
