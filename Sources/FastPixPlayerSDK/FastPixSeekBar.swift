
import UIKit
import Foundation

private class CustomSlider: UISlider {
    
    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        let originalRect = super.trackRect(forBounds: bounds)
        let newHeight: CGFloat = 8
        let newY = (bounds.height - newHeight) / 2
        return CGRect(
            x: originalRect.origin.x,
            y: newY,
            width: originalRect.width,
            height: newHeight
        )
    }
    
    override func thumbRect(
        forBounds bounds: CGRect,
        trackRect rect: CGRect,
        value: Float
    ) -> CGRect {
        var thumbRect = super.thumbRect(forBounds: bounds, trackRect: rect, value: value)
        return thumbRect
    }
}

public class FastPixSeekBar: UIView {
    
    // UI Elements
    private let slider = CustomSlider()
    
    private let touchBlocker = UIView()
    
    // Expose slider pan gesture
    public var panGestureRecognizer: UIPanGestureRecognizer? {
        return slider.gestureRecognizers?
            .compactMap { $0 as? UIPanGestureRecognizer }
            .first
    }
    
    private let currentTimeLabel = UILabel()
    private let durationLabel = UILabel()
    private let bufferProgressView = UIProgressView()
    
    // Callbacks
    public var onSeekStart: ((TimeInterval) -> Void)?
    public var onSeekEnd: ((TimeInterval) -> Void)?
    
    // new: for spritesheet
    public var onPreviewScrub: ((TimeInterval) -> Void)?
    public var onPreviewVisibilityChanged: ((Bool, TimeInterval) -> Void)?
    
    public var previewView = FastPixSeekPreviewView()
    private var isPreviewVisible = false
    
    // State
    private var isDragging = false
    public var duration: TimeInterval = 0
    private var currentTime: TimeInterval = 0
    private var lastSeekTime: TimeInterval = 0   // NEW: last drag/seek position
    
