
import AVFoundation

// MARK: - Models

public struct SubtitleTrack {
    public let id: String
    public let languageCode: String
    public let label: String
    public let playlistURL: String?
    public let isSelected: Bool
}

public struct SubtitleRenderInfo {
    public let text: String
    public let timestamp: Double
    public let languageCode: String
}

public enum SubtitleTrackError: Error {
    case playerNotReady
    case noTracksAvailable
    case trackNotFound
    case switchingFailed
}

// MARK: - Delegate Protocol

public protocol FastPixSubtitleTrackDelegate: AnyObject {
    func onSubtitlesLoaded(tracks: [SubtitleTrack])
    func onSubtitleChange(track: SubtitleTrack?)
    func onSubtitleCueChange(information: SubtitleRenderInfo)
    func onSubtitlesLoadedFailed(error: SubtitleTrackError)
}

// MARK: - WebVTT Parser (Internal)

internal final class FastPixWebVTTParser {
    
    private weak var player: AVPlayer?
    private var timeObserver: Any?
    private var currentCues: [(start: Double, end: Double, text: String)] = []
    private var lastDisplayedText: String = ""
    private var activeFetchURLs = Set<String>()
    
    weak var delegate: FastPixSubtitleTrackDelegate?
    
    init(player: AVPlayer?) {
        self.player = player
    }
    
    // MARK: - Start / Stop
    
    func startTracking(subtitleM3U8URL: String) {
        stopTracking()
        fetchPlaylist(urlString: subtitleM3U8URL)
        startTimeObserver()
    }
    
    func stopTracking() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        currentCues = []
        lastDisplayedText = ""
        activeFetchURLs = []
    }
    
    // MARK: - Fetch Playlist → Segments → Cues
    
    private func fetchPlaylist(urlString: String) {
        guard let url = URL(string: urlString) else {
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self,
                  let data,
                  error == nil,
                  let text = String(data: data, encoding: .utf8) else {
                return
            }
            
            let segmentURLs = self.extractSegmentURLs(from: text, baseURL: urlString)
            
            for segURL in segmentURLs {
                guard !self.activeFetchURLs.contains(segURL) else { continue }
                self.activeFetchURLs.insert(segURL)
                self.fetchVTTSegment(urlString: segURL)
            }
        }.resume()
    }
    
    private func extractSegmentURLs(from text: String, baseURL: String) -> [String] {
        let base = baseURL
            .components(separatedBy: "/")
            .dropLast()
            .joined(separator: "/")
        
        return text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
            .map { line in
                line.hasPrefix("http") ? line : "\(base)/\(line)"
            }
    }
    
    private func fetchVTTSegment(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self,
                  let data,
                  error == nil,
                  let text = String(data: data, encoding: .utf8) else {
                return
            }
            
            let newCues = self.parseWebVTT(text: text)
            
            DispatchQueue.main.async {
                let existingKeys = Set(self.currentCues.map { "\($0.start)-\($0.end)" })
                let toAdd = newCues.filter { !existingKeys.contains("\($0.start)-\($0.end)") }
                self.currentCues.append(contentsOf: toAdd)
                self.currentCues.sort { $0.start < $1.start }
            }
        }.resume()
    }
    
    // MARK: - WebVTT Parser
    
    private func parseWebVTT(
        text: String
    ) -> [(start: Double, end: Double, text: String)] {
        
        var cues: [(start: Double, end: Double, text: String)] = []
        
        for block in text.components(separatedBy: "\n\n") {
            let lines = block
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            
            guard let timingLine = lines.first(where: { $0.contains("-->") }) else {
                continue
            }
            
            let parts = timingLine.components(separatedBy: "-->")
            guard parts.count == 2,
                  let start = parseVTTTimestamp(parts[0].trimmingCharacters(in: .whitespaces)),
                  let end   = parseVTTTimestamp(parts[1].trimmingCharacters(in: .whitespaces))
            else { continue }
            
            guard let timingIdx = lines.firstIndex(where: { $0.contains("-->") }) else {
                continue
            }
            
            let subtitleText = lines[(timingIdx + 1)...]
                .filter { !$0.hasPrefix("NOTE") && !$0.hasPrefix("WEBVTT") }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !subtitleText.isEmpty {
                cues.append((start: start, end: end, text: subtitleText))
            }
        }
        return cues
    }
    
    private func parseVTTTimestamp(_ string: String) -> Double? {
        let clean = string.components(separatedBy: " ").first ?? string
        let parts  = clean.components(separatedBy: ":")
        
        switch parts.count {
        case 3:
            guard let h = Double(parts[0]),
                  let m = Double(parts[1]),
                  let s = Double(parts[2]) else { return nil }
            return h * 3600 + m * 60 + s
        case 2:
            guard let m = Double(parts[0]),
                  let s = Double(parts[1]) else { return nil }
            return m * 60 + s
        default:
            return nil
        }
    }
    
    // MARK: - Time Observer
    
    private func startTimeObserver() {
        guard let player else { return }
        
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            self?.updateSubtitle(at: CMTimeGetSeconds(time))
        }
    }
    
    private func updateSubtitle(at currentTime: Double) {
        let text = currentCues
            .first { currentTime >= $0.start && currentTime <= $0.end }?
            .text ?? ""
        
        guard text != lastDisplayedText else { return }
        lastDisplayedText = text
        
        delegate?.onSubtitleCueChange(
            information: SubtitleRenderInfo(
                text: text,
                timestamp: currentTime,
                languageCode: ""
            )
        )
    }
}

