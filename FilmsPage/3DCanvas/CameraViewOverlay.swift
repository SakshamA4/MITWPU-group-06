//
//  CameraViewOverlay.swift
//  3DCanvas
//
//  Full-screen HUD overlay shown when looking through a scene camera.
//  Contains: focal length slider, composition grid, focus controls.
//
//  Touch routing: hitTest returns nil for touches that don't land on
//  any HUD control, letting them pass through to arView underneath
//  so the camera-view gestures (point, dolly, truck, roll) work.
//

import UIKit
import RealityKit

final class CameraViewOverlay: UIView {

    // MARK: - Public State

    /// The camera root entity whose CameraFocusComponent we read/write.
    weak var cameraRoot: Entity?

    /// The PerspectiveCamera whose FOV we control via the slider.
    weak var perspectiveCamera: PerspectiveCamera?

    /// Called when the focal length slider or focus controls change a persisted value.
    var onSettingsChanged: (() -> Void)?

    /// Called when the user taps the screen in AF mode to request a focus raycast.
    var onAFTap: ((CGPoint) -> Void)?

    /// Aspect ratio of the active camera — used to compute the letterbox-safe rect
    /// so grid lines are clipped to the visible camera frame.
    var cameraAspectRatio: Float = 16.0 / 9.0

    // MARK: - Style Constants