    // MARK: - Initialization
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup UI
    private func setupUI() {
        // Buffer progress (behind slider)
        bufferProgressView.progressTintColor = UIColor.white.withAlphaComponent(0.35)  // Visible color
        bufferProgressView.trackTintColor = UIColor.white.withAlphaComponent(0.10)     // Very light track
        bufferProgressView.isUserInteractionEnabled = false
        
        bufferProgressView.transform = CGAffineTransform(scaleX: 1.0, y: 2.2)
        bufferProgressView.layer.cornerRadius = 2
        bufferProgressView.clipsToBounds = true
        addSubview(bufferProgressView)
        
        // Slider
        slider.minimumValue = 0
        slider.isContinuous = true
        slider.addTarget(self, action: #selector(sliderTouchDown), for: .touchDown)
        slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
        slider.addTarget(self, action: #selector(sliderTouchUp), for: [.touchUpInside, .touchUpOutside])
        addSubview(slider)
        
        // Time labels
        currentTimeLabel.font = .systemFont(ofSize: 12)
        currentTimeLabel.textColor = .white
        currentTimeLabel.text = "00:00"
        addSubview(currentTimeLabel)
        
        durationLabel.font = .systemFont(ofSize: 12)
        durationLabel.textColor = .white
        durationLabel.textAlignment = .right
        durationLabel.text = "00:00"
        addSubview(durationLabel)
        
        touchBlocker.backgroundColor = .clear
        touchBlocker.isUserInteractionEnabled = true
        touchBlocker.isHidden = true
        addSubview(touchBlocker)
        
        previewView.isHidden = true
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        let labelWidth: CGFloat = 50
        let spacing: CGFloat = 10
        
        // Labels
        currentTimeLabel.frame = CGRect(
            x: 0,
            y: 0,
            width: labelWidth,
            height: bounds.height
        )
        
        durationLabel.frame = CGRect(
            x: bounds.width - labelWidth,
            y: 0,
            width: labelWidth,
            height: bounds.height
        )
        
        // Slider between labels
        let sliderX = labelWidth + spacing
        let sliderWidth = max(0, bounds.width - labelWidth * 2 - spacing * 2)
        slider.frame = CGRect(
            x: sliderX,
            y: 0,
            width: sliderWidth,
            height: bounds.height
        )
        
        // Get the actual track rect from the slider
        let track = slider.trackRect(forBounds: slider.bounds)
        
        // Draw the gray buffer bar exactly where the real track is
        bufferProgressView.frame = CGRect(
            x: sliderX + track.origin.x,
            y: track.midY - 2,               // centered on track (4pt height)
            width: track.width,
            height: 4
        )
        repositionPreview()
        
        touchBlocker.frame = bounds
        bringSubviewToFront(slider)   // slider stays interactive
    }
    
    private func repositionPreview() {
        guard let superview = previewView.superview else { return }
        
        // Convert slider frame from seekbar to superview (playerViewController.view)
        let sliderFrameInSuperview = superview.convert(slider.frame, from: self)
        
        let progress = CGFloat(
            (slider.maximumValue == slider.minimumValue)
            ? 0
            : (slider.value - slider.minimumValue) / (slider.maximumValue - slider.minimumValue)
        )
        
        let thumbCenterX = sliderFrameInSuperview.minX + progress * sliderFrameInSuperview.width
        
        let previewSize = previewView.bounds.size
        guard previewSize.width > 0, previewSize.height > 0 else { return }
        
        var previewX = thumbCenterX - previewSize.width / 2
        let minX: CGFloat = 8
        let maxX = superview.bounds.width - previewSize.width - 8
        
        // Clamp so it never goes negative or off screen
        previewX = max(minX, min(maxX, previewX))
        
        var previewY = sliderFrameInSuperview.minY - previewSize.height - 8
        if previewY < 0 { previewY = 8 }
        
        previewView.frame = CGRect(
            x: previewX,
            y: previewY,
            width: previewSize.width,
            height: previewSize.height
        )
    }
    
    // MARK: - Slider Actions
    @objc private func sliderTouchDown() {
        isDragging = true
        let time = TimeInterval(slider.value)
        lastSeekTime = time                         // NEW
        onSeekStart?(time)
        setPreviewVisible(true, time: time)
        setNeedsLayout()
        touchBlocker.isHidden = false
    }
    
    @objc private func sliderValueChanged() {
        if isDragging {
            let time = TimeInterval(slider.value)
            lastSeekTime = time                     // NEW
            currentTimeLabel.text = formatTime(time)
            onPreviewScrub?(time)
            setPreviewVisible(true, time: time)
            setNeedsLayout()
        }
    }
    
    @objc private func sliderTouchUp() {
        isDragging = false
        let seekTime = TimeInterval(slider.value)
        lastSeekTime = seekTime                     // NEW
        onSeekEnd?(seekTime)
        setPreviewVisible(false, time: seekTime)
        setNeedsLayout()
        touchBlocker.isHidden = false
    }
    
    public func endDraggingAndReset() {
        isDragging = false
    }
    
    /// NEW: used by controller/SDK when system interrupts drag
    public func cancelActiveSeekIfNeeded() {
        guard isDragging else { return }
        isDragging = false
        
        let seekTime = lastSeekTime
        onSeekEnd?(seekTime)
        
        // NEW: fully clear preview thumbnail and timestamp
        previewView.imageView.image = nil
        previewView.label.text = ""
        previewView.isHidden = true
        
        setNeedsLayout()
    }
    
    private func setPreviewVisible(_ visible: Bool, time: TimeInterval) {
        
        guard isPreviewVisible != visible else {
            if visible {
                onPreviewVisibilityChanged?(true, time)
            }
            return
        }
        
        isPreviewVisible = visible
        previewView.isHidden = !visible
        onPreviewVisibilityChanged?(visible, time)
    }
    
    // MARK: - Public Update Methods
    
    /// Update current time (call this from your delegate)
    public func updateTime(current: TimeInterval, duration: TimeInterval) {
        self.duration = duration
        self.currentTime = current
        
        slider.minimumValue = 0
        slider.maximumValue = Float(duration > 0 ? duration : 1)
        
        if !isDragging {
            slider.value = Float(current)
            currentTimeLabel.text = formatTime(current)
        }
        
        durationLabel.text = formatTime(duration)
    }
    
    public func updateBuffer(loaded: TimeInterval, duration: TimeInterval) {
        guard duration > 0 else {
            bufferProgressView.progress = 0
            return
        }
        
        let bufferPercent = Float(loaded / duration)
        bufferProgressView.setProgress(bufferPercent, animated: false)
    }
    
    public func resetBuffer() {
        bufferProgressView.progress = 0
        slider.value = 0
        currentTimeLabel.text = "00:00"
        durationLabel.text = "00:00"
    }
    
    // MARK: - Helper
    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Touch cancellation safety
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        
        guard isDragging else { return }
        isDragging = false
        
        let seekTime = lastSeekTime
        onSeekEnd?(seekTime)
        setPreviewVisible(false, time: seekTime)
        setNeedsLayout()
    }
}

// MARK: - Orientation Support
extension FastPixSeekBar {
    
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        setNeedsLayout()
        layoutIfNeeded()
    }
    
