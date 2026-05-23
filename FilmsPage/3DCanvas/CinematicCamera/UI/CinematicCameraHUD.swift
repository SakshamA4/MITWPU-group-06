//
//  CinematicCameraHUD.swift
//  FilmsPage
//
//  Professional cinematic camera HUD overlay shown when looking through
//  a cinema camera. Extends the existing CameraViewOverlay with cinema-
//  specific readouts: camera body, sensor format, lens family, focal
//  length, cinematic look, aspect ratio, and motion style indicators.
//
//  Design language: minimal dark translucent pills with monospaced digits,
//  matching Apple Pro Apps (Final Cut, Compressor) and the existing HUD style.
//
//  Touch routing: hitTest returns nil for non-interactive areas so camera
//  gestures pass through to arView underneath.
//

import UIKit
import RealityKit

// MARK: - CinematicCameraHUD

/// Full-screen HUD overlay for cinema camera mode.
/// Displays camera body, lens, look, and recording info in a professional
/// cinematic viewfinder layout.
final class CinematicCameraHUD: UIView {
    
    // MARK: - Public Callbacks
    
    /// Called when the user taps the camera body badge to open the camera picker.
    var onCameraBodyTapped: (() -> Void)?
    
    /// Called when the user taps the lens badge to open the lens picker.
    var onLensTapped: (() -> Void)?
    
    /// Called when the user taps the look badge to open the look picker.
    var onLookTapped: (() -> Void)?
    
    /// Called when the user taps the aspect ratio badge to open the ratio picker.
    var onAspectRatioTapped: (() -> Void)?
    
    /// Called when the user taps the frame guide badge to toggle guides.
    var onFrameGuideTapped: (() -> Void)?
    
    /// Called when the user taps the motion style badge.
    var onMotionStyleTapped: (() -> Void)?
    
    // MARK: - Style Constants
    
