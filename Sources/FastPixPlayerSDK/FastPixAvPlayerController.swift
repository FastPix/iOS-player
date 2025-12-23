
import Foundation
import AVKit

public protocol FastPixPlayerDelegate: AnyObject {
    func playerDidStartPlaying(_ player: AVPlayerViewController)
    func playerDidPause(_ player: AVPlayerViewController)
    func playerDidFinish(_ player: AVPlayerViewController)
    func playerDidFail(_ player: AVPlayerViewController, error: Error)
}

//MARK: - Playlist Classes
public struct FastPixPlaylistItem {
    
    public let playbackId: String
    public let title: String
    public let description: String
    public let thumbnail: String
    public let duration: String
    public let token: String
    public let drmToken: String
    public let customDomain: String
    
    public init(
        playbackId: String,
        title: String,
        description: String = "",
        thumbnail: String = "",
        duration: String = "",
        token: String = "",
        drmToken: String = "",
        customDomain: String = ""
    ) {
        self.playbackId = playbackId
        self.title = title
        self.description = description
        self.thumbnail = thumbnail
        self.duration = duration
        self.token = token
        self.drmToken = drmToken
        self.customDomain = customDomain
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
            
            // Propagate to existing manager if already created
            allowsPictureInPicturePlayback = newValue ?? true
            if #available(iOS 14.2, *) {
                canStartPictureInPictureAutomaticallyFromInline = newValue ?? true
            } else {
                // Fallback on earlier versions
            }
            fastPixPiPManager?.isEnabled = newValue
            
            if newValue == false {
                // If disabling, stop any running PiP and mark unavailable
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
            
            if newValue {
                setupAutoPlayObserver()
            } else {
                removeAutoPlayObserver()
            }
        }
    }
    
    private func setupAutoPlayObserver() {
        
        // Remove existing observer first
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
        
        // Ensure this notification is for our player's current item
        guard let finishedItem = notification.object as? AVPlayerItem,
              finishedItem == player?.currentItem else {
            return
        }
        
        // Only auto-play if playlist exists and we can go to next
        guard hasPlaylist && canGoNext else {
            return
        }
        
        // Small delay for smooth transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if self.next() {
                self.notifyPlaylistStateChanged()
            }
        }
    }
    
    // Make sure this method exists and is accessible
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
    
    /// Clean up auto-play observers
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
    
    /// Initializes an AVPlayerViewController that's configured
    /// back it's playback performance.
    /// - Parameter playbackID: playback ID of the FastPix
    /// Asset you'd like to play
    public convenience init(playbackID: String) {
        self.init()
        
        guard !playbackID.isEmpty else {
            return
        }
        
        let playerItem = AVPlayerItem(playbackID: playbackID)
        
        let player = AVPlayer(playerItem: playerItem)
        self.player = player
    }
    
    /// Initializes an AVPlayerViewController that's configured
    /// back it's playback performance.
    /// - Parameters:
    ///   - playbackID: playback ID of the FastPix Asset
    ///   you'd like to play
    ///   - playbackOptions: playback-related options such
    ///   as custom domain and maximum resolution
    public convenience init(playbackID: String,playbackOptions: PlaybackOptions) {
        self.init()
        
        // Validate playbackID
        guard !playbackID.isEmpty else {
            return
        }
        
        let playerItem: AVPlayerItem
        
        if let drmOptions = playbackOptions.drmOptions {
            // DRM-enabled playback
            playerItem = AVPlayerItem(
                playbackID: playbackID,
                playbackOptions: playbackOptions,
                licenseServerUrl: drmOptions.licenseURL,
                certificateUrl: drmOptions.certificateURL
            )
        } else {
            // Regular playback
            playerItem = AVPlayerItem(
                playbackID: playbackID,
                playbackOptions: playbackOptions
            )
        }
        
        let player = AVPlayer(playerItem: playerItem)
        self.player = player
    }
    
    /// Prepares an already instantiated AVPlayerViewController
    /// for playback.
    /// - Parameters:
    ///   - playbackID: playback ID of the FastPix Asset
    ///   you'd like to play
    public func prepare(playbackID: String) {
        prepare(
            playerItem: AVPlayerItem(
                playbackID: playbackID
            )
        )
    }
    
    /// Prepares an already instantiated AVPlayerViewController
    /// for playback.
    /// it will be configured for playback.
    /// - Parameters:
    ///   - playbackID: playback ID of the FastPix Asset
    ///   you'd like to play
    ///   - playbackOptions: playback-related options such
    ///   as custom domain and maximum resolution
    public func prepare(playbackID: String,playbackOptions: PlaybackOptions) {
        
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
    
    internal func prepare(playerItem: AVPlayerItem) {
        //        stopObservingCurrentItem()
        if let player {
            player.replaceCurrentItem(
                with: playerItem
            )
        } else {
            player = AVPlayer(
                playerItem: playerItem
            )
        }
        observeItemStallAndFailure(playerItem)
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
        NotificationCenter.default.post(
            name: Notification.Name("PlaybackStalled"),
            object: self
        )
        
        retryResumePlaybackIfBuffering(player, attempt: 0)
    }
    
    private func retryResumePlaybackIfBuffering(_ player: AVPlayer, attempt: Int) {
        
        let maxAttempts = 10   // e.g. ~20 seconds total
            
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self else { return }
            guard let currentItem = player.currentItem else {
                return
            }
            if currentItem.isPlaybackLikelyToKeepUp {
                self.fastpixLastStalledTime = nil
                NotificationCenter.default.post(
                    name: Notification.Name("PlaybackResumed"),
                    object: self
                )
                player.play()
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
        
        loadCurrentPlaylistItem()   // rebuilds current item and calls prepare(...)
        guard let player = player else { return }
        
        // Seek close to where we were (slightly earlier for safety)
        let seconds = max(CMTimeGetSeconds(stalledTime) - 2.0, 0)
        let target = CMTimeMakeWithSeconds(seconds, preferredTimescale: stalledTime.timescale)
        
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            self?.fastpixLastStalledTime = nil
            NotificationCenter.default.post(
                name: Notification.Name("PlaybackResumed"),
                object: self
            )
            self?.player?.play()
        }
    }
    
    @objc private func handleItemFailed(_ notification: Notification) {
        guard let failedItem = notification.object as? AVPlayerItem else { return }
        guard failedItem == player?.currentItem else { return }
        
        guard let player = player,
              let item = notification.object as? AVPlayerItem,
              item == player.currentItem else { return }
        
        // If we don’t already have a stalled time, capture current position
        if fastpixLastStalledTime == nil {
            fastpixLastStalledTime = player.currentTime()
        }
        
        // Use the same logic you use for long stalls
        retryResumePlaybackIfBuffering(player, attempt: 0)
    }
}

