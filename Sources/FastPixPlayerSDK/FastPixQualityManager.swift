
import AVFoundation
import UIKit

// MARK: - Model

public struct QualityLevel: Equatable {
    public let id: String
    public let label: String
    public let bitrate: Double
    public let resolution: CGSize
    public let frameRate: Double
    public let codec: String
    public let isAuto: Bool
    public var isActive: Bool
}

// MARK: - Errors

public enum QualityLevelError: Error {
    case playerNotReady
    case noLevelsAvailable
    case levelNotFound
    case switchingFailed
}

// MARK: - Delegate

public protocol FastPixQualityDelegate: AnyObject {
    func onQualityLevelsUpdated(levels: [QualityLevel])
    func onQualityLevelChanged(selectedLevel: QualityLevel)
    func onQualityLevelFailed(error: QualityLevelError)
    func onQualitySwitching(isSwitching: Bool)
}

// MARK: - Final Unified Manager

public final class FastPixQualityManager {
    
    // MARK: - Properties
    
    private weak var player: AVPlayer?
    public weak var delegate: FastPixQualityDelegate?
    
    private var levels: [QualityLevel] = []
    private var isAutoMode: Bool = true
    private var abrTimer: Timer?
    
    private var lastSelectedLevel: QualityLevel?
    private var lastSelectedBitrate: Double?
    private var lastSelectedResolution: CGSize?
    
    // MARK: - Init
    
    public init(player: AVPlayer?) {
        self.player = player
    }
    
