
import UIKit

private class CustomSlider: UISlider {
    
    // Make the track taller and adjust origin to center vertically
    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        let originalRect = super.trackRect(forBounds: bounds)
        let newHeight: CGFloat = 8
        let newY = (bounds.height - newHeight) / 2
        return CGRect(x: originalRect.origin.x, y: newY, width: originalRect.width, height: newHeight)
    }
    
    // Optionally adjust thumb rect to prevent clipping
    override func thumbRect(forBounds bounds: CGRect, trackRect rect: CGRect, value: Float) -> CGRect {
        var thumbRect = super.thumbRect(forBounds: bounds, trackRect: rect, value: value)
        let offset: CGFloat = 2
        thumbRect.origin.y = max(thumbRect.origin.y - offset, 0)
        return thumbRect
    }
}

public class FastPixSeekBar: UIView {
    
    // UI Elements
    private let slider = CustomSlider()
    private let currentTimeLabel = UILabel()
    private let durationLabel = UILabel()
    private let bufferProgressView = UIProgressView()
    
    // Callbacks
    public var onSeekStart: ((TimeInterval) -> Void)?
    public var onSeekEnd: ((TimeInterval) -> Void)?
    
    // State
    private var isDragging = false
    public var duration: TimeInterval = 0
    
    private var currentTime: TimeInterval = 0
    
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
        bufferProgressView.trackTintColor = UIColor.white.withAlphaComponent(0.10) // Very light track
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
    }
    
    // MARK: - Layout
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        let labelWidth: CGFloat = 50
        let spacing: CGFloat = 10
        let verticalInset: CGFloat = 6          // Add vertical inset to avoid cropping
        let controlHeight = bounds.height - 2 * verticalInset
        
        // Current time label (left)
        currentTimeLabel.frame = CGRect(x: 0, y: 0, width: labelWidth, height: bounds.height)
        
        // Duration label (right)
        durationLabel.frame = CGRect(x: bounds.width - labelWidth, y: 0, width: labelWidth, height: bounds.height)
        
        // Slider (middle)
        let sliderX = labelWidth + spacing
        let sliderWidth = bounds.width - (labelWidth * 2) - (spacing * 2)
        slider.frame = CGRect(x: sliderX, y: 0, width: sliderWidth, height: bounds.height)
        
        // Buffer progress (same as slider)
        bufferProgressView.frame = CGRect(
            x: sliderX,
            y: (bounds.height - 4) / 2,
            width: sliderWidth,
            height: 4
        )
    }
    
    // MARK: - Slider Actions
    @objc private func sliderTouchDown() {
        isDragging = true
        onSeekStart?(TimeInterval(slider.value))
    }
    
    @objc private func sliderValueChanged() {
        if isDragging {
            let time = TimeInterval(slider.value)
            currentTimeLabel.text = formatTime(time)
        }
    }
    
    @objc private func sliderTouchUp() {
        isDragging = false
        let seekTime = TimeInterval(slider.value)
        onSeekEnd?(seekTime)
    }
    
    public func endDraggingAndReset() {
        isDragging = false
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
}

// MARK: - Orientation Support
extension FastPixSeekBar {
    
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        // Adjust layout for orientation change
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
        // Update the UI with restored values
        if !isDragging {
            slider.value = duration > 0 ? Float(currentTime / duration) : 0
            currentTimeLabel.text = formatTime(currentTime)
            durationLabel.text = formatTime(duration)
        }
    }
}
