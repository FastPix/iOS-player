
import AVFoundation
import Foundation
import UIKit
import AVKit

extension AVPlayerLayer {
    
    /// Initializes an AVPlayerLayer that's configured
    /// back it's playback performance.
    /// - Parameter playbackID: playback ID of the FastPix
    /// Asset you'd like to play
    public convenience init(playbackID: String) {
        self.init()
        
        let playerItem = AVPlayerItem(playbackID: playbackID)
        
        let player = AVPlayer(playerItem: playerItem)
        self.player = player
    }
    
    /// Initializes an AVPlayerLayer that's configured
    /// back it's playback performance.
    /// - Parameters:
    ///   - playbackID: playback ID of the FastPix Asset
    ///   you'd like to play
    ///   - playbackOptions: playback-related options such
    ///   as custom domain and maximum resolution
    public convenience init(playbackID: String,playbackOptions: PlaybackOptions) {
        
        self.init()
        
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
    
    /// Prepares an already instantiated AVPlayerLayer
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
    
    /// Prepares an already instantiated AVPlayerLayer
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
    }
}

// MARK: - Playback Control Methods
extension AVPlayerLayer {
    
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
    
    /// Check playback status
    public var isPlaying: Bool {
        return player?.timeControlStatus == .playing
    }
}

extension AVPlayerLayer {
    
    private static var seekManagerKey = "FastPixSeekManager"
    
    public var seekManager: FastPixSeekManager? {
        get {
            return objc_getAssociatedObject(self, &Self.seekManagerKey) as? FastPixSeekManager
        }
        set {
            objc_setAssociatedObject(self, &Self.seekManagerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    public func setupSeekManager(delegate: FastPixSeekDelegate? = nil) {
        guard let player = player else { return }
        seekManager = FastPixSeekManager(player: player)
        seekManager?.delegate = delegate
    }
    
    // Replicate all seek methods from AVPlayerViewController
    public func getCurrentTime() -> TimeInterval {
        return seekManager?.getCurrentTime() ?? 0
    }
    
    public func getDuration() -> TimeInterval {
        return seekManager?.getDuration() ?? 0
    }
    
    public func setStartTime(_ time: TimeInterval) {
        seekManager?.setStartTime(time)
    }
    
    public func enableStartTimeResume(_ enable: Bool) {
        seekManager?.enableStartTimeResume(enable)
    }
    
    public func seek(to time: TimeInterval, completion: ((Bool) -> Void)? = nil) {
        seekManager?.seekTo(time: time, completion: completion)
    }
}
