
import AVKit
import UIKit

public protocol FastPixPiPDelegate: AnyObject {
    func onPiPEnter()
    func onPiPExit()
    func onPiPStateChanged(isActive: Bool)
    func onPiPAvailabilityChanged(isAvailable: Bool)
    func onPiPSessionError(error: Error)
}

public final class FastPixPiPManager: NSObject, AVPictureInPictureControllerDelegate {
    
    private var pipController: AVPictureInPictureController?
    private weak var playerLayer: AVPlayerLayer?
    private weak var parentViewController: UIViewController?
    
    public weak var delegate: FastPixPiPDelegate?
    
    public var isEnabled: Bool = true
    
    public init(playerLayer: AVPlayerLayer, parent: UIViewController) {
        self.playerLayer = playerLayer
        self.parentViewController = parent
        super.init()
        
        if AVPictureInPictureController.isPictureInPictureSupported() {
            pipController = AVPictureInPictureController(playerLayer: playerLayer)
            pipController?.delegate = self
        }
    }
    
    public func isPiPAvailable() -> Bool {
        return isEnabled && pipController != nil
    }
    
    public func isPiPActive() -> Bool {
        return pipController?.isPictureInPictureActive ?? false
    }
    
    public func enterPiP() {
        guard isEnabled else { return }
        guard pipController?.isPictureInPictureActive == false else { return }
        pipController?.startPictureInPicture()
    }
    
    public func togglePiP() {
        guard isEnabled else { return }
        isPiPActive() ? exitPiP() : enterPiP()
    }
    
    public func exitPiP() {
        guard isEnabled else { return }
        guard pipController?.isPictureInPictureActive == true else { return }
        pipController?.stopPictureInPicture()
    }
    
    public func setPiPAudioBehavior(mixWithOthers: Bool) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: mixWithOthers ? [.mixWithOthers] : [])
    }
    
    // MARK: – Delegate methods
    public func pictureInPictureControllerDidStartPictureInPicture(_ controller: AVPictureInPictureController) {
        delegate?.onPiPEnter()
        delegate?.onPiPStateChanged(isActive: true)
    }
    
    public func pictureInPictureControllerDidStopPictureInPicture(_ controller: AVPictureInPictureController) {
        delegate?.onPiPExit()
        delegate?.onPiPStateChanged(isActive: false)
    }
    
    public func pictureInPictureController(_ controller: AVPictureInPictureController,
                                           failedToStartPictureInPictureWithError error: Error) {
        delegate?.onPiPSessionError(error: error)
    }
}
