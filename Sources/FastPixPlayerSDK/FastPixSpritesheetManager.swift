import UIKit
import AVFoundation

// MARK: - Public Types

public enum FastPixPreviewMode {
    case thumbnail
    case timestamp
}

public enum FastPixPreviewFallbackMode {
    case timestamp
    case none
}

public struct FastPixSpritesheetMetadata {
    public let imageURL: URL
    public let rows: Int
    public let cols: Int
    public let frameCount: Int
    public let duration: TimeInterval
    public let tileWidth: Int
    public let tileHeight: Int
}

public struct FastPixSeekPreviewConfig {
    public let previewSize: CGSize
    public let preloadRadius: Int
    
    public init(
        previewSize: CGSize = .init(width: 160, height: 90),
        preloadRadius: Int = 4
    ) {
        self.previewSize = previewSize
        self.preloadRadius = preloadRadius
    }
}

private struct FastPixSpritesheetJSON: Decodable {
    struct Tile: Decodable {
        let start: TimeInterval
        let x: Int
        let y: Int
    }
    
    let url: String
    let tileWidth: Int
    let tileHeight: Int
    let duration: TimeInterval
    let tiles: [Tile]
    
    // Provide custom CodingKeys so JSON decoding still maps snake_case keys correctly
    enum CodingKeys: String, CodingKey {
        case url
        case tileWidth  = "tile_width"
        case tileHeight = "tile_height"
        case duration
        case tiles
    }
}

// MARK: - Mapper

private struct FastPixSpritesheetPreviewMapper {
    let metadata: FastPixSpritesheetMetadata
    
    func frameIndex(for time: TimeInterval) -> Int {
        let clamped = max(0, min(time, metadata.duration))
        let ratio = metadata.duration > 0 ? clamped / metadata.duration : 0
        return min(Int(Double(metadata.frameCount) * ratio), max(metadata.frameCount - 1, 0))
    }
    
    func cropRect(for index: Int) -> CGRect {
        let row = index / metadata.cols
        let col = index % metadata.cols
        return CGRect(
            x: col * metadata.tileWidth,
            y: row * metadata.tileHeight,
            width: metadata.tileWidth,
            height: metadata.tileHeight
        )
    }
}

// MARK: - Manager

public final class FastPixSpritesheetManager {
    
    weak var player: AVPlayer?
    
    private let queue = DispatchQueue(label: "fastpix.spritesheet.queue", qos: .userInitiated)
    private let cache = NSCache<NSString, UIImage>()
    
    private var baseImage: UIImage?
    private(set) var metadata: FastPixSpritesheetMetadata?
    private var mapper: FastPixSpritesheetPreviewMapper?
    
    public var previewMode: FastPixPreviewMode = .timestamp
    public var fallbackMode: FastPixPreviewFallbackMode = .timestamp
    private var fastpixTiles: [FastPixSpritesheetJSON.Tile] = []
    
    // Events from design doc
    var onSpritesheetLoaded: ((FastPixSpritesheetMetadata) -> Void)?
    var onSpritesheetFailed: ((Error) -> Void)?
    var onPreviewShow: (() -> Void)?
    var onPreviewHide: (() -> Void)?
    
    // MARK: - Init
    
    init(player: AVPlayer?) {
        self.player = player
    }
    
    // MARK: - Public config
    
    func setFallbackMode(_ mode: FastPixPreviewFallbackMode) {
        fallbackMode = mode
    }
    
    // MARK: - Entry point used by AVPlayerViewController
    
    // The config value is accepted for API compatibility but not used in this
    // implementation; callers are unaffected.
    func load(url: URL?, config _: FastPixSeekPreviewConfig) {
        
        // 1) If caller passes explicit spritesheet JSON URL, use that.
        if let customURL = url {
            loadCustomSpritesheet(from: customURL)
            return
        }
        
        guard let playbackItem = player?.currentItem,
              let assetURL = (playbackItem.asset as? AVURLAsset)?.url else {
            previewMode = .timestamp
            return
        }
        
        guard let playbackID = extractPlaybackID(from: assetURL) else {
            previewMode = .timestamp
            return
        }
        
        // Extract token (if present)
        let token = extractToken(from: assetURL)
        
        // Choose images host based on stream host
        let imagesHost: String
        switch assetURL.host {
        case "stream.fastpix.io":
            imagesHost = "images.fastpix.io"
        case "stream.fastpix.app":
            imagesHost = "images.fastpix.app"
        case "venus-stream.fastpix.dev":
            imagesHost = "venus-images.fastpix.dev"
        default:
            previewMode = .timestamp
            return
        }
        
        var jsonString = "https://\(imagesHost)/\(playbackID)/spritesheet.json"
        
        // Append token ONLY if it exists
        if let token = token, !token.isEmpty {
            jsonString += "?token=\(token)"
        }
        
        guard let jsonURL = URL(string: jsonString) else {
            previewMode = .timestamp
            return
        }
        loadCustomSpritesheet(from: jsonURL)
    }
    
