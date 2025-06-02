//
//  FastPixAvPlayerItem.swift
//
//
//  Created by Neha Reddy on 16/06/24.
//

import AVFoundation
import Foundation

internal extension URLComponents {
    init(playbackID: String,playbackOptions: PlaybackOptions) {
        self.init()
        self.scheme = "https"
        var queryItems: [URLQueryItem] = []
        if playbackOptions.streamType == "live" {
            if let customDomain = playbackOptions.customDomain {
                self.host = "\(customDomain)"
            } else {
                self.host = "stream.fastpix.io"
            }
        } else {
            if let customDomain = playbackOptions.customDomain {
                self.host = "\(customDomain)"
            } else {
                self.host = "stream.fastpix.io"
            }
        }
        
        self.path = "/\(playbackID).m3u8"
        
        if playbackOptions.maxResolution != .standard {
            queryItems.append(
                URLQueryItem(
                    name: "max_resolution",
                    value: playbackOptions.maxResolution?.queryValue
                )
            )
        }
        
        if playbackOptions.minResolution != .standard {
            queryItems.append(
                URLQueryItem(
                    name: "min_resolution",
                    value: playbackOptions.maxResolution?.queryValue
                )
            )
        }
        
        if case .signed(let signedPlaybackOptions) = playbackOptions.playbackPolicy {
            queryItems.append(
                URLQueryItem(
                    name: "token",
                    value: signedPlaybackOptions.playbackToken
                )
            )
            self.queryItems = queryItems
        }

    }
}

fileprivate func createPlaybackURL(playbackID: String,playbackOptions: PlaybackOptions) -> URL {
    
    var components = URLComponents()
    var queryItems: [URLQueryItem] = []
    
    components.scheme = "https"
    if playbackOptions.streamType == "live" {
        if let customDomain = playbackOptions.customDomain {
            components.host = "\(customDomain)"
            components.path = "/\(playbackID).m3u8"
        } else {
            components.host = "stream.fastpix.io"
            components.path = "/\(playbackID).m3u8"
        }
    } else {
        if let customDomain = playbackOptions.customDomain {
            components.host = "\(customDomain)"
            components.path = "/\(playbackID).m3u8"
        } else {
            components.host = "stream.fastpix.io"
            components.path = "/\(playbackID).m3u8"
        }
    }
    
    if case .signed(let signedPlaybackOptions) = playbackOptions.playbackPolicy {
        queryItems.append(
            URLQueryItem(
                name: "token",
                value: signedPlaybackOptions.playbackToken
            )
        )
    }

    if playbackOptions.maxResolution != .standard, playbackOptions.maxResolution != nil {
        queryItems.append(
            URLQueryItem(
                name: "maxResolution",
                value: playbackOptions.maxResolution?.queryValue
            )
        )
    }
    
    if playbackOptions.minResolution != .standard, playbackOptions.minResolution != nil {
        queryItems.append(
            URLQueryItem(
                name: "minResolution",
                value: playbackOptions.minResolution?.queryValue
            )
        )
    }
    
    if playbackOptions.renditionOrder != .standard, playbackOptions.renditionOrder != nil {
        queryItems.append(
            URLQueryItem(
                name: "renditionOrder",
                value: playbackOptions.renditionOrder?.queryValue
            )
        )
    }
    
    if playbackOptions.resolution != .standard, playbackOptions.resolution != nil {
        queryItems.append(
            URLQueryItem(
                name: "resolution",
                value: playbackOptions.resolution?.queryValue
            )
        )
        
    }
    components.queryItems = queryItems
    guard let playbackURL = components.url else {
        preconditionFailure("Invalid playback URL components")
    }
//    print("---->",components.url?.absoluteString)
    print("---->",playbackURL)
    return playbackURL
}

internal extension AVPlayerItem {
    
    // Initializes a player item with a playback URL that
    // references your FastPix Video at the supplied playback ID.
    // The playback ID must be public.
    //
    // This initializer uses https://stream.fastpix.io as the
    // base URL. Use a different initializer if using a custom
    // playback URL.
    //
    // - Parameter playbackID: playback ID of the FastPix Asset
    convenience init(playbackID: String) {
        //        self.init(playbackID: playbackID)
        
        let defaultOptions = PlaybackOptions() // Ensure this struct has default values
        
        let playbackURL = createPlaybackURL(
            playbackID: playbackID,
            playbackOptions: defaultOptions
        )
        self.init(url: playbackURL)
    }

    // Initializes a player item with a playback URL that
    // references your FastPix Video at the supplied playback ID.
    // The playback ID must be public.
    //
    // - Parameters:
    //   - playbackID: playback ID of the FastPix Asset
    //   you'd like to play
    convenience init(playbackID: String,playbackOptions: PlaybackOptions) {
        let playbackURL = createPlaybackURL(
            playbackID: playbackID,
            playbackOptions: playbackOptions
        )
        self.init(url: playbackURL)
    }
}
