
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
        if let player {
            player.replaceCurrentItem(
                with: playerItem
            )
            
        } else {
            player = AVPlayer(
                playerItem: playerItem
            )
        }

        // MARK: - Analytics Hook
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            
            guard let self = self else { return }
            guard let metadata = self.analyticsMetadata else { return }
            
            self.fastpix_attachPlayerLayerIfNeeded()
            
            self.analyticsManager?.startTracking(
                playerLayer: self.fastpixPlayerLayer,
                metadata: metadata
            )
        }
        
        //playbackrate
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
        
        setupVolumeManager()
        setupEndObserver()
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
        
        let maxAttempts = 10
        
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
            self?.play()
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

        analyticsManager?.reset()
        
        guard let current = playlistManager?.currentItem else { return }
        
        var options = PlaybackOptions()
        
        
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
        
        // 3️⃣ Apply skip segments when item is ready
        if let playerItem = player?.currentItem {
            applySkipSegmentsWhenReady(
                playerItem,
                segments: current.skipSegments
            )
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            
            if self.isAutoPlayEnabled || self.isLoopEnabled {
                self.play()
            }
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
        
        //playbackrate
        let rate = fastpixPlaybackRateManager?.currentRate() ?? 1.0
        player?.rate = rate
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
            player?.seek(to: .zero) { [weak self] _ in
                self?.play()
            }
            return
        } else {
            fastPixDelegate?.playerDidFinish(self)
            fastPixDelegate?.onCompleted(self)
        }
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

private struct FastPixPlaybackRateKeys {
    static var manager = "fastpix_playback_rate_manager"
}