// MARK: - Playlist Extension
extension AVPlayerViewController {
    
    /// Internal playlist manager
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
    
    /// Check if playlist is active
    public var hasPlaylist: Bool {
        return playlistManager != nil
    }
    
    public func playlistItem(at index: Int) -> FastPixPlaylistItem? {
        guard index >= 0 && index < playlistManager?.items.count ?? 0 else { return nil }
        return playlistManager?.items[index]
    }
    
    /// Current playlist item
    public var currentPlaylistItem: FastPixPlaylistItem? {
        return playlistManager?.currentItem
    }
    
    /// Hide/Show default AVPlayerViewController controls
    public var hideDefaultControls: Bool {
        get { return !showsPlaybackControls }
        set { showsPlaybackControls = !newValue }
    }
    
    /// Updates playlist navigation button visibility based on current playlist state
    /// - Parameters:
    ///   - prevButton: Previous button to show/hide
    ///   - nextButton: Next button to show/hide
    public func updatePlaylistButtonVisibility(prevButton: UIButton?, nextButton: UIButton?) {
        guard hasPlaylist else {
            // No playlist - hide both buttons
            prevButton?.isHidden = true
            nextButton?.isHidden = true
            return
        }
        
        // Update based on playlist navigation state
        prevButton?.isHidden = !canGoPrevious
        nextButton?.isHidden = !canGoNext
        
        // Keep enabled state in sync
        prevButton?.isEnabled = canGoPrevious
        nextButton?.isEnabled = canGoNext
    }
    
    // MARK: - Playlist Methods
    
    public func addPlaylist(_ items: [FastPixPlaylistItem]) {
        guard !items.isEmpty else { return }
        playlistManager = FastPixPlaylistManager(items: items)
        loadCurrentPlaylistItem()
    }
    
    /// Go to next item in playlist
    @discardableResult
    public func next() -> Bool {
        guard let manager = playlistManager,
              let _ = manager.nextItem() else { return false }
        loadCurrentPlaylistItem()
        return true
    }
    
    /// Go to previous item in playlist
    @discardableResult
    public func previous() -> Bool {
        guard let manager = playlistManager,
              let _ = manager.previousItem() else { return false }
        loadCurrentPlaylistItem()
        return true
    }
    