    private func extractToken(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }
        return queryItems.first(where: { $0.name == "token" })?.value
    }
    
    func clearCache() {
        baseImage = nil
        metadata = nil
        mapper = nil
        fastpixTiles = []
        cache.removeAllObjects()
        previewMode = .timestamp
    }
}

// MARK: - Public thumbnail access

extension FastPixSpritesheetManager {
    
    public func thumbnail(for time: TimeInterval) -> UIImage? {
        
        guard previewMode == .thumbnail else {
            return nil
        }
        
        guard let baseImage = baseImage else {
            return nil
        }
        
        guard let metadata = metadata,
              let _ = mapper else {
            return nil
        }
        
        // Find the tile that matches this time
        var tileIndex = 0
        for (index, tile) in fastpixTiles.enumerated() {
            if tile.start <= time {
                tileIndex = index
            } else {
                break
            }
        }
        
        let key = "\(tileIndex)" as NSString
        
        if let cached = cache.object(forKey: key) {
            return cached
        }
        
        let tile = fastpixTiles[tileIndex]
        let cropRect = CGRect(
            x: tile.x,
            y: tile.y,
            width: metadata.tileWidth,
            height: metadata.tileHeight
        )
        
        guard let cg = baseImage.cgImage?.cropping(to: cropRect) else { return nil }
        let image = UIImage(cgImage: cg, scale: baseImage.scale, orientation: baseImage.imageOrientation)
        cache.setObject(image, forKey: key)
        return image
    }
}

// MARK: - Internal loading logic

extension FastPixSpritesheetManager {
    
    func extractPlaybackID(from url: URL) -> String? {
        let last = url.deletingPathExtension().lastPathComponent
        return last.isEmpty ? nil : last
    }
    
    private func loadCustomSpritesheet(from url: URL) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let jsonData = try Data(contentsOf: url)
                
                let decoder = JSONDecoder()
                let json = try decoder.decode(FastPixSpritesheetJSON.self, from: jsonData)
                guard let imageURL = URL(string: json.url) else {
                    throw NSError(domain: "FastPixSpritesheet", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "Invalid image URL"])
                }
                
                // Use URLComponents path normalisation instead, which handles
                // duplicate separators without embedding a literal delimiter string.
                let fixedURL: URL
                if var components = URLComponents(url: imageURL, resolvingAgainstBaseURL: false) {
                    // Collapse any consecutive path separators via URL's own path normalisation
                    let normalised = (imageURL.path as NSString).standardizingPath
                    components.path = normalised
                    fixedURL = components.url ?? imageURL
                } else {
                    fixedURL = imageURL
                }
                
                var request = URLRequest(url: fixedURL)
                request.timeoutInterval = 30
                
                let semaphore = DispatchSemaphore(value: 0)
                var imageData: Data?
                var downloadError: Error?
                
                URLSession.shared.dataTask(with: request) { data, _, error in
                    imageData = data
                    downloadError = error
                    semaphore.signal()
                }.resume()
                
                semaphore.wait()
                
                if let error = downloadError {
                    throw error
                }
                
                guard let imageData = imageData else {
                    throw NSError(domain: "FastPixSpritesheet", code: 2,
                                  userInfo: [NSLocalizedDescriptionKey: "No image data received"])
                }
                
                guard let image = UIImage(data: imageData) else {
                    throw NSError(domain: "FastPixSpritesheet", code: 3,
                                  userInfo: [NSLocalizedDescriptionKey: "Failed to decode spritesheet image"])
                }
                
                // Calculate rows/cols from tile positions using renamed properties
                let maxY = json.tiles.map { $0.y }.max() ?? 0
                let maxX = json.tiles.map { $0.x }.max() ?? 0
                let rows = (maxY / json.tileHeight) + 1
                let cols = (maxX / json.tileWidth) + 1
                
                let meta = FastPixSpritesheetMetadata(
                    imageURL: fixedURL,
                    rows: rows,
                    cols: cols,
                    frameCount: json.tiles.count,
                    duration: json.duration,
                    tileWidth: json.tileWidth,
                    tileHeight: json.tileHeight
                )
                
                self.baseImage = image
                self.metadata = meta
                self.mapper = FastPixSpritesheetPreviewMapper(metadata: meta)
                self.fastpixTiles = json.tiles
                self.previewMode = .thumbnail
                
                DispatchQueue.main.async {
                    self.onSpritesheetLoaded?(meta)
                }
                
            } catch {
                self.previewMode = .timestamp
                DispatchQueue.main.async {
                    self.onSpritesheetFailed?(error)
                }
            }
        }
    }
    
    // The parameter is kept for API compatibility; callers are unaffected.
    func generateSpritesheet(config _: FastPixSeekPreviewConfig) {
        previewMode = .timestamp
    }
}
