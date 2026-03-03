
import AVFoundation

public struct SkipSegment {
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let type: SkipType
    
    public init(startTime: TimeInterval, endTime: TimeInterval, type: SkipType) {
        self.startTime = startTime
        self.endTime = endTime
        self.type = type
    }
}

public enum SkipType {
    case intro
    case song
    case credits
}

public enum SkipError: Error {
    case invalidTimeRange
    case startEqualsEnd
    case startExceedsDuration
    case endExceedsDuration
    case seekNotAllowed
    case noActiveSegment
}

public protocol FastPixSkipDelegate: AnyObject {
    func onSkipVisibilityChanged(isVisible: Bool, segment: SkipSegment?)
    func onSkipStarted()
    func onSkipCompleted()
    func onSkipFailed(error: SkipError)
}

public final class FastPixSkipManager {
    
    // MARK: - Properties
    private weak var player: AVPlayer?
    public weak var delegate: FastPixSkipDelegate?
    
    private var skipSegments: [SkipSegment] = []
    private var activeSegment: SkipSegment?
    private var timeObserver: Any?
    
    // MARK: - Init
    public init(player: AVPlayer) {
        self.player = player
        setupTimeObserver()
    }
    
    deinit {
        removeTimeObserver()
    }
    
    // MARK: - Public API
    public func setSkipSegments(_ segments: [SkipSegment]) {
        guard let duration = player?.currentItem?.duration.seconds,
              duration.isFinite,
              duration > 0 else {
            delegate?.onSkipFailed(error: .seekNotAllowed)
            return
        }
        
        do {
            try validateSegments(segments, duration: duration)
            skipSegments = segments
        } catch let error as SkipError {
            delegate?.onSkipFailed(error: error)
        } catch {
            delegate?.onSkipFailed(error: .invalidTimeRange)
        }
        self.activeSegment = nil
    }
    
    public func skipCurrentSegment() {
        guard let player else { return }
        
        guard let segment = activeSegment else {
            delegate?.onSkipFailed(error: .noActiveSegment)
            return
        }
        
        guard player.currentItem?.status == .readyToPlay else {
            delegate?.onSkipFailed(error: .seekNotAllowed)
            return
        }
        
        delegate?.onSkipStarted()
        
        let seekTime = CMTime(seconds: segment.endTime, preferredTimescale: 600)
        
        player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] success in
            guard let self else { return }
            
            if success {
                self.activeSegment = nil
                self.notifyVisibility(isVisible: false, segment: nil)
                self.delegate?.onSkipCompleted()
            } else {
                self.delegate?.onSkipFailed(error: .seekNotAllowed)
            }
        }
    }
    
    // MARK: - Validation
    private func validateSegments(
        _ segments: [SkipSegment],
        duration: TimeInterval
    ) throws {
        
        for segment in segments {
            
            if segment.startTime == segment.endTime {
                throw SkipError.startEqualsEnd
            }
            
            if segment.startTime > segment.endTime {
                throw SkipError.invalidTimeRange
            }
            
            if segment.startTime >= duration {
                throw SkipError.startExceedsDuration
            }
            
            if segment.endTime > duration {
                throw SkipError.endExceedsDuration
            }
        }
    }
    
    // MARK: - Time Observation
    private func setupTimeObserver() {
        guard let player else { return }
        
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            self?.evaluate(currentTime: time.seconds)
        }
    }
    
    private func removeTimeObserver() {
        if let observer = timeObserver, let player {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
    }
    
    private func evaluate(currentTime: TimeInterval) {
        
        let matchedSegment = skipSegments.first {
            currentTime >= $0.startTime &&
            currentTime < $0.endTime   // ✅ FIXED
        }
        
        if activeSegment == nil, let segment = matchedSegment {
            activeSegment = segment
            notifyVisibility(isVisible: true, segment: segment)
            return
        }
        
        if let active = activeSegment,
           matchedSegment == nil {
            activeSegment = nil
            notifyVisibility(isVisible: false, segment: active)
            return
        }
    }
    
    private func notifyVisibility(isVisible: Bool, segment: SkipSegment?) {
        delegate?.onSkipVisibilityChanged(
            isVisible: isVisible,
            segment: segment
        )
    }
    
    public func clearSegments() {
        skipSegments.removeAll()
        activeSegment = nil
        
        notifyVisibility(isVisible: false, segment: nil)
    }
}
