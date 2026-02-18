
import Foundation
import AVFoundation

public final class FastPixPlaybackRateManager {
    
    // MARK: - Supported Rates
    public enum PlaybackRate: Float, CaseIterable {
        case x025 = 0.25
        case x05  = 0.5
        case x075 = 0.75
        case x1   = 1.0
        case x125 = 1.25
        case x15  = 1.5
        case x175 = 1.75
        case x2   = 2.0
    }
    
    // MARK: - Properties
    private weak var player: AVPlayer?
    private var playerItemObserver: NSKeyValueObservation?
    private var itemStatusObserver: NSKeyValueObservation?
    private var timeControlObserver: NSKeyValueObservation?
    private var storedRate: Float = 1.0
    
    // MARK: - Init
    public init(player: AVPlayer?) {
        attach(player: player)
    }
    
    // MARK: - Attach Player
    
    public func attach(player: AVPlayer?) {
        self.player = player
        observeCurrentItem()
        observeTimeControlStatus()
    }
    
    // MARK: - Observers
    
    /// Observe when currentItem changes (new video, replaced item, etc.)
    private func observeCurrentItem() {
        guard let player else { return }
        
        playerItemObserver = player.observe(\.currentItem, options: [.new]) { [weak self] _, _ in
            self?.observeItemStatus()
        }
        
        observeItemStatus()
    }
    
    /// Observe when item becomes ready
    private func observeItemStatus() {
        guard let item = player?.currentItem else { return }
        
        itemStatusObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard let self else { return }
            
            if item.status == .readyToPlay {
                self.applyStoredRate()
            }
        }
    }
    
    private func observeTimeControlStatus() {
        guard let player else { return }
        
        timeControlObserver = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            guard let self else { return }
            
            if player.timeControlStatus == .playing {
                self.applyStoredRate()
            }
        }
    }
    
    // MARK: - Public API
    
    public func setPlaybackSpeed(_ rate: PlaybackRate) {
        storedRate = rate.rawValue
        player?.rate = storedRate
    }
    
    public func setRate(_ rate: Float) {
        storedRate = rate
        player?.rate = storedRate
    }
    
    public func currentRate() -> Float {
        return storedRate
    }
    
    public func incrementPlaybackRate() {
        let rates = PlaybackRate.allCases
        guard let currentIndex = rates.firstIndex(where: { $0.rawValue == storedRate }) else { return }
        
        let newIndex = min(currentIndex + 1, rates.count - 1)
        storedRate = rates[newIndex].rawValue
        player?.rate = storedRate
    }
    
    public func decrementPlaybackRate() {
        let rates = PlaybackRate.allCases
        guard let currentIndex = rates.firstIndex(where: { $0.rawValue == storedRate }) else { return }
        
        let newIndex = max(currentIndex - 1, 0)
        storedRate = rates[newIndex].rawValue
        player?.rate = storedRate
    }
    
    public func applyStoredRate() {
        guard let player else { return }
        if player.rate != storedRate {
            player.rate = storedRate
        }
    }
}
