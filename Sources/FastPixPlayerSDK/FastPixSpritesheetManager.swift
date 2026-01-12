
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
    
    let url: String                // spritesheet image URL
    let tile_width: Int            // width of each tile
    let tile_height: Int           // height of each tile
    let duration: TimeInterval     // video duration
    let tiles: [Tile]              // array of tiles with start times and positions
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
    
    func load(url: URL?, config: FastPixSeekPreviewConfig) {
        // 1) If caller passes explicit spritesheet JSON URL, use that.
        if let customURL = url {
            loadCustomSpritesheet(from: customURL)
            return
        }
        
        // 2) Otherwise, derive FastPix spritesheet JSON URL from current AVPlayerItem URL.
        guard let playbackItem = player?.currentItem,
              let assetURL = (playbackItem.asset as? AVURLAsset)?.url else {
            previewMode = .timestamp
            return
        }
        
        guard let playbackID = extractPlaybackID(from: assetURL) else {
            previewMode = .timestamp
            return
        }
        
        //Choose images host based on stream host
        let imagesHost: String
        switch assetURL.host {
        case "stream.fastpix.io":
            imagesHost = "images.fastpix.io"
        case "stream.fastpix.app":
            imagesHost = "images.fastpix.app"
        case "venus-stream.fastpix.dev":
            imagesHost = "venus-images.fastpix.dev"
        default:
            // Fallback or bail out
            previewMode = .timestamp
            return
        }
        
        let jsonString = "https://\(imagesHost)/\(playbackID)/spritesheet.json"
        guard let jsonURL = URL(string: jsonString) else {
            previewMode = .timestamp
            return
        }
        loadCustomSpritesheet(from: jsonURL)
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
        
        // 🔹 If no spritesheet loaded, return nil
        guard previewMode == .thumbnail else {
            return nil
        }
        
        guard let baseImage = baseImage else {
            return nil
        }
        
        guard let metadata = metadata,
              let mapper = mapper else {
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
    
    // Derive playbackID from your HLS URL.
    // Example: https://stream.fastpix.io/hls/{PLAYBACK_ID}.m3u8?token=...
    func extractPlaybackID(from url: URL) -> String? {
        let last = url.deletingPathExtension().lastPathComponent
        return last.isEmpty ? nil : last
    }
    
    private func loadCustomSpritesheet(from url: URL) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let jsonData = try Data(contentsOf: url)
                
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                }
                
                let decoder = JSONDecoder()
                let json = try decoder.decode(FastPixSpritesheetJSON.self, from: jsonData)
                guard let imageURL = URL(string: json.url) else {
                    throw NSError(domain: "FastPixSpritesheet", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "Invalid image URL"])
                }
                
                // Fix double slashes in the URL path
                let fixedURL: URL
                if let urlComponents = URLComponents(url: imageURL, resolvingAgainstBaseURL: false) {
                    var newPath = urlComponents.path.replacingOccurrences(of: "//", with: "/")
                    var newComponents = urlComponents
                    newComponents.path = newPath
                    fixedURL = newComponents.url ?? imageURL
                } else {
                    fixedURL = imageURL
                }
                
                var request = URLRequest(url: fixedURL)
                request.timeoutInterval = 30
                
                let semaphore = DispatchSemaphore(value: 0)
                var imageData: Data?
                var downloadError: Error?
                
                URLSession.shared.dataTask(with: request) { data, response, error in
                    imageData = data
                    downloadError = error
                    if let httpResponse = response as? HTTPURLResponse {
                    }
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
                
                // Calculate rows/cols from tile positions
                let maxY = json.tiles.map { $0.y }.max() ?? 0
                let maxX = json.tiles.map { $0.x }.max() ?? 0
                let rows = (maxY / json.tile_height) + 1
                let cols = (maxX / json.tile_width) + 1
                
                let meta = FastPixSpritesheetMetadata(
                    imageURL: fixedURL,
                    rows: rows,
                    cols: cols,
                    frameCount: json.tiles.count,
                    duration: json.duration,
                    tileWidth: json.tile_width,
                    tileHeight: json.tile_height
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
    
    // Optional: local generation fallback (not needed if FastPix always has spritesheet)
    func generateSpritesheet(config: FastPixSeekPreviewConfig) {
        // For FastPix, you usually rely on server-side spritesheet.
        // Keep timestamp-only fallback here for now.
        previewMode = .timestamp
    }
}