// MARK: - Manifest Parser (Internal)
// Fetches the master .m3u8 and extracts subtitle playlist URLs by language

internal struct FastPixManifestParser {
    
    /// Parses an HLS master manifest and returns a map of [languageCode: subtitlePlaylistURL]
    /// e.g. ["fr": "https://...stream_French_subtitle.m3u8", "en": "https://..."]
    static func extractSubtitleURLs(
        from manifestURL: String,
        completion: @escaping ([String: String]) -> Void
    ) {
        guard let url = URL(string: manifestURL) else {
            completion([:])
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data,
                  error == nil,
                  let text = String(data: data, encoding: .utf8) else {
                completion([:])
                return
            }
            
            let result = parse(manifestText: text, baseURL: manifestURL)
            completion(result)
        }.resume()
    }
    
    /// Parses raw manifest text for EXT-X-MEDIA TYPE=SUBTITLES lines
    /// and extracts LANGUAGE + URI pairs
    private static func parse(
        manifestText: String,
        baseURL: String
    ) -> [String: String] {
        
        var subtitleURLs: [String: String] = [:]
        let base = baseURL
            .components(separatedBy: "/")
            .dropLast()
            .joined(separator: "/")
        
        let lines = manifestText.components(separatedBy: "\n")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Only process subtitle media lines
            guard trimmed.hasPrefix("#EXT-X-MEDIA"),
                  trimmed.contains("TYPE=SUBTITLES") else { continue }
            
            // Extract LANGUAGE="xx"
            guard let language = extractAttribute("LANGUAGE", from: trimmed) else {
                continue
            }
            
            // Extract URI="..."
            guard let uri = extractAttribute("URI", from: trimmed) else {
                continue
            }
            
            // Resolve relative URLs
            let resolvedURI = uri.hasPrefix("http") ? uri : "\(base)/\(uri)"
            subtitleURLs[language] = resolvedURI
        }
        
        return subtitleURLs
    }
    
    /// Extracts the value of a named attribute from an HLS tag line
    /// e.g. extractAttribute("LANGUAGE", from: #EXT-X-MEDIA:...,LANGUAGE="fr",...) → "fr"
    private static func extractAttribute(
        _ key: String,
        from line: String
    ) -> String? {
        
        // Match KEY="value" or KEY=value
        let pattern = "\(key)=\"([^\"]+)\""
        
        guard let range = line.range(of: pattern, options: .regularExpression) else {
            // Try unquoted fallback e.g. LANGUAGE=fr
            let plainPattern = "\(key)=([^,\\s]+)"
            guard let plainRange = line.range(of: plainPattern, options: .regularExpression) else {
                return nil
            }
            let match = String(line[plainRange])
            return match
                .replacingOccurrences(of: "\(key)=", with: "")
                .trimmingCharacters(in: .whitespaces)
        }
        
        return String(line[range])
            .replacingOccurrences(of: "\(key)=\"", with: "")
            .replacingOccurrences(of: "\"", with: "")
    }
}

