
import AVFoundation

// MARK: - Delegate

public protocol PrecacheManagerDelegate: AnyObject {
    func videoCacheDidHit(url: URL)
    func videoCacheDidMiss(url: URL)
}

// MARK: - Precache Manager

public final class PrecacheManager: NSObject {
    
    public static let shared = PrecacheManager()
    
    public weak var delegate: PrecacheManagerDelegate?
    
    // MARK: - Config
    private var isCachingEnabled = true
    private var maxDiskSize: Int = 200 * 1024 * 1024   // 200 MB default
    private let fileManager = FileManager.default
    private var cacheDirectory: URL!
    
    // MARK: - Networking
    // URLSession that respects the system disk cache so segments already
    // downloaded by AVFoundation can be reused.
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        // Use the system cache so we don't double-download what AVPlayer already fetched
        config.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: config)
    }()
    
    // Maps playlist URL → its active segment download tasks
    // Structure: [playlistURL: [segmentURL: task]]
    private var activeTasks: [URL: [URL: URLSessionDataTask]] = [:]
    
    // MARK: - Init
    public override init() {
        super.init()
        setupCacheDirectory()
    }
    
    // MARK: - Setu
    private func setupCacheDirectory() {
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = base.appendingPathComponent("FastPixVideoCache")
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory,
                                             withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Public API
    
    /// Enable or disable caching globally.
    public func enableVideoCaching(_ enabled: Bool) {
        isCachingEnabled = enabled
    }
    
    /// Set maximum disk cache size in megabytes.
    public func configureVideoCacheSize(_ sizeInMB: Int) {
        maxDiskSize = sizeInMB * 1024 * 1024
    }
    
    /// Returns true if any segment for this playlist URL has been cached to disk.
    public func isVideoCached(withURL url: URL) -> Bool {
        // We use the playlist URL's path component as a directory prefix
        let prefix = cacheKey(for: url)
        let dir = cacheDirectory.appendingPathComponent(prefix)
        guard let contents = try? fileManager.contentsOfDirectory(atPath: dir.path) else {
            return false
        }
        return !contents.isEmpty
    }
    
    /// Start precaching all segments in a given HLS playlist URL.
    /// Safe to call multiple times — duplicate requests are skipped.
    public func startPrecaching(url: URL) {
        guard isCachingEnabled else { return }
        guard activeTasks[url] == nil else { return }   // already in progress
        
        activeTasks[url] = [:]
        
        let task = session.dataTask(with: url) { [weak self] data, _, error in
            guard let self,
                  error == nil,
                  let data,
                  let playlist = String(data: data, encoding: .utf8) else { return }
            
            let baseURL = url.deletingLastPathComponent()
            let lines = playlist.components(separatedBy: "\n")
            
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.hasSuffix(".ts") || trimmed.hasSuffix(".m4s") else { continue }
                
                let segmentURL: URL
                if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
                    guard let u = URL(string: trimmed) else { continue }
                    segmentURL = u
                } else {
                    segmentURL = baseURL.appendingPathComponent(trimmed)
                }
                
                self.downloadAndCacheSegment(segmentURL, playlistURL: url)
            }
        }
        task.resume()
    }
    
    /// Stop all active segment downloads for a given playlist URL.
    public func stopPrecaching(url: URL) {
        // Cancel every segment task associated with this playlist
        activeTasks[url]?.values.forEach { $0.cancel() }
        activeTasks.removeValue(forKey: url)
    }
    
    /// Stop all active precaching tasks.
    public func stopAllPrecaching() {
        activeTasks.values.forEach { $0.values.forEach { $0.cancel() } }
        activeTasks.removeAll()
    }
    
    /// Clear all cached video segments from disk.
    public func clearVideoCache() {
        try? fileManager.removeItem(at: cacheDirectory)
        setupCacheDirectory()
    }
    
    /// Clear cached segments for a specific playlist URL.
    public func clearVideoCache(forURL url: URL) {
        let dir = cacheDirectory.appendingPathComponent(cacheKey(for: url))
        try? fileManager.removeItem(at: dir)
    }
    
    // MARK: - Asset Creation
    
    /// Wraps a URL in a custom-scheme AVURLAsset whose resource loader
    /// serves cached segments and falls back to network on a miss.
    /// Pass isDRM: true to skip custom caching (DRM assets use their own loader).
    public func createCachingAsset(from url: URL, isDRM: Bool = false) -> AVURLAsset {
        guard isCachingEnabled && !isDRM else {
            return AVURLAsset(url: url)
        }
        let customURL = convertToCustomScheme(url)
        let asset = AVURLAsset(url: customURL)
        asset.resourceLoader.setDelegate(self, queue: DispatchQueue.global(qos: .utility))
        return asset
    }
    
    // MARK: - Private: Segment Download + Disk Save
    
    private func downloadAndCacheSegment(_ url: URL, playlistURL: URL) {
        // Skip if already cached
        if isCachedOnDisk(url) { return }
        // Skip duplicate in-flight tasks
        if activeTasks[playlistURL]?[url] != nil { return }
        
        let task = session.dataTask(with: url) { [weak self] data, response, error in
            defer {
                self?.activeTasks[playlistURL]?.removeValue(forKey: url)
            }
            guard let self,
                  error == nil,
                  let data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else { return }
            
            self.saveSegmentToDisk(data, url: url)
        }
        
        activeTasks[playlistURL]?[url] = task
        task.resume()
    }
    
    private func saveSegmentToDisk(_ data: Data, url: URL) {
        let path = diskPath(for: url)
        // Create the parent directory if needed
        let dir = path.deletingLastPathComponent()
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: path, options: .atomic)
        enforceLRU()
    }
    
    // MARK: - Private: Disk Helpers
    
    /// Stable directory prefix derived from the playlist/segment URL host + path.
    private func cacheKey(for url: URL) -> String {
        let raw = (url.host ?? "") + url.deletingLastPathComponent().path
        return raw.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "default"
    }
    
    private func diskPath(for url: URL) -> URL {
        let dir = cacheDirectory.appendingPathComponent(cacheKey(for: url))
        let file = url.lastPathComponent
        return dir.appendingPathComponent(file)
    }
    
    private func isCachedOnDisk(_ url: URL) -> Bool {
        return fileManager.fileExists(atPath: diskPath(for: url).path)
    }
    
    private func readFromDisk(_ url: URL) -> Data? {
        return try? Data(contentsOf: diskPath(for: url))
    }
    
    // MARK: - Private: URL Scheme Conversion
    
    private func convertToCustomScheme(_ url: URL) -> URL {
        var c = URLComponents(url: url, resolvingAgainstBaseURL: false)
        c?.scheme = "fastpixcache"
        return c?.url ?? url
    }
    
    private func restoreOriginalScheme(_ url: URL) -> URL {
        var c = URLComponents(url: url, resolvingAgainstBaseURL: false)
        c?.scheme = "https"
        return c?.url ?? url
    }
    
    // MARK: - Private: LRU Eviction
    
    private func enforceLRU() {
        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: .skipsHiddenFiles
        ) else { return }
        
        var totalSize = 0
        var infos: [(url: URL, size: Int, date: Date)] = []
        
        for file in files {
            let v = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let size = v?.fileSize ?? 0
            let date = v?.contentModificationDate ?? Date.distantPast
            totalSize += size
            infos.append((file, size, date))
        }
        
        guard totalSize > maxDiskSize else { return }
        
        infos.sort { $0.date < $1.date }   // oldest first
        
        for info in infos {
            try? fileManager.removeItem(at: info.url)
            totalSize -= info.size
            if totalSize <= maxDiskSize { break }
        }
    }
}