    /// Jump to specific index
    @discardableResult
    public func jumpTo(index: Int) -> Bool {
        guard let manager = playlistManager,
              index >= 0 && index < manager.items.count else { return false }
        
        manager.currentIndex = index
        loadCurrentPlaylistItem()
        return true
    }
    
    /// Get current playlist index
    public var currentPlaylistIndex: Int {
        return playlistManager?.currentIndex ?? 0
    }
    
    /// Get total playlist count
    public var playlistCount: Int {
        return playlistManager?.items.count ?? 0
    }
    
    /// Check if can go to next
    public var canGoNext: Bool {
        return !(playlistManager?.isAtLast ?? true)
    }
    
    /// Check if can go to previous
    public var canGoPrevious: Bool {
        return !(playlistManager?.isAtFirst ?? true)
    }
    
    private func loadCurrentPlaylistItem() {
        
        guard let current = playlistManager?.currentItem else { return }
        
        var options = PlaybackOptions()                // start with defaults
        
        
        if !current.customDomain.isEmpty {
            options.customDomain = current.customDomain
        }
        
        if !current.token.isEmpty {
            
            options.playbackPolicy = .signed(
                .init(playbackToken: current.token))
            
            let base = "https://api.fastpix.io/v1/on-demand/drm"
            let licence = "\(base)/license/fairplay/\(current.playbackId)?token=\(current.token)"
            let cert    = "\(base)/cert/fairplay/\(current.playbackId)?token=\(current.token)"
            
            if let licenceURL = URL(string: licence),
               let certURL    = URL(string: cert) {
                
                options.drmOptions = DRMOptions(
                    licenseURL: licenceURL,
                    certificateURL: certURL
                )
            }
        }
        
        prepare(
            playbackID: current.playbackId,
            playbackOptions: options
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.player?.play()
        }
    }
    
    /// Clean up playlist storage and auto-play
    public func cleanupPlaylist() {
        let id = ObjectIdentifier(self)
        playlistStorage.removeValue(forKey: id)
        cleanupAutoPlay()
    }
}

// MARK: - Playback Control Methods
extension AVPlayerViewController {
    
    /// Starts or resumes playback
    public func play() {
        player?.play()
    }
    
    /// Pauses playback at current position
    public func pause() {
        player?.pause()
    }
    
    /// Toggles between play and pause
    public func togglePlayPause() {
        if player?.timeControlStatus == .playing {
            pause()
        } else {
            play()
        }
    }
    
    /// Check if player is currently playing
    public var isPlaying: Bool {
        return player?.timeControlStatus == .playing
    }
    
    /// Check if player is paused
    public var isPaused: Bool {
        return player?.timeControlStatus == .paused
    }
}

// Add to FastPixAvPlayerController.swift
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
    
    /// Get current playback state
    public var playbackState: FastPixPlaybackState {
        guard let player = player else { return .idle }
        
        switch player.timeControlStatus {
        case .playing:
            return .playing
        case .paused:
            return player.currentItem == nil ? .stopped : .paused
        case .waitingToPlayAtSpecifiedRate:
            return .buffering
        @unknown default:
            return .idle
        }
    }
}

// Add to AVPlayerViewController extension
extension AVPlayerViewController {
    
    private static var delegateKey = "FastPixPlayerDelegate"
    
    public weak var fastPixDelegate: FastPixPlayerDelegate? {
        get {
            return objc_getAssociatedObject(self, &Self.delegateKey) as? FastPixPlayerDelegate
        }
        set {
            objc_setAssociatedObject(self, &Self.delegateKey, newValue, .OBJC_ASSOCIATION_ASSIGN)
            if newValue != nil {
                setupPlaybackObservers()
            }
        }
    }
    
    private func setupPlaybackObservers() {
        // Observe play/pause status
        player?.addObserver(self, forKeyPath: "timeControlStatus", options: [.new], context: nil)
        
        // Observe playback end
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem
        )
    }
    
    @objc private func playerDidFinishPlaying() {
        fastPixDelegate?.playerDidFinish(self)
    }
}

extension AVPlayerViewController {
    
    // MARK: - Seek Manager Integration
    
    private static var seekManagerKey = "FastPixSeekManager"
    