// MARK: - Subtitle Track Manager (Public)

public final class FastPixSubtitleTrackManager: NSObject {
    
    // MARK: - Properties
    
    private weak var player: AVPlayer?
    private var vttParser: FastPixWebVTTParser?
    private var trackedItem: AVPlayerItem?
    
    // Keyed by languageCode e.g. ["fr": "https://...m3u8", "en": "https://...m3u8"]
    private var subtitleURLMap: [String: String] = [:]
    
    public weak var delegate: FastPixSubtitleTrackDelegate?
    
    private var preferredLanguageName: String?      // ← ADD THIS
    private var didApplyInitialSelection = false    // ← ADD THIS
    
    public func setPreferredSubtitleTrack(languageName: String?) {   // ← ADD THIS
        preferredLanguageName = languageName
    }
    
    /// Returns the label of the active track, or nil if subtitles are off
    public var currentSubtitleLabel: String? {
        getCurrentSubtitleTrack()?.label
    }
    
    // MARK: - Init
    
    public init(player: AVPlayer?) {
        self.player = player
    }
    
    deinit {
        detach()
    }
    
    // MARK: - Attach
    
    /// Call this whenever the player or its current item changes (e.g. playlist switch)
    public func attach(player: AVPlayer?) {
        detach()
        self.player = player
        
        guard let item = player?.currentItem else {
            return
        }
        
        trackedItem = item
        item.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
        
        if item.status == .readyToPlay {
            loadTracksAsync(for: item)
        }
    }
    
    // MARK: - Detach
    
    /// Call this on playlist change, viewWillDisappear, or deinit
    public func detach() {
        vttParser?.stopTracking()
        vttParser = nil
        subtitleURLMap = [:]
        didApplyInitialSelection = false // Added
        trackedItem?.removeObserver(self, forKeyPath: "status")
        trackedItem = nil
    }
    
    // MARK: - KVO
    
    public override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        guard keyPath == "status",
              let item = object as? AVPlayerItem,
              item.status == .readyToPlay else { return }
        
