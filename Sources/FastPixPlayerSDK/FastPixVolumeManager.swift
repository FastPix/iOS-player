
import Foundation
import AVFoundation
import MediaPlayer
import AVKit

// MARK: - Volume Delegate
public protocol FastPixVolumeDelegate: AnyObject {
    func fastPixVolumeDidChange(
        volume: Float,
        isMuted: Bool,
        isSystemChange: Bool
    )
}

// MARK: - Associated Keys
private struct FastPixVolumeKeys {
    static var delegate = "fastpix.volume.delegate"
    static var isMuted = "fastpix.volume.isMuted"
    static var observer = "fastpix.volume.observer"
    static var volumeView = "fastpix.volume.view"
    static var hideWorkItem = "fastpix.volume.hide.work"
}

// MARK: - Volume Manager
extension AVPlayerViewController {
    
    // MARK: Delegate
    public weak var fastPixVolumeDelegate: FastPixVolumeDelegate? {
        get {
            objc_getAssociatedObject(self, &FastPixVolumeKeys.delegate)
            as? FastPixVolumeDelegate
        }
        set {
            objc_setAssociatedObject(
                self,
                &FastPixVolumeKeys.delegate,
                newValue,
                .OBJC_ASSOCIATION_ASSIGN
            )
        }
    }
    
    // MARK: State
    private var fastpixIsMuted: Bool {
        get {
            (objc_getAssociatedObject(self, &FastPixVolumeKeys.isMuted) as? Bool) ?? false
        }
        set {
            objc_setAssociatedObject(
                self,
                &FastPixVolumeKeys.isMuted,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    
    private var volumeHideWorkItem: DispatchWorkItem? {
        get {
            objc_getAssociatedObject(self, &FastPixVolumeKeys.hideWorkItem)
            as? DispatchWorkItem
        }
        set {
            objc_setAssociatedObject(
                self,
                &FastPixVolumeKeys.hideWorkItem,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
    
    // MARK: - Setup (call once)
    public func setupVolumeManager() {
        configureAudioSession()
        observeSystemVolumeChanges()
        
        // Keep player volume fixed at 1.0
        player?.volume = 1.0
        
        // Sync initial mute state
        fastpixIsMuted = player?.isMuted ?? false
        
        // Initially hide slider
        fastPixVolumeDelegate?.fastPixVolumeDidChange(
            volume: -1, // signal hide
            isMuted: fastpixIsMuted,
            isSystemChange: false
        )
    }
    
    // MARK: Audio Session
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback)
            try session.setActive(true)
        } catch {
            print("VolumeManager: Audio session error - \(error)")
        }
    }
    
    // MARK: System Volume Listener
    private func observeSystemVolumeChanges() {
        
        let session = AVAudioSession.sharedInstance()
        
        let observer = session.observe(
            \.outputVolume,
             options: [.new]
        ) { [weak self] session, change in
            guard let self else { return }
            
            let systemVolume = change.newValue ?? session.outputVolume
            
            let shouldMute = systemVolume == 0
            
            self.fastpixIsMuted = shouldMute
            FastPixVolumeStore.update(controller: self) { state in
                state.isMuted = shouldMute
                if systemVolume > 0 {
                    state.lastNonZeroVolume = systemVolume
                }
            }
            
            self.player?.isMuted = shouldMute
            
            self.showVolumeSliderTemporarily(systemVolume: systemVolume)
        }
        
        objc_setAssociatedObject(
            self,
            &FastPixVolumeKeys.observer,
            observer,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
        
        let volumeView = MPVolumeView(frame: .zero)
        volumeView.isHidden = true
        view.addSubview(volumeView)
        
        objc_setAssociatedObject(
            self,
            &FastPixVolumeKeys.volumeView,
            volumeView,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }
    
    // MARK: Show / Hide Slider
    private func showVolumeSliderTemporarily(systemVolume: Float) {
        
        fastPixVolumeDelegate?.fastPixVolumeDidChange(
            volume: systemVolume,
            isMuted: fastpixIsMuted,
            isSystemChange: true
        )
        
        volumeHideWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.fastPixVolumeDelegate?.fastPixVolumeDidChange(
                volume: -1, // signal hide
                isMuted: self?.fastpixIsMuted ?? false,
                isSystemChange: true
            )
        }
        
        volumeHideWorkItem = workItem
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: workItem)
    }
    
    public func toggleMute() {
        let state = FastPixVolumeStore.state(for: self)
        
        if state.isMuted {
            let restore = state.lastNonZeroVolume > 0 ? state.lastNonZeroVolume : 0.5
            setVolume(restore)
        } else {
            setVolume(0)
        }
    }
    
    public func setVolume(_ volume: Float) {
        guard
            let volumeView = objc_getAssociatedObject(
                self,
                &FastPixVolumeKeys.volumeView
            ) as? MPVolumeView
        else { return }
        
        let clamped = min(max(volume, 0), 1)
        
        FastPixVolumeStore.update(controller: self) { state in
            if clamped > 0 {
                state.lastNonZeroVolume = clamped
            }
            state.isMuted = clamped == 0
        }
        
        player?.isMuted = clamped == 0
        
        if let slider = volumeView.subviews.compactMap({ $0 as? UISlider }).first {
            slider.value = clamped
        }
        
        let state = FastPixVolumeStore.state(for: self)
        
        fastPixVolumeDelegate?.fastPixVolumeDidChange(
            volume: clamped,
            isMuted: state.isMuted,
            isSystemChange: false
        )
    }
    
    public func isMuted() -> Bool {
        return fastpixIsMuted
    }
    
    public func getCurrentVolume() -> Float {
        return AVAudioSession.sharedInstance().outputVolume
    }
}

private struct FastPixVolumeState {
    var isMuted: Bool
    var lastNonZeroVolume: Float
}

private enum FastPixVolumeStore {
    static var states: [ObjectIdentifier: FastPixVolumeState] = [:]
    
    static func state(for controller: AVPlayerViewController) -> FastPixVolumeState {
        let key = ObjectIdentifier(controller)
        return states[key] ?? FastPixVolumeState(
            isMuted: false,
            lastNonZeroVolume: 0.5
        )
    }
    
    static func update(
        controller: AVPlayerViewController,
        _ block: (inout FastPixVolumeState) -> Void
    ) {
        let key = ObjectIdentifier(controller)
        var state = state(for: controller)
        block(&state)
        states[key] = state
    }
    
    static func remove(controller: AVPlayerViewController) {
        states.removeValue(forKey: ObjectIdentifier(controller))
    }
}