    // Preserve seek state across orientation changes
    public func preserveState() -> [String: Any] {
        return [
            "currentTime": currentTime,
            "duration": duration,
            "isDragging": isDragging
        ]
    }
    
    public func restoreState(_ state: [String: Any]) {
        if let time = state["currentTime"] as? TimeInterval {
            currentTime = time
        }
        if let dur = state["duration"] as? TimeInterval {
            duration = dur
        }
        
        if !isDragging {
            slider.value = duration > 0 ? Float(currentTime / duration) : 0
            currentTimeLabel.text = formatTime(currentTime)
            durationLabel.text = formatTime(duration)
        }
    }
}

public final class FastPixSeekPreviewView: UIView {
    
    public let imageView = UIImageView()
    public let label = UILabel()
    
    /// Fixed label height
    private let labelHeight: CGFloat = 24
    
    var imageSize: CGSize = .zero {
        didSet { invalidateIntrinsicContentSize() }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        backgroundColor = .clear
        layer.cornerRadius = 4
        clipsToBounds = true
        
        // Use AspectFit so full image is visible, no cropping
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        addSubview(imageView)
        
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 1
        label.backgroundColor = .clear
        addSubview(label)
    }
    
    // Total intrinsic size = image + label(24)
    public override var intrinsicContentSize: CGSize {
        guard imageSize != .zero else { return .zero }
        return CGSize(width: imageSize.width,
                      height: imageSize.height + labelHeight)
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        // 1. Image gets the full area above the label
        let imageFrame = CGRect(
            x: 0,
            y: 0,
            width: bounds.width,
            height: bounds.height - labelHeight
        )
        imageView.frame = imageFrame
        
        // 2. Label is fixed 24pt bar at bottom
        label.frame = CGRect(
            x: 0,
            y: bounds.height - labelHeight,
            width: bounds.width,
            height: labelHeight
        )
    }
}

extension FastPixSeekBar {
    
    public func updatePreviewThumbnail(_ image: UIImage?, time: TimeInterval, useTimestamp: Bool) {
        if let image, !useTimestamp {
            // Show image + timestamp
            previewView.imageView.image = image
            previewView.imageView.isHidden = false
            previewView.label.isHidden = false
            previewView.label.text = formatTime(time)
        } else {
            // Show only timestamp (no image)
            previewView.imageView.isHidden = true
            previewView.label.isHidden = false
            previewView.label.text = formatTime(time)
        }
    }
}
