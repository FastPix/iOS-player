//
//  File.swift
//  
//
//  Created by Neha Reddy on 21/07/24.
//

import AVFoundation
import Foundation

extension AVPlayerLayer {
    
    /// Initializes an AVPlayerLayer that's configured
    /// back it's playback performance.
    /// - Parameter playbackID: playback ID of the FastPix
    /// Asset you'd like to play
    public convenience init(playbackID: String) {
        self.init()
        
        let playerItem = AVPlayerItem(playbackID: playbackID)
        
        let player = AVPlayer(playerItem: playerItem)
        print(playerItem)
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
        
        let playerItem = AVPlayerItem(
            playbackID: playbackID,
            playbackOptions: playbackOptions
        )
        
        let player = AVPlayer(playerItem: playerItem)
        print(playerItem)
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
        prepare(
            playerItem: AVPlayerItem(
                playbackID: playbackID,
                playbackOptions: playbackOptions
            )
        )
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
