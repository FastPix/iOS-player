
import AVFoundation
import Foundation
import ObjectiveC.runtime

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
    return playbackURL
}

// MARK: - DRM Delegate
public class FastPixDRMDelegate: NSObject, AVAssetResourceLoaderDelegate {
    
    private let licenseServerUrl: URL
    private let certificateUrl: URL
    
    init(licenseServerUrl: URL, certificateUrl: URL) {
        self.licenseServerUrl = licenseServerUrl
        self.certificateUrl = certificateUrl
    }
    
    @available(tvOS 13.0.0, *)
    @available(iOS 13.0.0, *)
    private func fetchCertificate() async throws -> Data {
        let (data, _) = try await URLSession.shared.data(from: certificateUrl)
        return data
    }
    
    public func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
                               shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        
        guard let url = loadingRequest.request.url, url.scheme == "skd" else {
            return false
        }
        
        if #available(iOS 13.0, *) {
            if #available(tvOS 13.0, *) {
                Task {
                    do {
                        let certificate = try await fetchCertificate()
                        guard let contentIdData = url.host?.data(using: .utf8) else {
                            loadingRequest.finishLoading(with: NSError(domain: "FastPixDRM", code: -1))
                            return
                        }
                        
                        let spcData = try loadingRequest.streamingContentKeyRequestData(
                            forApp: certificate,
                            contentIdentifier: contentIdData,
                            options: nil
                        )
                        var request = URLRequest(url: licenseServerUrl)
                        request.httpMethod = "POST"
                        request.httpBody = spcData
                        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
                        
                        let (ckcData, _) = try await URLSession.shared.data(for: request)
                        loadingRequest.dataRequest?.respond(with: ckcData)
                        loadingRequest.finishLoading()
                    } catch {
                        loadingRequest.finishLoading(with: error)
                    }
                }
            } else {
                // Fallback on earlier versions
            }
        } else {
            // Fallback on earlier versions
        }
        return true
    }
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
    
    // DRM initializer
    convenience init(playbackID: String,
                     playbackOptions: PlaybackOptions,
                     licenseServerUrl: URL,
                     certificateUrl: URL) {
        let playbackURL = createPlaybackURL(
            playbackID: playbackID,
            playbackOptions: playbackOptions
        )
        let asset = AVURLAsset(url: playbackURL)
        let delegate = FastPixDRMDelegate(licenseServerUrl: licenseServerUrl,
                                          certificateUrl: certificateUrl)
        asset.resourceLoader.setDelegate(delegate, queue: DispatchQueue.global(qos: .userInitiated))
        self.init(asset: asset)
        objc_setAssociatedObject(self, "FastPixDRMDelegateKey", delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