// MARK: - AVAssetResourceLoaderDelegate
// Intercepts requests for the custom "fastpixcache://" scheme.
// Serves from disk on a HIT; fetches from network and saves on a MISS.
// Correctly sets content-type and content-length headers so AVFoundation
// accepts the response for HLS segments.

extension PrecacheManager: AVAssetResourceLoaderDelegate {
    
    public func resourceLoader(
        _ loader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource request: AVAssetResourceLoadingRequest
    ) -> Bool {
        
        guard let url = request.request.url else { return false }
        let originalURL = restoreOriginalScheme(url)
        
        if isCachedOnDisk(originalURL), let data = readFromDisk(originalURL) {
            delegate?.videoCacheDidHit(url: originalURL)
            fillResponse(request, data: data, url: originalURL)
            request.finishLoading()
            return true
        }
        
        delegate?.videoCacheDidMiss(url: originalURL)
        
        URLSession.shared.dataTask(with: originalURL) { [weak self] data, response, _ in
            guard let self, let data, let response else {
                request.finishLoading(with: URLError(.badServerResponse))
                return
            }
            self.saveSegmentToDisk(data, url: originalURL)
            self.fillResponse(request, data: data, url: originalURL)
            request.finishLoading()
        }.resume()
        
        return true
    }
    
    /// Populate content-information and data on the loading request.
    private func fillResponse(_ request: AVAssetResourceLoadingRequest, data: Data, url: URL) {
        if let info = request.contentInformationRequest {
            info.contentLength = Int64(data.count)
            info.isByteRangeAccessSupported = true
            // Determine MIME type from extension
            let ext = url.pathExtension.lowercased()
            switch ext {
            case "ts":
                info.contentType = "video/MP2T"
            case "m4s":
                info.contentType = "video/iso.segment"
            case "m3u8":
                info.contentType = "application/x-mpegURL"
            default:
                info.contentType = "application/octet-stream"
            }
        }
        // Serve the requested byte range (or all data if no range specified)
        if let dataRequest = request.dataRequest {
            let requestedOffset = Int(dataRequest.requestedOffset)
            let requestedLength = dataRequest.requestedLength
            let end = min(requestedOffset + requestedLength, data.count)
            if requestedOffset < data.count {
                dataRequest.respond(with: data[requestedOffset..<end])
            }
        }
    }
}