    private let hudBg = UIColor(red: 0.04, green: 0.04, blue: 0.08, alpha: 0.75)
    private let accentColor = UIColor(red: 0.92, green: 0.32, blue: 0.18, alpha: 1.0)
    private let secondaryText = UIColor.white.withAlphaComponent(0.55)
    private let monoFont = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
    private let tinyFont = UIFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium)
    private let labelFont = UIFont.systemFont(ofSize: 10, weight: .medium)
    
    // MARK: - Top Bar Elements
    
    private let topBar = UIView()
    private let cameraNameLabel = UILabel()
    private let sensorFormatLabel = UILabel()
    private let resolutionLabel = UILabel()
    private let recDot = UIView()
    private let timecodeLabel = UILabel()
    
    // MARK: - Bottom Bar Elements
    
    private let bottomBar = UIView()
    private let cameraBodyButton = UIButton(type: .system)
    private let lensButton = UIButton(type: .system)
    private let focalLengthLabel = UILabel()
    private let lookButton = UIButton(type: .system)
    private let aspectButton = UIButton(type: .system)
    private let guideButton = UIButton(type: .system)
    private let motionButton = UIButton(type: .system)
    
    // MARK: - Side Indicators
    
    private let leftInfoStack = UIStackView()
    private let fovLabel = UILabel()
    private let cropLabel = UILabel()
    private let isoLabel = UILabel()
    
    /// All interactive controls for hit-test pass-through.
    private var interactiveControls: [UIView] {
        [cameraBodyButton, lensButton, lookButton, aspectButton,
         guideButton, motionButton, topBar, bottomBar]
    }
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        setupTopBar()
        setupBottomBar()
        setupSideIndicators()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        topBar.frame = CGRect(
            x: 0, y: safeAreaInsets.top,
            width: bounds.width, height: 36
        )
        bottomBar.frame = CGRect(
            x: 0, y: bounds.height - safeAreaInsets.bottom - 44,
            width: bounds.width, height: 44
        )
    }
    
    // MARK: - Touch Pass-Through
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for control in interactiveControls {
            guard !control.isHidden, control.alpha > 0.01 else { continue }
            let controlPoint = control.convert(point, from: self)
            if let hit = control.hitTest(controlPoint, with: event) {
                return hit
            }
        }
        return nil
    }
    
    // MARK: - Top Bar Setup
    
    private func setupTopBar() {
        topBar.backgroundColor = hudBg
        addSubview(topBar)
        
        // REC dot
        recDot.backgroundColor = accentColor
        recDot.layer.cornerRadius = 4
        recDot.translatesAutoresizingMaskIntoConstraints = false
        recDot.isHidden = true
        topBar.addSubview(recDot)
        
        // Camera name
        cameraNameLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        cameraNameLabel.textColor = .white
        cameraNameLabel.text = "ALEXA MINI LF"
        cameraNameLabel.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(cameraNameLabel)
        
        // Sensor format
        sensorFormatLabel.font = tinyFont
        sensorFormatLabel.textColor = secondaryText
        sensorFormatLabel.text = "LARGE FORMAT"
        sensorFormatLabel.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(sensorFormatLabel)
        
        // Resolution
        resolutionLabel.font = tinyFont
        resolutionLabel.textColor = secondaryText
        resolutionLabel.text = "4448×3096"
        resolutionLabel.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(resolutionLabel)
        
        // Timecode
        timecodeLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        timecodeLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        timecodeLabel.text = "00:00:00:00"
        timecodeLabel.textAlignment = .right
        timecodeLabel.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(timecodeLabel)
        
        NSLayoutConstraint.activate([
            recDot.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 16),
            recDot.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            recDot.widthAnchor.constraint(equalToConstant: 8),
            recDot.heightAnchor.constraint(equalToConstant: 8),
            
            cameraNameLabel.leadingAnchor.constraint(equalTo: recDot.trailingAnchor, constant: 10),
            cameraNameLabel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor, constant: -6),
            
            sensorFormatLabel.leadingAnchor.constraint(equalTo: cameraNameLabel.leadingAnchor),
            sensorFormatLabel.topAnchor.constraint(equalTo: cameraNameLabel.bottomAnchor, constant: 1),
            
            resolutionLabel.leadingAnchor.constraint(equalTo: sensorFormatLabel.trailingAnchor, constant: 8),
            resolutionLabel.centerYAnchor.constraint(equalTo: sensorFormatLabel.centerYAnchor),
            
            timecodeLabel.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -16),
            timecodeLabel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor)
        ])
    }
    
    // MARK: - Bottom Bar Setup
    
    private func setupBottomBar() {
        bottomBar.backgroundColor = hudBg
        addSubview(bottomBar)
        
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .center
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -12),
            stack.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            stack.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        // Camera body pill
        configurePillButton(cameraBodyButton, icon: "camera.fill", title: "BODY")
        cameraBodyButton.addTarget(self, action: #selector(cameraBodyTapped), for: .touchUpInside)
        stack.addArrangedSubview(cameraBodyButton)
        
        // Lens pill
        configurePillButton(lensButton, icon: "circle.circle", title: "50mm")
        lensButton.addTarget(self, action: #selector(lensTapped), for: .touchUpInside)
        stack.addArrangedSubview(lensButton)
        
        // Focal length readout
        focalLengthLabel.font = monoFont
        focalLengthLabel.textColor = accentColor
        focalLengthLabel.text = "50mm"
        focalLengthLabel.textAlignment = .center
        focalLengthLabel.translatesAutoresizingMaskIntoConstraints = false
        focalLengthLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
        stack.addArrangedSubview(focalLengthLabel)
        
        // Spacer
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(spacer)
        
        // Look pill
        configurePillButton(lookButton, icon: "paintpalette.fill", title: "LOOK")
        lookButton.addTarget(self, action: #selector(lookTapped), for: .touchUpInside)
        stack.addArrangedSubview(lookButton)
        
        // Aspect ratio pill
        configurePillButton(aspectButton, icon: "aspectratio.fill", title: "2.39")
        aspectButton.addTarget(self, action: #selector(aspectTapped), for: .touchUpInside)
        stack.addArrangedSubview(aspectButton)
        
        // Frame guide pill
        configurePillButton(guideButton, icon: "square.grid.3x3", title: "")
        guideButton.addTarget(self, action: #selector(guideTapped), for: .touchUpInside)
        stack.addArrangedSubview(guideButton)
        
        // Motion style pill
        configurePillButton(motionButton, icon: "waveform.path", title: "")
        motionButton.addTarget(self, action: #selector(motionTapped), for: .touchUpInside)
        stack.addArrangedSubview(motionButton)
    }
    
    // MARK: - Side Indicators
    
    private func setupSideIndicators() {
        leftInfoStack.axis = .vertical
        leftInfoStack.spacing = 4
        leftInfoStack.alignment = .leading
        leftInfoStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(leftInfoStack)
        
        configureSideLabel(fovLabel, text: "FOV 39.6°")
        configureSideLabel(cropLabel, text: "×1.0")
        configureSideLabel(isoLabel, text: "ISO 800")
        
        leftInfoStack.addArrangedSubview(fovLabel)
        leftInfoStack.addArrangedSubview(cropLabel)
        leftInfoStack.addArrangedSubview(isoLabel)
        
        NSLayoutConstraint.activate([
            leftInfoStack.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 12),
            leftInfoStack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    // MARK: - Public Update Methods
    
    /// Updates the HUD with current cinema camera configuration.
    func update(
        cameraBody: CinemaCameraBody?,
        lensFamily: CinemaLensFamily?,
        focalLength: Float,
        look: CinematicLook?,
        aspectRatio: CinemaAspectRatioPreset,
        motionStyle: CameraMotionStyle,
        fovDegrees: Float,
        cropFactor: Float
    ) {
        // Top bar
        cameraNameLabel.text = cameraBody?.name.uppercased() ?? "CINEMA CAMERA"
        sensorFormatLabel.text = cameraBody?.sensor.format.rawValue.uppercased() ?? "—"
        if let body = cameraBody {
            resolutionLabel.text = "\(body.nativeResolution.width)×\(body.nativeResolution.height)"
        }
        
        // Bottom bar pills
        updatePillTitle(cameraBodyButton, title: cameraBody?.brand.rawValue.uppercased() ?? "BODY")
        updatePillTitle(lensButton, title: lensFamily?.name ?? "LENS")
        focalLengthLabel.text = String(format: "%.0fmm", focalLength)
        updatePillTitle(lookButton, title: look?.name ?? "LOOK")
        updatePillTitle(aspectButton, title: aspectRatio.shortName)
        
        // Side indicators
        fovLabel.text = String(format: "FOV %.1f°", fovDegrees)
        cropLabel.text = String(format: "×%.2f", cropFactor)
    }
    
    /// Updates the timecode display.
    func updateTimecode(_ time: Float) {
        let totalFrames = Int(time * 24) // 24fps
        let hours = totalFrames / (24 * 3600)
        let minutes = (totalFrames % (24 * 3600)) / (24 * 60)
        let seconds = (totalFrames % (24 * 60)) / 24
        let frames = totalFrames % 24
        timecodeLabel.text = String(format: "%02d:%02d:%02d:%02d", hours, minutes, seconds, frames)
    }
    
    /// Shows/hides the REC indicator.
    func setRecording(_ isRecording: Bool) {
        recDot.isHidden = !isRecording
        if isRecording {
            // Pulse animation
            let pulse = CABasicAnimation(keyPath: "opacity")
            pulse.fromValue = 1.0
            pulse.toValue = 0.3
            pulse.duration = 0.8
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            recDot.layer.add(pulse, forKey: "pulse")
        } else {
            recDot.layer.removeAllAnimations()
        }
    }
    
    // MARK: - Button Actions
    
    @objc private func cameraBodyTapped() { onCameraBodyTapped?() }
    @objc private func lensTapped() { onLensTapped?() }
    @objc private func lookTapped() { onLookTapped?() }
    @objc private func aspectTapped() { onAspectRatioTapped?() }
    @objc private func guideTapped() { onFrameGuideTapped?() }
    @objc private func motionTapped() { onMotionStyleTapped?() }
    
    // MARK: - Private Helpers
    
    private func configurePillButton(_ button: UIButton, icon: String, title: String) {
        var config = UIButton.Configuration.filled()
        let imgCfg = UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
        config.image = UIImage(systemName: icon, withConfiguration: imgCfg)
        config.imagePadding = 4
        config.baseBackgroundColor = UIColor.white.withAlphaComponent(0.08)
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        
        if !title.isEmpty {
            config.attributedTitle = AttributedString(
                title,
                attributes: AttributeContainer([
                    .font: UIFont.systemFont(ofSize: 9, weight: .bold)
                ])
            )
        }
        
        button.configuration = config
        button.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func updatePillTitle(_ button: UIButton, title: String) {
        guard var config = button.configuration else { return }
        config.attributedTitle = AttributedString(
            title,
            attributes: AttributeContainer([
                .font: UIFont.systemFont(ofSize: 9, weight: .bold)
            ])
        )
        button.configuration = config
    }
    
    private func configureSideLabel(_ label: UILabel, text: String) {
        label.font = tinyFont
        label.textColor = secondaryText
        label.text = text
        label.backgroundColor = hudBg
        label.layer.cornerRadius = 6
        label.clipsToBounds = true
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
        label.heightAnchor.constraint(equalToConstant: 18).isActive = true
    }
}