    private let accentColor = UIColor(red: 0.9, green: 0.35, blue: 0.2, alpha: 1.0)
    private let hudBg       = UIColor(red: 0.06, green: 0.06, blue: 0.12, alpha: 0.85)
    private let hudFont     = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)

    // MARK: - UI Elements

    // ── Focal Length ──
    private let focalSlider    = UISlider()
    private let focalLabel     = UILabel()   // "35 mm"
    private let focalValueBadge = UILabel()  // floating badge near thumb

    // ── Grid ──
    private let gridButton     = UIButton(type: .system)
    private let gridPicker     = UIStackView()
    private let gridOverlay    = CAShapeLayer()
    private var selectedGrid: GridType = .none

    // ── Focus ──
    private let focusSegment   = UISegmentedControl(items: ["OFF", "AF", "MF"])
    private let leftSlider     = UISlider()   // MF: aperture
    private let rightSlider    = UISlider()   // MF: focus distance
    private let leftLabel      = UILabel()    // "f/5.6"
    private let rightLabel     = UILabel()    // "5.0m"
    private let leftTrack      = UIView()     // vertical slider container
    private let rightTrack     = UIView()     // vertical slider container
    private let focusBracket   = UIView()     // AF tap indicator

    // ── DoF Blur ──
    private var blurView: UIVisualEffectView?
    private let blurMaskLayer  = CAGradientLayer()
    /// Normalized focus point for AF mode (0…1, 0…1).
    private var afFocusPoint: CGPoint = CGPoint(x: 0.5, y: 0.5)

    // ── FOV Sync ──
    private var displayLink: CADisplayLink?
    /// Prevents the DisplayLink from fighting the user when they are actively dragging the slider.
    private var isDraggingFocalSlider = false

    /// All interactive subviews — used by hitTest to decide pass-through.
    private var interactiveControls: [UIView] {
        [focalSlider, focalLabel, gridButton, gridPicker,
         focusSegment, leftTrack, rightTrack]
    }

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        setupFocalLengthUI()
        setupGridUI()
        setupFocusUI()
        setupDisplayLink()
    }
    required init?(coder: NSCoder) { fatalError() }

    deinit {
        displayLink?.invalidate()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateGridOverlay()
        layoutVerticalSliders()
        updateBlurEffect()
    }

    // MARK: - Touch Pass-Through
    //
    // Only intercept touches that land on HUD controls (slider, segment, grid button).
    // Everything else passes through to arView so camera gestures work.

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // If the grid picker is visible, let it handle touches
        if !gridPicker.isHidden {
            let pickerPoint = gridPicker.convert(point, from: self)
            if let hit = gridPicker.hitTest(pickerPoint, with: event) {
                return hit
            }
        }

        // Check each interactive control
        for control in interactiveControls {
            guard !control.isHidden, control.alpha > 0.01 else { continue }
            let controlPoint = control.convert(point, from: self)
            if let hit = control.hitTest(controlPoint, with: event) {
                return hit
            }
        }

        // AF mode: let taps through to this view for focus bracket
        if focusSegment.selectedSegmentIndex == 1 {
            // Check if it's a tap (not a drag) — we return self for the tap gesture
            return self
        }

        // Otherwise, pass through to arView below
        return nil
    }

    // MARK: - Configuration

    /// Call after setting cameraRoot / perspectiveCamera to sync UI with stored values.
    func configure(cameraRoot: Entity, camera: PerspectiveCamera) {
        self.cameraRoot = cameraRoot
        self.perspectiveCamera = camera

        // Read aspect ratio from camera root
        if let aspectComp = cameraRoot.components[CameraAspectComponent.self] {
            cameraAspectRatio = aspectComp.aspectRatio.ratio
        }

        let comp = cameraRoot.components[CameraFocusComponent.self] ?? CameraFocusComponent()

        // Focal length
        let mm = comp.focalLengthMM
        focalSlider.value = mm
        updateFocalLabels(mm)

        // Grid
        selectedGrid = comp.gridType
        updateGridOverlay()

        // Focus
        switch comp.mode {
        case .off:         focusSegment.selectedSegmentIndex = 0
        case .autoFocus:   focusSegment.selectedSegmentIndex = 1
        case .manualFocus: focusSegment.selectedSegmentIndex = 2
        }
        leftSlider.value  = comp.aperture
        rightSlider.value = comp.focusDistance
        updateFocusMode()
        updateFocusLabels()
    }

    // MARK: - Letterbox-Safe Rect
    //
    // Computes the visible camera frame inside the letterbox bars.
    // Grid lines are drawn only within this rect.

    private var letterboxSafeRect: CGRect {
        let viewSize = bounds.size
        guard viewSize.width > 0, viewSize.height > 0 else { return bounds }

        let viewRatio = Float(viewSize.width / viewSize.height)
        let targetRatio = cameraAspectRatio

        if abs(viewRatio - targetRatio) < 0.01 {
            return bounds // No letterbox needed
        }

        if targetRatio < viewRatio {
            // Pillarbox: narrower — bars on left/right
            let targetWidth = viewSize.height * CGFloat(targetRatio)
            let barWidth = (viewSize.width - targetWidth) / 2.0
            return CGRect(x: barWidth, y: 0, width: targetWidth, height: viewSize.height)
        } else {
            // Letterbox: wider — bars on top/bottom
            let targetHeight = viewSize.width / CGFloat(targetRatio)
            let barHeight = (viewSize.height - targetHeight) / 2.0
            return CGRect(x: 0, y: barHeight, width: viewSize.width, height: targetHeight)
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - Focal Length Slider
    // ══════════════════════════════════════════════════════════════════════

    private func setupFocalLengthUI() {
        // ── Slider ──
        focalSlider.minimumValue = 10
        focalSlider.maximumValue = 200
        focalSlider.value = 35
        focalSlider.minimumTrackTintColor = accentColor
        focalSlider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.15)
        focalSlider.addTarget(self, action: #selector(focalSliderBegan), for: .touchDown)
        focalSlider.addTarget(self, action: #selector(focalSliderChanged), for: .valueChanged)
        focalSlider.addTarget(self, action: #selector(focalSliderEnded), for: [.touchUpInside, .touchUpOutside])
        focalSlider.translatesAutoresizingMaskIntoConstraints = false
        addSubview(focalSlider)

        // ── Label badge ── "35 mm"
        focalLabel.text = "35 mm"
        focalLabel.font = hudFont
        focalLabel.textColor = .white
        focalLabel.backgroundColor = hudBg
        focalLabel.textAlignment = .center
        focalLabel.layer.cornerRadius = 10
        focalLabel.clipsToBounds = true
        focalLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(focalLabel)

        // ── Value badge near thumb ──
        focalValueBadge.font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold)
        focalValueBadge.textColor = accentColor
        focalValueBadge.textAlignment = .center
        focalValueBadge.translatesAutoresizingMaskIntoConstraints = false
        focalValueBadge.isHidden = true
        addSubview(focalValueBadge)

        NSLayoutConstraint.activate([
            focalLabel.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 16),
            focalLabel.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -115),
            focalLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 54),
            focalLabel.heightAnchor.constraint(equalToConstant: 26),

            focalSlider.leadingAnchor.constraint(equalTo: focalLabel.trailingAnchor, constant: 12),
            focalSlider.centerYAnchor.constraint(equalTo: focalLabel.centerYAnchor),
            // Leave room for the focus segment (130pt) + margin (16pt + 16pt)
            focalSlider.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -170)
        ])

        updateFocalLabels(35)
    }

    @objc private func focalSliderBegan() {
        isDraggingFocalSlider = true
        focalValueBadge.isHidden = false
    }

    @objc private func focalSliderChanged() {
        let mm = focalSlider.value
        let snapped = snapToStandardFocalLength(mm)
        updateFocalLabels(snapped)

        // Update camera FOV
        let fov = focalLengthToFOV(snapped)
        perspectiveCamera?.camera.fieldOfViewInDegrees = fov

        // Update component
        updateComponent { $0.focalLengthMM = snapped }

        focalValueBadge.isHidden = false
    }

    @objc private func focalSliderEnded() {
        isDraggingFocalSlider = false
        focalValueBadge.isHidden = true
        onSettingsChanged?()
    }

    private func updateFocalLabels(_ mm: Float) {
        let rounded = Int(mm)
        focalLabel.text = " \(rounded) mm "
        focalValueBadge.text = "\(rounded)"
    }

    /// Snap to common focal lengths when close (within ±2mm).
    private func snapToStandardFocalLength(_ mm: Float) -> Float {
        let standards: [Float] = [10, 14, 18, 24, 28, 35, 50, 70, 85, 100, 135, 200]
        for s in standards where abs(mm - s) < 2.5 { return s }
        return round(mm)
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - Grid Overlay
    // ══════════════════════════════════════════════════════════════════════

    private func setupGridUI() {
        // ── Grid toggle button ──
        let gridCfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        gridButton.setImage(UIImage(systemName: "square.grid.3x3", withConfiguration: gridCfg), for: .normal)
        gridButton.tintColor = .white
        gridButton.backgroundColor = hudBg
        gridButton.layer.cornerRadius = 16
        gridButton.addTarget(self, action: #selector(gridButtonTapped), for: .touchUpInside)
        gridButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(gridButton)

        NSLayoutConstraint.activate([
            // Offset 70pt from leading to clear the exit camera (back) button (44pt + 26pt gap)
            gridButton.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 70),
            gridButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
            gridButton.widthAnchor.constraint(equalToConstant: 36),
            gridButton.heightAnchor.constraint(equalToConstant: 36)
        ])

        // ── Grid type picker (floating pill bar) ──
        gridPicker.axis = .horizontal
        gridPicker.spacing = 4
        gridPicker.alignment = .center
        gridPicker.distribution = .fillEqually
        gridPicker.backgroundColor = UIColor.white.withAlphaComponent(0.95)
        gridPicker.layer.cornerRadius = 20
        gridPicker.clipsToBounds = true
        gridPicker.isHidden = true
        gridPicker.translatesAutoresizingMaskIntoConstraints = false
        gridPicker.isLayoutMarginsRelativeArrangement = true
        gridPicker.layoutMargins = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        addSubview(gridPicker)

        // Grid type icons
        let gridIcons: [(String, GridType)] = [
            ("rectangle", .none),
            ("square.grid.3x3", .ruleOfThirds),
            ("square.grid.4x3.fill", .fourByFour),
            ("arrow.up.right.and.arrow.down.left", .diagonal),
            ("square.grid.3x3.middleright.filled", .diagonalThirds),
            ("plus", .centerCross)
        ]
        for (idx, (icon, type)) in gridIcons.enumerated() {
            let btn = UIButton(type: .system)
            let cfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
            btn.setImage(UIImage(systemName: icon, withConfiguration: cfg), for: .normal)
            btn.tintColor = type == selectedGrid ? accentColor : .darkGray
            btn.tag = idx
            btn.addTarget(self, action: #selector(gridTypeTapped(_:)), for: .touchUpInside)
            gridPicker.addArrangedSubview(btn)
        }
        // Close button
        let closeBtn = UIButton(type: .system)
        closeBtn.setImage(UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)), for: .normal)
        closeBtn.tintColor = .darkGray
        closeBtn.addTarget(self, action: #selector(closeGridPicker), for: .touchUpInside)
        gridPicker.addArrangedSubview(closeBtn)

        NSLayoutConstraint.activate([
            gridPicker.centerXAnchor.constraint(equalTo: centerXAnchor),
            gridPicker.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 8),
            gridPicker.heightAnchor.constraint(equalToConstant: 40)
        ])

        // ── Grid overlay layer ──
        gridOverlay.strokeColor = UIColor.white.withAlphaComponent(0.4).cgColor
        gridOverlay.fillColor   = nil
        gridOverlay.lineWidth   = 0.5
        layer.addSublayer(gridOverlay)
    }

    @objc private func gridButtonTapped() {
        gridPicker.isHidden.toggle()
    }

    @objc private func closeGridPicker() {
        gridPicker.isHidden = true
    }

    @objc private func gridTypeTapped(_ sender: UIButton) {
        let types = GridType.allCases
        guard sender.tag < types.count else { return }
        selectedGrid = types[sender.tag]
        updateGridOverlay()
        updateComponent { $0.gridType = self.selectedGrid }
        onSettingsChanged?()

        // Update button tints
        for (idx, view) in gridPicker.arrangedSubviews.enumerated() {
            if let btn = view as? UIButton, idx < types.count {
                btn.tintColor = types[idx] == selectedGrid ? accentColor : .darkGray
            }
        }
        gridPicker.isHidden = true
    }

    /// Draws grid lines ONLY within the letterbox-safe rect (the visible camera frame).
    private func updateGridOverlay() {
        let path = UIBezierPath()
        // Use the letterbox-safe rect, not full overlay bounds
        let rect = letterboxSafeRect
        guard rect.width > 0, rect.height > 0 else {
            gridOverlay.path = nil
            return
        }

        gridOverlay.frame = bounds

        switch selectedGrid {
        case .none:
            break
        case .ruleOfThirds:
            let w = rect.width, h = rect.height
            for i in 1...2 {
                let x = rect.minX + w * CGFloat(i) / 3.0
                path.move(to: CGPoint(x: x, y: rect.minY))
                path.addLine(to: CGPoint(x: x, y: rect.maxY))
                let y = rect.minY + h * CGFloat(i) / 3.0
                path.move(to: CGPoint(x: rect.minX, y: y))
                path.addLine(to: CGPoint(x: rect.maxX, y: y))
            }
        case .fourByFour:
            let w = rect.width, h = rect.height
            for i in 1...3 {
                let x = rect.minX + w * CGFloat(i) / 4.0
                path.move(to: CGPoint(x: x, y: rect.minY))
                path.addLine(to: CGPoint(x: x, y: rect.maxY))
                let y = rect.minY + h * CGFloat(i) / 4.0
                path.move(to: CGPoint(x: rect.minX, y: y))
                path.addLine(to: CGPoint(x: rect.maxX, y: y))
            }
        case .diagonal:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        case .diagonalThirds:
            let w = rect.width, h = rect.height
            for i in 1...2 {
                let x = rect.minX + w * CGFloat(i) / 3.0
                path.move(to: CGPoint(x: x, y: rect.minY))
                path.addLine(to: CGPoint(x: x, y: rect.maxY))
                let y = rect.minY + h * CGFloat(i) / 3.0
                path.move(to: CGPoint(x: rect.minX, y: y))
                path.addLine(to: CGPoint(x: rect.maxX, y: y))
            }
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        case .centerCross:
            let cx = rect.midX, cy = rect.midY
            path.move(to: CGPoint(x: cx, y: rect.minY))
            path.addLine(to: CGPoint(x: cx, y: rect.maxY))
            path.move(to: CGPoint(x: rect.minX, y: cy))
            path.addLine(to: CGPoint(x: rect.maxX, y: cy))
        }

        gridOverlay.path = path.cgPath
    }

    // ══════════════════════════════════════════════════════════════════════
    // MARK: - Focus Controls
    // ══════════════════════════════════════════════════════════════════════

    private func setupFocusUI() {
        // ── Mode segment ──
        focusSegment.selectedSegmentIndex = 0
        focusSegment.backgroundColor = hudBg
        focusSegment.selectedSegmentTintColor = accentColor
        focusSegment.setTitleTextAttributes([.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 11, weight: .bold)], for: .selected)
        focusSegment.setTitleTextAttributes([.foregroundColor: UIColor.white.withAlphaComponent(0.6), .font: UIFont.systemFont(ofSize: 11, weight: .medium)], for: .normal)
        focusSegment.addTarget(self, action: #selector(focusModeChanged), for: .valueChanged)
        focusSegment.translatesAutoresizingMaskIntoConstraints = false
        addSubview(focusSegment)

        NSLayoutConstraint.activate([
            focusSegment.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -16),
            focusSegment.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -60),
            focusSegment.widthAnchor.constraint(equalToConstant: 130),
            focusSegment.heightAnchor.constraint(equalToConstant: 28)
        ])

        // ── Left vertical slider (Aperture) ──
        setupVerticalSlider(leftSlider, track: leftTrack, label: leftLabel,
                            leading: true, minVal: 1.4, maxVal: 22, initial: 5.6)
        leftSlider.addTarget(self, action: #selector(apertureChanged), for: .valueChanged)
        leftSlider.addTarget(self, action: #selector(focusSliderEnded), for: [.touchUpInside, .touchUpOutside])

        // ── Right vertical slider (Focus Distance) ──
        setupVerticalSlider(rightSlider, track: rightTrack, label: rightLabel,
                            leading: false, minVal: 0.5, maxVal: 20, initial: 5.0)
        rightSlider.addTarget(self, action: #selector(focusDistanceChanged), for: .valueChanged)
        rightSlider.addTarget(self, action: #selector(focusSliderEnded), for: [.touchUpInside, .touchUpOutside])

        // ── AF tap bracket ──
        focusBracket.frame = CGRect(x: 0, y: 0, width: 60, height: 60)
        focusBracket.layer.borderColor = accentColor.cgColor
        focusBracket.layer.borderWidth = 1.5
        focusBracket.layer.cornerRadius = 4
        focusBracket.isHidden = true
        focusBracket.isUserInteractionEnabled = false
        addSubview(focusBracket)

        // AF tap gesture
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleAFTap(_:)))
        addGestureRecognizer(tap)

        updateFocusMode()
        updateFocusLabels()
    }

    private func setupVerticalSlider(_ slider: UISlider, track: UIView, label: UILabel,
                                      leading: Bool, minVal: Float, maxVal: Float, initial: Float) {
        track.backgroundColor = .clear
        track.isHidden = true
        track.translatesAutoresizingMaskIntoConstraints = false
        addSubview(track)

        slider.minimumValue = minVal
        slider.maximumValue = maxVal
        slider.value = initial
        slider.minimumTrackTintColor = accentColor
        slider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.15)
        slider.translatesAutoresizingMaskIntoConstraints = false
        track.addSubview(slider)

        label.font = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = hudBg
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        track.addSubview(label)

        let side: NSLayoutXAxisAnchor = leading ? safeAreaLayoutGuide.leadingAnchor : safeAreaLayoutGuide.trailingAnchor
        let offset: CGFloat = leading ? 20 : -20

        NSLayoutConstraint.activate([
            track.widthAnchor.constraint(equalToConstant: 40),
            track.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 60),
            track.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -100),
            leading ? track.leadingAnchor.constraint(equalTo: side, constant: offset)
                    : track.trailingAnchor.constraint(equalTo: side, constant: offset)
        ])

        // Slider rotated -90° to make it vertical
        NSLayoutConstraint.activate([
            slider.centerXAnchor.constraint(equalTo: track.centerXAnchor),
            slider.centerYAnchor.constraint(equalTo: track.centerYAnchor),
            slider.widthAnchor.constraint(equalTo: track.heightAnchor)
        ])
        slider.transform = CGAffineTransform(rotationAngle: -.pi / 2)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: track.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: track.bottomAnchor),
            label.widthAnchor.constraint(greaterThanOrEqualToConstant: 40)
        ])
    }

    private func layoutVerticalSliders() {
        leftSlider.layoutIfNeeded()
        rightSlider.layoutIfNeeded()
    }

    @objc private func focusModeChanged() {
        let mode: CameraFocusComponent.FocusMode
        switch focusSegment.selectedSegmentIndex {
        case 1:  mode = .autoFocus
        case 2:  mode = .manualFocus
        default: mode = .off
        }
        updateComponent { $0.mode = mode }
        updateFocusMode()
        updateBlurEffect()
        onSettingsChanged?()
    }

    @objc private func apertureChanged() {
        updateComponent { $0.aperture = self.leftSlider.value }
        updateFocusLabels()
        updateBlurEffect()
    }

    @objc private func focusDistanceChanged() {
        updateComponent { $0.focusDistance = self.rightSlider.value }
        updateFocusLabels()
        updateBlurEffect()
    }

    @objc private func focusSliderEnded() {
        onSettingsChanged?()
    }

    @objc private func handleAFTap(_ gesture: UITapGestureRecognizer) {
        guard focusSegment.selectedSegmentIndex == 1 else { return } // AF mode only
        let point = gesture.location(in: self)

        // Show focus bracket animation
        focusBracket.center = point
        focusBracket.isHidden = false
        focusBracket.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        focusBracket.alpha = 1

        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) {
            self.focusBracket.transform = .identity
        }
        UIView.animate(withDuration: 0.3, delay: 1.0) {
            self.focusBracket.alpha = 0
        } completion: { _ in
            self.focusBracket.isHidden = true
            self.focusBracket.alpha = 1
        }

        // Store normalized focus point
        let nx = Float(point.x / bounds.width)
        let ny = Float(point.y / bounds.height)
        afFocusPoint = CGPoint(x: CGFloat(nx), y: CGFloat(ny))
        updateComponent {
            $0.focusPointX = nx
            $0.focusPointY = ny
        }
        updateBlurEffect()
        onSettingsChanged?()
        onAFTap?(point)
    }

    private func updateFocusMode() {
        let isMF = focusSegment.selectedSegmentIndex == 2
        leftTrack.isHidden  = !isMF
        rightTrack.isHidden = !isMF
        focusBracket.isHidden = true
    }

    private func updateFocusLabels() {
        let fStop = leftSlider.value
        leftLabel.text = String(format: " f/%.1f ", fStop)
        let dist = rightSlider.value
        rightLabel.text = String(format: " %.1fm ", dist)
    }

    /// Programmatically update focus distance (e.g. from AF raycast)
    func setFocusDistance(_ distance: Float) {
        rightSlider.value = max(rightSlider.minimumValue, min(rightSlider.maximumValue, distance))
        updateFocusLabels()
        updateBlurEffect()
    }

    // MARK: - ECS Component Helper

    private func updateComponent(_ mutate: (inout CameraFocusComponent) -> Void) {
        guard let root = cameraRoot else { return }
        var comp = root.components[CameraFocusComponent.self] ?? CameraFocusComponent()
        mutate(&comp)
        root.components.set(comp)
    }

    // MARK: - FOV Sync (Bi-Directional)

    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateFromCamera))
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func updateFromCamera() {
        // Only update UI from camera if the user isn't actively dragging the slider
        guard !isDraggingFocalSlider,
              let cam = perspectiveCamera else { return }

        // Get the actual FOV from the camera (could be animating via Timeline)
        let currentFOV = cam.camera.fieldOfViewInDegrees
        let currentMM = fovToFocalLength(currentFOV)

        // Don't fight tiny floating point differences
        if abs(focalSlider.value - currentMM) > 0.5 {
            focalSlider.value = currentMM
            updateFocalLabels(snapToStandardFocalLength(currentMM))
        }
    }

    // MARK: - DoF Blur Effect
    //
    // Simulates depth-of-field using UIVisualEffectView with a radial gradient mask.
    // - OFF: no blur
    // - AF: light vignette blur centred on the tapped focus point
    // - MF: configurable blur — aperture controls intensity, focus distance controls
    //       the clear-area radius (closer distance = smaller clear area = more blur)

    private func updateBlurEffect() {
        let modeIndex = focusSegment.selectedSegmentIndex

        // OFF mode — remove blur entirely
        if modeIndex == 0 {
            blurView?.removeFromSuperview()
            blurView = nil
            return
        }

        // Create blur view if needed
        if blurView == nil {
            let effect = UIBlurEffect(style: .dark)
            let bv = UIVisualEffectView(effect: effect)
            bv.frame = bounds
            bv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            bv.isUserInteractionEnabled = false
            // Insert behind all HUD controls but above the base overlay
            insertSubview(bv, at: 0)
            blurView = bv
        }

        guard let bv = blurView else { return }
        bv.frame = bounds

        // Compute blur opacity and clear-area from mode
        let aperture: Float
        let clearRadius: CGFloat
        let focusCenter: CGPoint

        if modeIndex == 1 {
            // AF mode — light blur, focused on tapped point
            aperture = 4.0
            clearRadius = 0.35
            focusCenter = CGPoint(x: afFocusPoint.x * bounds.width,
                                  y: afFocusPoint.y * bounds.height)
        } else {
            // MF mode — configurable
            aperture = leftSlider.value    // f/1.4 (heavy blur) → f/22 (light blur)
            let dist = rightSlider.value   // 0.5m (tiny clear) → 20m (large clear)
            // Map focus distance to clear radius: close = small clear, far = large clear
            clearRadius = CGFloat(0.1 + (dist / 20.0) * 0.5)
            focusCenter = CGPoint(x: bounds.midX, y: bounds.midY)
        }

        // Map aperture to alpha: f/1.4 → 0.6 (heavy), f/22 → 0.05 (barely visible)
        let maxAperture: Float = 22.0
        let minAperture: Float = 1.4
        let normalised = (aperture - minAperture) / (maxAperture - minAperture)
        let blurAlpha = CGFloat(0.6 - normalised * 0.55)
        bv.alpha = max(0.05, blurAlpha)

        // Apply radial gradient mask — clear in the focus area, opaque at edges
        let maskLayer = CAGradientLayer()
        maskLayer.type = .radial
        maskLayer.frame = bv.bounds

        // Focus center as start point (normalized)
        let startX = focusCenter.x / max(1, bounds.width)
        let startY = focusCenter.y / max(1, bounds.height)
        maskLayer.startPoint = CGPoint(x: startX, y: startY)
        maskLayer.endPoint = CGPoint(x: 1.0, y: 1.0)

        // Clear center → opaque edges
        maskLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.4).cgColor,
            UIColor.black.cgColor
        ]
        maskLayer.locations = [
            0.0,
            NSNumber(value: Float(clearRadius)),
            NSNumber(value: Float(clearRadius + 0.15)),
            1.0
        ]

        bv.layer.mask = maskLayer
    }
}
