
import CoreMedia
import Foundation
import AVFoundation

// MARK: - Seek Event Delegate
public protocol FastPixSeekDelegate: AnyObject {
    func onSeekStart(at time: TimeInterval)
    func onSeekEnd(at time: TimeInterval)
    func onTimeUpdate(currentTime: TimeInterval, duration: TimeInterval)
    func onBufferedTimeUpdate(loaded: TimeInterval, duration: TimeInterval)
}

// MARK: - Seek Manager
public class FastPixSeekManager: NSObject{
    
    private weak var player: AVPlayer?
    private var timeObserver: Any?
    private var isSeekInProgress = false
    public weak var delegate: FastPixSeekDelegate?
    
    private var isObservingBuffer = false
    private weak var observedItem: AVPlayerItem?
    
    // Start time for "Continue Watching"
    private var startTime: TimeInterval = 0
    private var enableStartTimeResumeFlag = false
    public var shouldResumeAfterSeek = false
    
    public init(player: AVPlayer) {
        super.init()
        self.player = player
        setupTimeObserver()
        observeBufferingProgress()
    }
    
    // MARK: - Time Observer Setup
    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            guard let self = self, !self.isSeekInProgress else { return }
            
            let currentTime = time.seconds
            let duration = self.getDuration()
            
            self.delegate?.onTimeUpdate(currentTime: currentTime, duration: duration)
        }
    }
    
    private func observeBufferingProgress() {
        guard let item = player?.currentItem, !isObservingBuffer else { return }
        
        item.addObserver(
            self,
            forKeyPath: "loadedTimeRanges",
            options: [.new, .initial],
            context: nil
        )
        
        observedItem = item
        isObservingBuffer = true
    }
    
    // MARK: - Public API Functions
    
    public func getCurrentTime() -> TimeInterval {
        guard let player = player else { return 0 }
        return player.currentTime().seconds
    }
    
    public func getDuration() -> TimeInterval {
        guard let duration = player?.currentItem?.duration else { return 0 }
        return duration.isNumeric ? duration.seconds : 0
    }
    
    public func setStartTime(_ time: TimeInterval) {
        self.startTime = time
        if enableStartTimeResumeFlag && time > 0 {
            seekTo(time: time)
        }
    }
    
    public func enableStartTimeResume(_ enable: Bool) {
        self.enableStartTimeResumeFlag = enable
        if enable && startTime > 0 {
            seekTo(time: startTime)
        }
    }
    
    public func seekTo(time: TimeInterval, completion: ((Bool) -> Void)? = nil) {
        guard let player = player else {
            completion?(false)
            return
        }
        
        if player.timeControlStatus == .playing {
            shouldResumeAfterSeek = true
        } else if player.timeControlStatus == .paused {
            shouldResumeAfterSeek = false
        }
        
        isSeekInProgress = true
        delegate?.onSeekStart(at: time)
        
        let targetTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        let tolerance = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        player.seek(
            to: targetTime,
            toleranceBefore: tolerance,
            toleranceAfter: tolerance
        ) { [weak self] finished in
            self?.isSeekInProgress = false
            self?.delegate?.onSeekEnd(at: time)
            
            if self?.shouldResumeAfterSeek == true {
                player.play()
            } else {
                player.pause()
            }
            
            completion?(finished)
        }
    }
    
    public func seekToPercentage(_ percentage: Double, completion: ((Bool) -> Void)? = nil) {
        let duration = getDuration()
        let time = duration * max(0, min(1, percentage))
        seekTo(time: time, completion: completion)
    }
    
    public func seekForward(by seconds: TimeInterval = 10) {
        let currentTime = getCurrentTime()
        let duration = getDuration()
        let newTime = min(currentTime + seconds, duration)
        seekTo(time: newTime)
    }
    
    public func seekBackward(by seconds: TimeInterval = 10) {
        let currentTime = getCurrentTime()
        let newTime = max(currentTime - seconds, 0)
        seekTo(time: newTime)
    }
    
    override public func observeValue(forKeyPath keyPath: String?,
                                      of object: Any?,
                                      change: [NSKeyValueChangeKey : Any]?,
                                      context: UnsafeMutableRawPointer?) {
        
        if keyPath == "loadedTimeRanges",
           let item = object as? AVPlayerItem {
            
            guard let timeRange = item.loadedTimeRanges.first?.timeRangeValue else { return }
            
            // loadedTime = start + duration of the first buffered range
            let loadedTime = CMTimeGetSeconds(timeRange.start) + CMTimeGetSeconds(timeRange.duration)
            let duration = getDuration()
            
            // Send update to delegate
            delegate?.onBufferedTimeUpdate(loaded: loadedTime, duration: duration)
        }
    }
    
    public func cancelSeekIfNeeded() {
        if isSeekInProgress {
            isSeekInProgress = false
            delegate?.onSeekEnd(at: getCurrentTime())
        }
    }
    
    public func removeBufferObserver() {
        guard let item = observedItem, isObservingBuffer else { return }
        
        item.removeObserver(self, forKeyPath: "loadedTimeRanges")
        isObservingBuffer = false
        observedItem = nil
    }
    
    public func refreshBufferObservation() {
        removeBufferObserver()
        observeBufferingProgress()
    }
    
    // MARK: - Cleanup
    deinit {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        removeBufferObserver()
    }
}
