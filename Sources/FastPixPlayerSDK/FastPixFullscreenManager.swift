
import UIKit
import AVFoundation

public protocol FastPixFullscreenDelegate: AnyObject {
    func onFullscreenEnter()
    func onFullscreenExit()
    func onFullscreenStateChanged(isFullscreen: Bool)
    func onFullscreenOrientationChanged(isLandscape: Bool)
}

public  class FastPixFullscreenManager {
    
    weak var delegate: FastPixFullscreenDelegate?
    
    private weak var parentViewController: UIViewController?
    private weak var playerView: UIView?
    
    public var isFullscreenMode = false
    private var autoRotateEnabled = true
    private var autoHideTimeout: Double = 3.0
    
    private var normalConstraints: [NSLayoutConstraint] = []
    private var fullscreenConstraints: [NSLayoutConstraint] = []
    
    private var originalSuperview: UIView?
    private var originalConstraints: [NSLayoutConstraint] = []
    
    private var fullscreenVC: UIViewController?
    
    public init(playerView: UIView, parentViewController: UIViewController) {
        self.playerView = playerView
        self.parentViewController = parentViewController
    }
    
    // MARK: - Public Methods
    
    public func configureConstraints(normal: [NSLayoutConstraint],
                                     fullscreen: [NSLayoutConstraint]) {
        normalConstraints = normal
        fullscreenConstraints = fullscreen
        NSLayoutConstraint.activate(normalConstraints)
    }
    
    public func toggleFullscreen() {
        isFullscreenMode ? exitFullscreen() : enterFullscreen()
    }
    
    private func applyConstraints() {
        
        guard let controller = parentViewController else { return }
        
        NSLayoutConstraint.deactivate(isFullscreenMode ? normalConstraints : fullscreenConstraints)
        NSLayoutConstraint.activate(isFullscreenMode ? fullscreenConstraints : normalConstraints)
        
        UIView.animate(withDuration: 0.3) {
            controller.view.layoutIfNeeded()
        }
    }
    
    public func enterFullscreen() {
        guard !isFullscreenMode else { return }
        isFullscreenMode = true
        
        applyConstraints()
        
        delegate?.onFullscreenStateChanged(isFullscreen: true)
        delegate?.onFullscreenEnter()
        
        if autoRotateEnabled {
            UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue,
                                      forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
            delegate?.onFullscreenOrientationChanged(isLandscape: true)
        }
    }
    
    public func exitFullscreen() {
        guard isFullscreenMode else { return }
        isFullscreenMode = false
        
        applyConstraints()
        
        delegate?.onFullscreenStateChanged(isFullscreen: false)
        delegate?.onFullscreenExit()
        
        if autoRotateEnabled {
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue,
                                      forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
            delegate?.onFullscreenOrientationChanged(isLandscape: false)
        }
    }
    
    public func isFullscreen() -> Bool {
        return isFullscreenMode
    }
    
    public func setFullscreenAutoRotate(enabled: Bool) {
        autoRotateEnabled = enabled
    }
    
    public func setControlAutoHideTimeout(seconds: Double) {
        autoHideTimeout = seconds
    }
}
