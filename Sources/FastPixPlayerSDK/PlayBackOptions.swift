
import Foundation

/// The max resolution tier you'd like your asset to be streamed at
public enum MaxResolution {
    /// By default no resolution tier is specified and FastPix  selects the optimal resolution and bitrate based on  network and player conditions.
    case standard
    
    case upTo270p
    
    case upTo360p
    
    case upTo480p
    
    case upTo540p
    
    case upTo720p
    

    case upTo1080p
    
    case upTo1440p
    
    case upTo2160p
}

/// The min resolution  you'd like your asset to be streamed at
public enum MinResolution {
    /// By default no resolution tier is specified and FastPix selects the optimal resolution and bitrate based on network and player conditions.
    case standard
    
    case atLeast270p
    
    case atLeast360p
    
    case atLeast480p
    
    case atLeast540p
    
    case atLeast720p
    
    case atLeast1080p
    
    case atLeast1440p
    
    case atLeast2160p
}

public enum Resolutions {
    
    case standard
    
    case set270p
    
    case set360p
    
    case set480p
    
    case set540p
    
    case set720p
    
    case set1080p
    
    case set1440p
    
    case set2160p
}

public enum RenditionOrder {
    
    case standard
    case descending
    
}

extension MaxResolution {
    var queryValue: String {
        switch self {
        case .standard:
            return ""
        case .upTo270p:
            return "270p"
        case .upTo360p:
            return "360p"
        case .upTo480p:
            return "480p"
        case .upTo540p:
            return "540p"
        case .upTo720p:
            return "720p"
        case .upTo1080p:
            return "1080p"
        case .upTo1440p:
            return "1440p"
        case .upTo2160p:
            return "2160p"
        }
    }
}

extension MinResolution {
    var queryValue: String {
        switch self {
        case .standard:
            return ""
        case .atLeast270p:
            return "270p"
        case .atLeast360p:
            return "360p"
        case .atLeast480p:
            return "480p"
        case .atLeast540p:
            return "540p"
        case .atLeast720p:
            return "720p"
        case .atLeast1080p:
            return "1080p"
        case .atLeast1440p:
            return "1440p"
        case .atLeast2160p:
            return "2160p"
        }
    }
}

extension RenditionOrder {
    var queryValue: String {
        switch self {
        case .standard:
            return "asc"
        case .descending:
            return "desc"
        }
    }
}

extension Resolutions {
    var queryValue: String {
        switch self {
        case .standard:
            return ""
        case .set270p:
            return "270p"
        case .set360p:
            return "360p"
        case .set480p:
            return "480p"
        case .set540p:
            return "540p"
        case .set720p:
            return "720p"
        case .set1080p:
            return "1080p"
        case .set1440p:
            return "1440p"
        case .set2160p:
            return "2160p"
            
        }
    }
}

/// DRM options for FairPlay playback
public struct DRMOptions {
    public let licenseURL: URL
    public let certificateURL: URL
    
    public init(licenseURL: URL, certificateURL: URL) {
        self.licenseURL = licenseURL
        self.certificateURL = certificateURL
    }
}

public struct PlaybackOptions {
    
    struct SignedPlaybackOptions {
        var playbackToken: String?
    }
    
    enum PlaybackPolicy {
        case unsigned
        case signed(SignedPlaybackOptions)
    }
    
    var playbackPolicy: PlaybackPolicy?
    var customDomain: String?
    var streamType: String?
    var minResolution: MinResolution?
    var maxResolution: MaxResolution?
    var renditionOrder: RenditionOrder?
    var resolution: Resolutions?
    
    /// Optional DRM options for FairPlay
    public var drmOptions: DRMOptions?
}

extension PlaybackOptions {
    
    public init(customDomain: String,streamType: String) {
        self.customDomain = customDomain
        self.streamType = streamType
        self.playbackPolicy = .unsigned
    }
    
    public init(streamType: String) {
        self.streamType = streamType
    }
    
    public init(streamType: String,playbackToken:String) {
        self.streamType = streamType
        self.playbackPolicy = .signed(SignedPlaybackOptions(playbackToken: playbackToken))
    }
    
    public init(customDomain: String,playbackToken: String) {
        self.customDomain = customDomain
        self.playbackPolicy = .signed(
            SignedPlaybackOptions(
                playbackToken: playbackToken
            )
        )
    }
    
    public init(customDomain: String) {
        self.customDomain = customDomain
    }
    
    public init(playbackToken: String,minResolution: MinResolution = .standard, maxResolution: MaxResolution = .standard, renditionOrder: RenditionOrder = .standard) {
        self.playbackPolicy = .signed(
            SignedPlaybackOptions(
                playbackToken: playbackToken
            )
        )
        self.minResolution = minResolution
        self.maxResolution = maxResolution
        self.renditionOrder = renditionOrder
    }
    
    public init(playbackToken: String,resolution: Resolutions = .standard) {
        self.playbackPolicy = .signed(
            SignedPlaybackOptions(
                playbackToken: playbackToken
            )
        )
        self.resolution = resolution
    }
    
    public init(minResolution: MinResolution = .standard, maxResolution: MaxResolution = .standard, renditionOrder: RenditionOrder = .standard) {
        self.minResolution = minResolution
        self.maxResolution = maxResolution
        self.renditionOrder = renditionOrder
    }
    
    public init(resolution: Resolutions = .standard) {
        self.resolution = resolution
    }
    
    /// New: Init with DRM only
    public init(drmOptions: DRMOptions) {
        self.drmOptions = drmOptions
    }
    
    /// New: Init with DRM + playbackToken
    public init(playbackToken: String, drmOptions: DRMOptions) {
        self.playbackPolicy = .signed(SignedPlaybackOptions(playbackToken: playbackToken))
        self.drmOptions = drmOptions
    }
    
    /// New: Init with DRM + other options
    public init(customDomain: String? = nil,
                streamType: String? = nil,
                playbackToken: String? = nil,
                drmOptions: DRMOptions? = nil,
                minResolution: MinResolution? = .standard,
                maxResolution: MaxResolution? = .standard,
                renditionOrder: RenditionOrder? = .standard,
                resolution: Resolutions? = .standard) {
        self.customDomain = customDomain
        self.streamType = streamType
        if let token = playbackToken {
            self.playbackPolicy = .signed(SignedPlaybackOptions(playbackToken: token))
        } else {
            self.playbackPolicy = .unsigned
        }
        self.drmOptions = drmOptions
        self.minResolution = minResolution
        self.maxResolution = maxResolution
        self.renditionOrder = renditionOrder
        self.resolution = resolution
    }
}