// MARK: - Forward / Backward Seek Config
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
        get {
            objc_getAssociatedObject(self, &FastpixOverlayKeys.leftOverlay) as? UIView
        }
        set {
            objc_setAssociatedObject(
                self,
                &FastpixOverlayKeys.leftOverlay,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    
    var rightSeekOverlay: UIView? {
        get {
            objc_getAssociatedObject(self, &FastpixOverlayKeys.rightOverlay) as? UIView
        }
        set {
            objc_setAssociatedObject(
                self,
                &FastpixOverlayKeys.rightOverlay,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    
    // MARK: - Forward / Backward Seek Associated Storage
    private var fastpixSeekButtonsConfig: FastPixSeekButtonsConfig {
        get {
            (objc_getAssociatedObject(self, &FastPixSeekButtonsKeys.config) as? FastPixSeekButtonsConfig)
            ?? FastPixSeekButtonsConfig()
        }
        set {
            objc_setAssociatedObject(
                self,
                &FastPixSeekButtonsKeys.config,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    
    public var fastpixForwardButton: UIButton? {
        get { objc_getAssociatedObject(self, &FastPixSeekButtonsKeys.forwardButton) as? UIButton }
        set {
            objc_setAssociatedObject(
                self,
                &FastPixSeekButtonsKeys.forwardButton,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    
    public var fastpixBackwardButton: UIButton? {
        get { objc_getAssociatedObject(self, &FastPixSeekButtonsKeys.backwardButton) as? UIButton }
        set {
            objc_setAssociatedObject(
                self,
                &FastPixSeekButtonsKeys.backwardButton,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    
    private var fastpixSeekGesturesEnabled: Bool {
        get {
            (objc_getAssociatedObject(self, &FastPixSeekButtonsKeys.gesturesEnabled) as? Bool) ?? false
        }
        set {
            objc_setAssociatedObject(
                self,
                &FastPixSeekButtonsKeys.gesturesEnabled,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    
    private var fastpixSeekFeatureEnabled: Bool {
        get {
            (objc_getAssociatedObject(self, &FastPixSeekButtonsKeys.featureEnabled) as? Bool) ?? false
        }
        set {
            objc_setAssociatedObject(
                self,
                &FastPixSeekButtonsKeys.featureEnabled,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    
    // MARK: - Forward / Backward Seek Public API
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
    
    /// setSeekIncrement(forward: TimeInterval, backward: TimeInterval)
    public func setSeekIncrement(forward: TimeInterval, backward: TimeInterval) {
        guard fastpixSeekFeatureEnabled else { return }
        var config = fastpixSeekButtonsConfig
        config.forwardIncrement = forward
        config.backwardIncrement = backward
        fastpixSeekButtonsConfig = config
    }
    
    /// enableSeekButtons(enabled: Bool, orientation: PlayerOrientation?)
    public func enableSeekButtons(enabled: Bool, orientation: FastPixPlayerOrientation? = nil) {
        guard fastpixSeekFeatureEnabled else { return }
        var config = fastpixSeekButtonsConfig
        config.enabled = enabled
        fastpixSeekButtonsConfig = config
        fastpix_updateSeekButtonsVisibility(for: orientation)
    }
    
    // MARK: - Forward / Backward Seek Logic (uses FastPixSeekManager)
    private func fastpix_ensureSeekManager() {
        if seekManager == nil, let player = player {
            let manager = FastPixSeekManager(player: player)
            seekManager = manager
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
    
    // MARK: - Seek Buttons UI
    
    /// Call once after player is ready to setup default forward/backward buttons.
    public func setupDefaultSeekButtonsUI() {
        guard fastpixSeekFeatureEnabled else { return }
        guard fastpixForwardButton == nil, fastpixBackwardButton == nil else { return }
        guard let overlay = contentOverlayView else { return }
        
        let forward = UIButton(type: .system)
        let backward = UIButton(type: .system)
        
        // Replace titles with icons as needed
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
        let orientation: FastPixPlayerOrientation = isLandscape ? .landscape : .portrait
        fastpix_updateSeekButtonsVisibility(for: orientation)
    }
    
    private func fastpix_updateSeekButtonsVisibility(for orientation: FastPixPlayerOrientation?) {
        let config = fastpixSeekButtonsConfig
        guard let f = fastpixForwardButton, let b = fastpixBackwardButton else { return }
        
        // DEBUG: always show while debugging
        f.isHidden = !config.enabled
        b.isHidden = !config.enabled
        f.isEnabled = config.enabled
        b.isEnabled = config.enabled
    }
    
    public func fastpix_setupSeekButtons() {
        fastpixSeekFeatureEnabled = true    // force feature ON
        
        guard let overlay = contentOverlayView else { return }
        
        // Always remove old buttons and recreate to avoid weird state
        fastpixForwardButton?.removeFromSuperview()
        fastpixBackwardButton?.removeFromSuperview()
        fastpixForwardButton = nil
        fastpixBackwardButton = nil
        
        let forward = UIButton(type: .system)
        let backward = UIButton(type: .system)
        
        let forwardImage: UIImage?
        let backwardImage: UIImage?
        
        if #available(iOS 13.0, *) {
            let symbolConfig = UIImage.SymbolConfiguration(pointSize: 22, weight: .bold)
            forwardImage = UIImage(systemName: "goforward.10", withConfiguration: symbolConfig)
            backwardImage = UIImage(systemName: "gobackward.10", withConfiguration: symbolConfig)
        } else {
            forwardImage = nil
            backwardImage = nil
        }
        
        forward.setImage(forwardImage, for: .normal)
        backward.setImage(backwardImage, for: .normal)
        
        forward.tintColor = .white
        backward.tintColor = .white
        forward.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        backward.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        forward.layer.cornerRadius = 24
        backward.layer.cornerRadius = 24
        forward.clipsToBounds = true
        backward.clipsToBounds = true
        
        forward.setTitle(nil, for: .normal)
        backward.setTitle(nil, for: .normal)
        
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
        
        let doubleTap = UITapGestureRecognizer(
            target: self,
            action: #selector(fastpix_handleSeekDoubleTap)
        )
        doubleTap.numberOfTapsRequired = 2
        doubleTap.cancelsTouchesInView = false
        doubleTap.delegate = self
        view.addGestureRecognizer(doubleTap)
        
    }
    
    @objc private func fastpix_handleSeekDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard let hostView = gesture.view else { return }
        
        let location = gesture.location(in: hostView)
        let midX = hostView.bounds.midX
        
        fastpix_ensureSeekManager()
        
        if location.x < midX {
            seekManager?.seekBackward(by: fastpixSeekButtonsConfig.backwardIncrement)
            showSeekFeedback(isForward: false)
            NotificationCenter.default.post(
                name: Notification.Name("fastpixSeekGesture"),
                object: nil,
                userInfo: ["direction": "backward"]
            )
        } else {
            seekManager?.seekForward(by: fastpixSeekButtonsConfig.forwardIncrement)
            showSeekFeedback(isForward: true)
            NotificationCenter.default.post(
                name: Notification.Name("fastpixSeekGesture"),
                object: nil,
                userInfo: ["direction": "forward"]
            )
        }
    }
    
    private func showSeekFeedback(isForward: Bool) {
        let overlay = isForward ? rightSeekOverlay : leftSeekOverlay
        guard let view = overlay else { return }
        
        view.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        view.alpha = 0
        
        UIView.animate(withDuration: 0.15) {
            view.alpha = 1
            view.transform = .identity
        }
        
        UIView.animate(withDuration: 0.25, delay: 0.45, options: []) {
            view.alpha = 0
        }
    }
    
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
    
    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // Allow AVPlayer gestures + your seek gesture together
        return true
    }
    
    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        
        if touch.view is UIControl {
            return false
        }
        return true
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
        
        NotificationCenter.default.post(name: Notification.Name("FastPixFullscreenOrientationChangedNotification"),
                                        object: self,
                                        userInfo: ["isLandscape": isLandscape])
        
        fastpix_updateSeekButtonsVisibilityForCurrentOrientation()
    }
    
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

extension AVPlayerViewController {
    
    private var fastpixPlaybackRateManager: FastPixPlaybackRateManager? {
        get {
            objc_getAssociatedObject(self, &FastPixPlaybackRateKeys.manager) as? FastPixPlaybackRateManager
        }
        set {
            objc_setAssociatedObject(
                self,
                &FastPixPlaybackRateKeys.manager,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    
    // MARK: - Playback Rate APIs
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
    
    public func currentPlaybackRate() -> Float {
        return fastpixPlaybackRateManager?.currentRate() ?? 1.0
    }
}

private struct FastPixSkipKeys {
    static var skipManager = "fastpix_skip_manager"
}

extension AVPlayerViewController {
    
    public var skipManager: FastPixSkipManager? {
        get {
            objc_getAssociatedObject(self, &FastPixSkipKeys.skipManager) as? FastPixSkipManager
        }
        set {
            objc_setAssociatedObject(
                self,
                &FastPixSkipKeys.skipManager,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    
    public func setupSkipManager(delegate: FastPixSkipDelegate) {
        
        guard let player = self.player else {
            return
        }
        
        // Create ONLY ONCE
        if skipManager == nil {
            skipManager = FastPixSkipManager(player: player)
        }
        skipManager?.delegate = delegate
    }
    
}

private struct FastPixSkipObserverKeys {
    static var skipItemObserver = "fastpix_skip_item_observer"
}

extension AVPlayerViewController {
    
    private var skipItemStatusObserver: NSKeyValueObservation? {
        get {
            objc_getAssociatedObject(self, &FastPixSkipObserverKeys.skipItemObserver)
            as? NSKeyValueObservation
        }
        set {
            objc_setAssociatedObject(
                self,
                &FastPixSkipObserverKeys.skipItemObserver,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    
    func applySkipSegmentsWhenReady(
        _ item: AVPlayerItem,
        segments: [SkipSegment]
    ) {
        
        // Clear previous observer + segments
        skipItemStatusObserver = nil
        skipManager?.setSkipSegments([])
        
        guard !segments.isEmpty else { return }
        
        // If item already ready → apply immediately
        if item.status == .readyToPlay {
            skipManager?.setSkipSegments(segments)
            return
        }
        
        // Else wait for ready state
        skipItemStatusObserver = item.observe(
            \.status,
             options: [.new]
        ) { [weak self] item, _ in
            guard let self else { return }
            
            if item.status == .readyToPlay {
                DispatchQueue.main.async {
                    self.skipManager?.setSkipSegments(segments)
                    self.skipItemStatusObserver = nil
                }
            }
        }
    }
}

extension AVPlayerViewController {
    
    public func setSkipSegments(_ segments: [SkipSegment]) {
        
        guard let skipManager else {
            return
        }
        skipManager.setSkipSegments(segments)
    }
    
    public func skipCurrentSegment() {
        skipManager?.skipCurrentSegment()
    }
}

extension AVPlayerViewController {
    
    private static var audioTrackManagerKey = "FastPixAudioTrackManager"
    
    public var audioTrackManager: FastPixAudioTrackManager? {
        get {
            return objc_getAssociatedObject(self, &Self.audioTrackManagerKey) as? FastPixAudioTrackManager
        }
        set {
            objc_setAssociatedObject(
                self,
                &Self.audioTrackManagerKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    
    private static var audioTrackDelegateKey = "FastPixAudioTrackDelegate"
    
    public weak var audioTrackDelegate: FastPixAudioTrackDelegate? {
        get {
            return objc_getAssociatedObject(self, &Self.audioTrackDelegateKey) as? FastPixAudioTrackDelegate
        }
        set {
            objc_setAssociatedObject(self,
                                     &Self.audioTrackDelegateKey,
                                     newValue,
                                     .OBJC_ASSOCIATION_ASSIGN)
        }
    }
    
    public func getAudioTracks() -> [AudioTrack] {
        return audioTrackManager?.fetchAudioTracks() ?? []
    }
    
    public func getCurrentAudioTrack() -> AudioTrack? {
        return audioTrackManager?.getCurrentTrack()
    }
    
    public func setAudioTrack(trackId: String) {
        
        do {
            try audioTrackManager?.selectTrack(trackId: trackId)
            
            if let track = getCurrentAudioTrack() {
                audioTrackDelegate?.onAudioTrackChange(selectedTrack: track)
            }
            
        } catch {
            fastPixDelegate?.playerDidFail(self, error: error)
        }
    }
    
    public func setPreferredAudioTrack(_ languageName: String?) {
        audioTrackManager?.setPreferredAudioTrack(languageName: languageName)
    }
}

extension AVPlayerViewController: FastPixAudioTrackDelegate {
    
    public func onAudioTracksUpdated(tracks: [AudioTrack]) {
        // Forward to host app if needed
    }
    
    public func onAudioTrackChange(selectedTrack: AudioTrack) {
        // Forward to host app delegate
    }
    
    public func onAudioTrackFailed(error: AudioTrackError) {
        // Forward to host app delegate
    }
    
    public func onAudioTrackSwitching(isSwitching: Bool) {
        // Optional event
    }
}

extension AVPlayerViewController {
    
    private static var subtitleTrackManagerKey = "FastPixSubtitleTrackManager"
    
    public var subtitleTrackManager: FastPixSubtitleTrackManager? {
        get {
            return objc_getAssociatedObject(self, &Self.subtitleTrackManagerKey) as? FastPixSubtitleTrackManager
        }
        set {
            objc_setAssociatedObject(
                self,
                &Self.subtitleTrackManagerKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    
    private static var subtitleTrackDelegateKey = "FastPixSubtitleTrackDelegate"
    
    public weak var subtitleTrackDelegate: FastPixSubtitleTrackDelegate? {
        get {
            return objc_getAssociatedObject(self, &Self.subtitleTrackDelegateKey) as? FastPixSubtitleTrackDelegate
        }
        set {
            objc_setAssociatedObject(
                self,
                &Self.subtitleTrackDelegateKey,
                newValue,
                .OBJC_ASSOCIATION_ASSIGN
            )
        }
    }
    
    public func getSubtitleTracks() -> [SubtitleTrack] {
        return subtitleTrackManager?.getSubtitleTracks() ?? []
    }
    
    public func getCurrentSubtitleTrack() -> SubtitleTrack? {
        return subtitleTrackManager?.getCurrentSubtitleTrack()
    }
    
    public func setSubtitleTrack(trackId: String) {
        
        do {
            try subtitleTrackManager?.setSubtitleTrack(trackId: trackId)
        } catch {
            print("Subtitle switching failed:", error)
        }
    }
    
    public func setPreferredSubtitleTrack(_ languageName: String?) {
        subtitleTrackManager?.setPreferredSubtitleTrack(languageName: languageName)
    }
    
    public func disableSubtitles() {
        subtitleTrackManager?.disableSubtitles()
    }
}

extension AVPlayerViewController: FastPixSubtitleTrackDelegate {
    
    public func onSubtitlesLoaded(tracks: [SubtitleTrack]) {
        // Forward to host app if needed
    }
    
    public func onSubtitleChange(track: SubtitleTrack?) {
        // Notify UI
    }
    
    public func onSubtitlesLoadedFailed(error: SubtitleTrackError) {
        // Forward to host app delegate
    }
    
    public func onSubtitleCueChange(information: SubtitleRenderInfo) {
        // Optional: custom subtitle rendering
    }
}

extension AVPlayerViewController {
    
    // MARK: - Associated Object Key
    
    private static var qualityManagerKey = "FastPixQualityManagerKey"
    
    // MARK: - Manager
    
    public var qualityManager: FastPixQualityManager? {
        get {
            return objc_getAssociatedObject(self, &Self.qualityManagerKey) as? FastPixQualityManager
        }
        set {
            objc_setAssociatedObject(
                self,
                &Self.qualityManagerKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    
    private static var qualityDelegateKey = "FastPixQualityDelegate"
    
    public weak var qualityDelegate: FastPixQualityDelegate? {
        get {
            return objc_getAssociatedObject(self, &Self.qualityDelegateKey) as? FastPixQualityDelegate
        }
        set {
            objc_setAssociatedObject(
                self,
                &Self.qualityDelegateKey,
                newValue,
                .OBJC_ASSOCIATION_ASSIGN
            )
        }
    }
    
    public func setupQualityManager(delegate: FastPixQualityDelegate? = nil) {
        
        guard let player = self.player else {
            return
        }
        
        let manager = FastPixQualityManager(player: self.player)
        manager.delegate = self.qualityDelegate
        manager.attach(player: self.player)
        
        self.qualityManager = manager
    }
    
    // MARK: - Public APIs (Design Doc Aligned)
    
    public func getResolutionLevels() -> [QualityLevel] {
        return qualityManager?.getResolutionLevels() ?? []
    }
    
    public func getCurrentResolutionLevel() -> QualityLevel? {
        return qualityManager?.getCurrentResolutionLevel()
    }
    
    public func setResolutionLevel(_ level: QualityLevel) {
        qualityManager?.setResolutionLevel(level)
    }
    
    public func setInitialResolutionLevel(_ level: QualityLevel) {
        qualityManager?.setInitialResolutionLevel(level)
    }
    
    public func resetToAuto() {
        qualityManager?.resetToAuto()
    }
    
    public func getAutoQualityLevel() -> QualityLevel? {
        return qualityManager?.getAutoQualityLevel()
    }
    
    // MARK: - ABR Control
    
    public func setABREnabled(_ enabled: Bool) {
        qualityManager?.setABREnabled(enabled)
    }
    
    public func isABREnabled() -> Bool {
        return qualityManager?.isABREnabled() ?? true
    }
}

final class FastPixAnalyticsManager {
    
    private var dataSDK = initAvPlayerTracking()
    private var isTrackingStarted = false
    
    func startTracking(playerLayer: AVPlayerLayer?, metadata: [String: Any]) {
        guard let layer = playerLayer else { return }
        guard !isTrackingStarted else { return } // prevent duplicate tracking
        
        let payload: [String: Any] = [
            "data": metadata
        ]
        
        dataSDK.trackAvPlayerLayer(
            playerLayer: layer,
            customMetadata: payload
        )
        
        isTrackingStarted = true
    }
    
    func reset() {
        isTrackingStarted = false
    }
}

private struct FastPixAnalyticsKeys {
    static var manager = "fastpix_analytics_manager"
    static var metadata = "fastpix_analytics_metadata"
}

extension AVPlayerViewController {
    
    private var analyticsManager: FastPixAnalyticsManager? {
        get {
            objc_getAssociatedObject(self, &FastPixAnalyticsKeys.manager) as? FastPixAnalyticsManager
        }
        set {
            objc_setAssociatedObject(
                self,
                &FastPixAnalyticsKeys.manager,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    
    private var analyticsMetadata: [String: Any]? {
        get {
            objc_getAssociatedObject(self, &FastPixAnalyticsKeys.metadata) as? [String: Any]
        }
        set {
            objc_setAssociatedObject(
                self,
                &FastPixAnalyticsKeys.metadata,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}

extension AVPlayerViewController {
    
    public func enableAnalytics(metadata: [String: Any]) {
        
        // Store metadata
        self.analyticsMetadata = enrichMetadata(metadata)
        
        print("Came to trcak the Analytics")
        
        // Initialize manager
        if analyticsManager == nil {
            analyticsManager = FastPixAnalyticsManager()
        }
    }
    
    private func enrichMetadata(_ metadata: [String: Any]) -> [String: Any] {
        
        var enriched = metadata
        
        enriched["player_name"] = "AVPlayer"
        enriched["player_version"] = "1.0.0"
        enriched["player_software_name"] = "AVPlayer"
        enriched["player_software_version"] = "1.0.0"
        enriched["player_fastpix_sdk_name"] = "fastpix-ios-player"
        enriched["player_fastpix_sdk_version"] = "1.0.0"
        
        // Defaults if not provided
        if enriched["video_stream_type"] == nil {
            enriched["video_stream_type"] = "on-demand"
        }
        
        return enriched
    }
}