    public func attach(player: AVPlayer?) {
        self.player = player
        loadQualityLevels()
        startABRMonitoring()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.reapplyQualityIfNeeded()
        }
    }
    
    private func codecName(from codec: CMVideoCodecType) -> String {
        switch codec {
        case kCMVideoCodecType_H264:
            return "H.264"
        case kCMVideoCodecType_HEVC:
            return "HEVC (H.265)"
        case kCMVideoCodecType_MPEG4Video:
            return "MPEG-4"
        default:
            return "unknown"
        }
    }
    
    // MARK: - Load Quality Levels (REAL HLS Parsing)
    
    @discardableResult
    public func loadQualityLevels() -> [QualityLevel] {
        
        guard let asset = player?.currentItem?.asset as? AVURLAsset else {
            delegate?.onQualityLevelFailed(error: .playerNotReady)
            return []
        }
        
        var extractedLevels: [QualityLevel] = []
        
        if #available(iOS 15.0, *) {
            
            for variant in asset.variants {
                
                let bitrate = variant.averageBitRate ?? 0
                let resolution = variant.videoAttributes?.presentationSize ?? .zero
                let frameRate = Double(variant.videoAttributes?.nominalFrameRate ?? 0)
                
                let codecType = variant.videoAttributes?.codecTypes.first
                let codec = codecType.map { codecName(from: $0) } ?? "unknown"
                
                let label = resolution.height > 0 ? "\(Int(resolution.height))p" : "Unknown"
                
                let level = QualityLevel(
                    id: "\(bitrate)-\(label)",
                    label: label,
                    bitrate: bitrate,
                    resolution: resolution,
                    frameRate: frameRate,
                    codec: codec,
                    isAuto: false,
                    isActive: false
                )
                
                extractedLevels.append(level)
            }
        }
        
        guard !extractedLevels.isEmpty else {
            delegate?.onQualityLevelFailed(error: .noLevelsAvailable)
            return []
        }
        
        // sort High → Low
        extractedLevels.sort { $0.bitrate > $1.bitrate }
        
        // AUTO Mode (Design Doc requirement)
        let auto = QualityLevel(
            id: "auto",
            label: "Auto",
            bitrate: 0,
            resolution: .zero,
            frameRate: 0,
            codec: "",
            isAuto: true,
            isActive: lastSelectedLevel == nil
        )
        
        levels = [auto] + extractedLevels
        
        if let last = lastSelectedLevel {
            updateActiveLevel(last)
        }
        
        delegate?.onQualityLevelsUpdated(levels: levels)
        
        return levels
    }
    
    // MARK: - Public APIs (Design Doc Aligned)
    
    public func getResolutionLevels() -> [QualityLevel] {
        return levels
    }
    
    public func getCurrentResolutionLevel() -> QualityLevel? {
        return levels.first(where: { $0.isActive })
    }
    
    public func setResolutionLevel(_ level: QualityLevel) {
        
        guard let player = player,
              let item = player.currentItem else {
            delegate?.onQualityLevelFailed(error: .playerNotReady)
            return
        }
        
        // Prevent duplicate selection
        if getCurrentResolutionLevel() == level { return }
        
        delegate?.onQualitySwitching(isSwitching: true)
        
        if level.isAuto {
            resetToAuto()
            lastSelectedLevel = nil
            delegate?.onQualitySwitching(isSwitching: false)
            return
        }
        
        isAutoMode = false
        lastSelectedLevel = level
        lastSelectedBitrate = level.bitrate
        lastSelectedResolution = level.resolution
        
        //switching (NO SEEK, NO PAUSE)
        item.preferredPeakBitRate = level.bitrate
        
        if #available(iOS 15.0, *) {
            item.preferredMaximumResolution = level.resolution
        }
        
        updateActiveLevel(level)
        
        delegate?.onQualityLevelChanged(selectedLevel: level)
        delegate?.onQualitySwitching(isSwitching: false)
    }
    
    public func reapplyQualityIfNeeded() {
        
        guard let item = player?.currentItem else { return }
        
        if isAutoMode {
            //Force AUTO explicitly
            item.preferredPeakBitRate = 0
            
            if #available(iOS 15.0, *) {
                item.preferredMaximumResolution = .zero
            }
            return
        }
        
        guard let bitrate = lastSelectedBitrate,
              let resolution = lastSelectedResolution else {
            return
        }
        
        item.preferredPeakBitRate = bitrate
        
        if #available(iOS 15.0, *) {
            item.preferredMaximumResolution = resolution
        }
    }
    
    public func setInitialResolutionLevel(_ level: QualityLevel) {
        setResolutionLevel(level)
    }
    
    public func resetToAuto() {
        guard let item = player?.currentItem else { return }
        
        isAutoMode = true
        lastSelectedLevel = nil
        lastSelectedBitrate = nil
        lastSelectedResolution = nil
        
        item.preferredPeakBitRate = 0
        
        if #available(iOS 15.0, *) {
            item.preferredMaximumResolution = .zero
        }
        
        if let auto = levels.first(where: { $0.isAuto }) {
            updateActiveLevel(auto)
            delegate?.onQualityLevelChanged(selectedLevel: auto)
        }
    }
    
    public func getAutoQualityLevel() -> QualityLevel? {
        return levels.first(where: { $0.isAuto })
    }
    
    // MARK: - ABR Control
    
    public func setABREnabled(_ enabled: Bool) {
        enabled ? resetToAuto() : ()
    }
    
    public func isABREnabled() -> Bool {
        return isAutoMode
    }
    
    // MARK: - Private Helpers
    
    private func updateActiveLevel(_ selected: QualityLevel) {
        levels = levels.map {
            var level = $0
            level.isActive = ($0.id == selected.id)
            return level
        }
    }
    
    // MARK: - ABR Monitoring (Design Doc Requirement ✅)
    
    private func startABRMonitoring() {
        
        abrTimer?.invalidate()
        
        abrTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.monitorABR()
        }
    }
    
    private func monitorABR() {
        
        guard let item = player?.currentItem,
              let event = item.accessLog()?.events.last else { return }
        
        let indicated = event.indicatedBitrate
        let observed = event.observedBitrate
        let resolution = event.indicatedBitrate > 0 ? "\(Int(indicated/1000)) kbps" : "N/A"
        
        //CRITICAL: Re-enforce manual quality
        if !isAutoMode {
            reapplyQualityIfNeeded()
        }
        
//        print("""
//           ABR INFO
//           Observed: \(observed)
//           Indicated: \(indicated)
//           Resolution (approx): \(resolution)
//           """)
    }
    
    deinit {
        abrTimer?.invalidate()
    }
}