    public var seekManager: FastPixSeekManager? {
        get {
            return objc_getAssociatedObject(self, &Self.seekManagerKey) as? FastPixSeekManager
        }
        set {
            objc_setAssociatedObject(self, &Self.seekManagerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    /// Initialize seek manager
    public func setupSeekManager(delegate: FastPixSeekDelegate? = nil) {
        guard let player = player else { return }
        seekManager = FastPixSeekManager(player: player)
        seekManager?.delegate = delegate
    }
    
    // MARK: - Public Seek API
    
    /// Get current playback time
    public func getCurrentTime() -> TimeInterval {
        return seekManager?.getCurrentTime() ?? 0
    }
    
    /// Get video duration
    public func getDuration() -> TimeInterval {
        return seekManager?.getDuration() ?? 0
    }
    
    /// Set start time for "Continue Watching"
    public func setStartTime(_ time: TimeInterval) {
        seekManager?.setStartTime(time)
    }
    
    /// Enable automatic resume from start time
    public func enableStartTimeResume(_ enable: Bool) {
        seekManager?.enableStartTimeResume(enable)
    }
    
    /// Seek to specific time
    public func seek(to time: TimeInterval, completion: ((Bool) -> Void)? = nil) {
        seekManager?.seekTo(time: time, completion: completion)
    }
    
    /// Seek to percentage (0.0 to 1.0)
    public func seek(toPercentage percentage: Double, completion: ((Bool) -> Void)? = nil) {
        seekManager?.seekToPercentage(percentage, completion: completion)
    }
    
    /// Seek forward
    public func seekForward(by seconds: TimeInterval = 10) {
        seekManager?.seekForward(by: seconds)
    }
    
    /// Seek backward
    public func seekBackward(by seconds: TimeInterval = 10) {
        seekManager?.seekBackward(by: seconds)
    }
}

// MARK: - Fullscreen & PiP Extensions for AVPlayerViewController

private struct FastPixAssociatedKeys {
    static var fullscreenManager = "fastpix_fullscreen_manager"
    static var pipManager = "fastpix_pip_manager"
}

extension AVPlayerViewController {
    
    // Fullscreen manager accessor (stored via associated object)
    private var fastPixFullscreenManager: FastPixFullscreenManager? {
        get {
            return objc_getAssociatedObject(self, &FastPixAssociatedKeys.fullscreenManager) as? FastPixFullscreenManager
        }
        set {
            objc_setAssociatedObject(self, &FastPixAssociatedKeys.fullscreenManager, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    // PiP manager accessor (stored via associated object)
    private var fastPixPiPManager: FastPixPiPManager? {
        get {
            return objc_getAssociatedObject(self, &FastPixAssociatedKeys.pipManager) as? FastPixPiPManager
        }
        set {
            objc_setAssociatedObject(self, &FastPixAssociatedKeys.pipManager, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    // MARK: - Fullscreen APIs
    
    /// Setup fullscreen support for this AVPlayerViewController.
    /// - Parameters:
    ///   - parent: the containing UIViewController (usually the VC that hosts this AVPlayerViewController)
    ///   - container: the UIView that contains the player view and custom controls (playerView).
    /// Note: Fullscreen manager moves `container` to a fullscreen UIWindow when toggled.
    public func setupFullscreen(parent: UIViewController, container: UIView) {
        let fs = FastPixFullscreenManager(playerView: container, parentViewController: parent)
        fs.delegate = self
        fastPixFullscreenManager = fs
    }
    
    public func toggleFullscreen() {
        fastPixFullscreenManager?.toggleFullscreen()
    }
    
    public func enterFullscreen() {
        fastPixFullscreenManager?.enterFullscreen()
    }
    
    public func exitFullscreen() {
        fastPixFullscreenManager?.exitFullscreen()
    }
    
    public func isFullscreen() -> Bool {
        return fastPixFullscreenManager?.isFullscreen() ?? false
    }
    
    public func setFullscreenAutoRotate(enabled: Bool) {
        fastPixFullscreenManager?.setFullscreenAutoRotate(enabled: enabled)
    }
    
    public func setControlAutoHideTimeout(seconds: Double) {
        fastPixFullscreenManager?.setControlAutoHideTimeout(seconds: seconds)
    }
    
    // MARK: - PiP APIs
    
    public func setupPiP(parent: UIViewController) {
        guard enablePiP else {
            return
        }
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
        fastpix_attachPlayerLayerIfNeeded()
        guard let realLayer = fastpixPlayerLayer else {
            return
        }
        
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
    
    public func togglePiP() {
        guard enablePiP else {
            return
        }
        fastPixPiPManager?.togglePiP()
    }
    
    public func enterPiP() {
        fastPixPiPManager?.enterPiP()
    }
    
    public func exitPiP() {
        fastPixPiPManager?.exitPiP()
    }
    
    public func isPiPAvailable() -> Bool {
        return fastPixPiPManager?.isPiPAvailable() ?? false
    }
    
    public func isPiPActive() -> Bool {
        return fastPixPiPManager?.isPiPActive() ?? false
    }
    
    public func setPiPAudioBehavior(mixWithOthers: Bool) {
        fastPixPiPManager?.setPiPAudioBehavior(mixWithOthers: mixWithOthers)
    }
}

// MARK: - FastPixFullscreenDelegate & FastPixPiPDelegate bridging
extension AVPlayerViewController: FastPixFullscreenDelegate, FastPixPiPDelegate {
    
    // Fullscreen
    public func onFullscreenEnter() {
        NotificationCenter.default.post(name: Notification.Name("FastPixFullscreenDidEnterNotification"), object: self)
    }
    
    public func onFullscreenExit() {
        NotificationCenter.default.post(name: Notification.Name("FastPixFullscreenDidExitNotification"), object: self)
    }
    
    public func onFullscreenStateChanged(isFullscreen: Bool) {
        NotificationCenter.default.post(name: Notification.Name("FastPixFullscreenStateChangedNotification"),
                                        object: self,
                                        userInfo: ["isFullscreen": isFullscreen])
    }
    
    public func onFullscreenOrientationChanged(isLandscape: Bool) {
        // provide a notification if consumers care about orientation while in fullscreen
        NotificationCenter.default.post(name: Notification.Name("FastPixFullscreenOrientationChangedNotification"),
                                        object: self,
                                        userInfo: ["isLandscape": isLandscape])
    }
    
    // PiP
    public func onPiPEnter() {
        NotificationCenter.default.post(name: Notification.Name("FastPixPiPDidEnterNotification"), object: self)
    }
    
    public func onPiPExit() {
        NotificationCenter.default.post(name: Notification.Name("FastPixPiPDidExitNotification"), object: self)
    }
    
    public func onPiPStateChanged(isActive: Bool) {
        NotificationCenter.default.post(name: Notification.Name("FastPixPiPStateChangedNotification"),
                                        object: self,
                                        userInfo: ["isActive": isActive])
    }
    
    public func onPiPAvailabilityChanged(isAvailable: Bool) {
        NotificationCenter.default.post(name: Notification.Name("FastPixPiPAvailabilityChangedNotification"),
                                        object: self,
                                        userInfo: ["isAvailable": isAvailable])
    }
    
    public func onPiPSessionError(error: Error) {
        NotificationCenter.default.post(name: Notification.Name("FastPixPiPSessionErrorNotification"),
                                        object: self,
                                        userInfo: ["error": error])
    }
}

extension AVPlayerViewController {
    
    private static var spritesheetManagerKey = "FastPixSpritesheetManagerKey"
    
    // Make this private, not public
    public var fastpixSpritesheetManager: FastPixSpritesheetManager? {
        get {
            objc_getAssociatedObject(self, &Self.spritesheetManagerKey) as? FastPixSpritesheetManager
        }
        set {
            objc_setAssociatedObject(
                self,
                &Self.spritesheetManagerKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    
    // MARK: - Public Spritesheet API
    
    public func loadSpritesheet(
        url: URL? = nil,
        previewEnable: Bool = true,
        config: FastPixSeekPreviewConfig
    ) {
        guard previewEnable else {
            fastpixSpritesheetManager?.previewMode = .timestamp
            return
        }
        if fastpixSpritesheetManager == nil {
            fastpixSpritesheetManager = FastPixSpritesheetManager(player: player)
        }
        fastpixSpritesheetManager?.load(url: url, config: config)
    }
    
    public func setFallbackMode(_ mode: FastPixPreviewFallbackMode) {
        if fastpixSpritesheetManager == nil {
            fastpixSpritesheetManager = FastPixSpritesheetManager(player: player)
        }
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
        guard let manager = fastpixSpritesheetManager else {
            return (nil, true) // no manager -> timestamp
        }
        
        switch manager.previewMode {
        case .thumbnail:
            if let image = manager.thumbnail(for: time) {
                return (image, false)
            } else {
                // fallback decision
                return (nil, manager.fallbackMode == .timestamp)
            }
            
        case .timestamp:
            return (nil, manager.fallbackMode == .timestamp)
        }
    }
}