        loadTracksAsync(for: item)
    }
    
    // MARK: - Track Loading
    
    private func loadTracksAsync(for item: AVPlayerItem) {
        item.asset.loadValuesAsynchronously(
            forKeys: ["availableMediaCharacteristicsWithMediaSelectionOptions"]
        ) { [weak self] in
            DispatchQueue.main.async {
                self?.didLoadAsset(item: item)
            }
        }
    }
    
    private func didLoadAsset(item: AVPlayerItem) {
        guard let group = item.asset.mediaSelectionGroup(
            forMediaCharacteristic: .legible
        ) else {
            delegate?.onSubtitlesLoadedFailed(error: .noTracksAvailable)
            return
        }
        
        // Step 1: Build tracks from AVFoundation (no URLs yet)
        let currentOption = item.currentMediaSelection.selectedMediaOption(in: group)
        
        let avTracks: [(option: AVMediaSelectionOption, track: SubtitleTrack)] =
        group.options.map { option in
            let track = SubtitleTrack(
                id: option.extendedLanguageTag ?? option.displayName,
                languageCode: option.extendedLanguageTag ?? "",
                label: option.displayName,
                playlistURL: nil,
                isSelected: option == currentOption
            )
            return (option, track)
        }
        
        // Step 2: Fetch the master manifest to extract subtitle playlist URLs
        guard let urlAsset = item.asset as? AVURLAsset else {
            delegate?.onSubtitlesLoadedFailed(error: .noTracksAvailable)
            return
        }
        
        let manifestURL = urlAsset.url.absoluteString
        
        FastPixManifestParser.extractSubtitleURLs(from: manifestURL) { [weak self] urlMap in
            guard let self else { return }
            
            self.subtitleURLMap = urlMap
            
            // Step 3: Rebuild tracks with resolved URLs
            let tracks: [SubtitleTrack] = avTracks.map { (_, track) in
                SubtitleTrack(
                    id: track.id,
                    languageCode: track.languageCode,
                    label: track.label,
                    playlistURL: urlMap[track.languageCode],
                    isSelected: track.isSelected
                )
            }
            
            tracks.forEach { print("  •", $0.label, "[\($0.languageCode)]", "→", $0.playlistURL ?? "no URL") }
            
            self.delegate?.onSubtitlesLoaded(tracks: tracks)
            
            self.applyPreferredOrDefaultTrack(from: tracks)
        }
    }
    
    private func applyPreferredOrDefaultTrack(from tracks: [SubtitleTrack]) {
        guard !didApplyInitialSelection else { return }
        didApplyInitialSelection = true
        
        // 1️⃣ Try preferred language name first (case-insensitive)
        if let preferredName = preferredLanguageName,
           let preferredTrack = tracks.first(where: {
               $0.label.lowercased() == preferredName.lowercased()
           }),
           let url = preferredTrack.playlistURL {
            try? setSubtitleTrack(trackId: preferredTrack.id)
            return
        }
        
        // 2️⃣ Fall back to whatever AVFoundation already selected
        if let selected = tracks.first(where: { $0.isSelected }),
           let url = selected.playlistURL {
            startParser(for: selected, playlistURL: url)
        }
    }
    
    // MARK: - Public API
    
    /// Returns all available subtitle tracks for the current player item
    public func getSubtitleTracks() -> [SubtitleTrack] {
        guard let item = player?.currentItem,
              let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible)
        else { return [] }
        
        let current = item.currentMediaSelection.selectedMediaOption(in: group)
        
        return group.options.map { option in
            let langCode = option.extendedLanguageTag ?? ""
            return SubtitleTrack(
                id: option.extendedLanguageTag ?? option.displayName,
                languageCode: langCode,
                label: option.displayName,
                playlistURL: subtitleURLMap[langCode],
                isSelected: option == current
            )
        }
    }
    
    /// Returns the currently active subtitle track, or nil if subtitles are off
    public func getCurrentSubtitleTrack() -> SubtitleTrack? {
        guard let item = player?.currentItem,
              let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible),
              let option = item.currentMediaSelection.selectedMediaOption(in: group)
        else { return nil }
        
        let langCode = option.extendedLanguageTag ?? ""
        return SubtitleTrack(
            id: option.extendedLanguageTag ?? option.displayName,
            languageCode: langCode,
            label: option.displayName,
            playlistURL: subtitleURLMap[langCode],
            isSelected: true
        )
    }
    
    /// Switch to a subtitle track by its id (languageCode or displayName)
    public func setSubtitleTrack(trackId: String) throws {
        guard let item = player?.currentItem,
              let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible)
        else { throw SubtitleTrackError.playerNotReady }
        
        guard let option = group.options.first(where: {
            ($0.extendedLanguageTag ?? $0.displayName) == trackId
        }) else { throw SubtitleTrackError.trackNotFound }
        
        item.select(option, in: group)
        
        let langCode = option.extendedLanguageTag ?? ""
        
        guard let url = subtitleURLMap[langCode] else {
            throw SubtitleTrackError.switchingFailed
        }
        
        let selected = SubtitleTrack(
            id: option.extendedLanguageTag ?? option.displayName,
            languageCode: langCode,
            label: option.displayName,
            playlistURL: url,
            isSelected: true
        )
        
        startParser(for: selected, playlistURL: url)
        delegate?.onSubtitleChange(track: selected)
    }
    
    /// Turn off subtitles entirely
    public func disableSubtitles() {
        guard let item = player?.currentItem,
              let group = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible)
        else { return }
        
        item.select(nil, in: group)
        
        vttParser?.stopTracking()
        vttParser = nil
        
        delegate?.onSubtitleCueChange(
            information: SubtitleRenderInfo(text: "", timestamp: 0, languageCode: "")
        )
        delegate?.onSubtitleChange(track: nil)
    }
    
    // MARK: - Private Helpers
    
    private func startParser(for track: SubtitleTrack, playlistURL: String) {
        vttParser?.stopTracking()
        vttParser = FastPixWebVTTParser(player: player)
        vttParser?.delegate = delegate
        vttParser?.startTracking(subtitleM3U8URL: playlistURL)
    }
}
