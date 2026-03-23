//
//  CanvasViewController+AR.swift
//  3DCanvas
//
//  ARCHITECTURE (Single-ARView, background-toggle):
//  ─────────────────────────────────────────────────
//  arView is .ar from launch with idle session + .color(.white) background.
//
//  AR mode:  .cameraFeed() background, full plane detection,
//            person occlusion, light estimation, viewfinder overlay,
//            dolly recording.
//
//  Editor:   .color(.white) background, idle session, grid visible.
//
//  FILMMAKER FEATURES:
//  1. Person/scene occlusion (depth-aware)
//  2. Real-world light estimation
//  3. AR viewfinder with lens emulation (24mm/35mm/50mm/85mm)
//  4. Physical dolly — record iPad transform, save to timeline
//  5. 1:1 scale enforcement (handled in CanvasViewController.swift spawnEntity)
//

import Combine
import PhotosUI
import RealityKit
import UIKit
import ARKit
import AVFoundation

// MARK: - Dolly recording data
struct DollyFrame {
    let timestamp: TimeInterval
    let transform: simd_float4x4
}

extension CanvasViewController {

    // MARK: - Toggle

    func toggleARMode(isOn: Bool) {
        if isOn {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    DispatchQueue.main.async {
                        if granted { self?.activateAR() }
                        else { self?.isARModeActive = false; self?.showCameraDeniedAlert() }
                    }
                }
            case .authorized:
                activateAR()
            default:
                isARModeActive = false
                showCameraDeniedAlert()
            }
        } else {
            deactivateAR()
        }
    }

    // MARK: - Activate AR

    func activateAR() {
        isARModeActive = true

        // Dismiss editor UI
        hideGizmo()
        hideRotationGizmo()
        currentActionMenu?.removeFromSuperview()
        currentActionMenu = nil
        setEntityTransparency(selectedEntity, alpha: 1.0)
        selectedEntity = nil
        stopCameraPreviewUpdates()

        // Switch background: white → camera feed
        arView.environment.background = .cameraFeed()

        // Hide editor grid in AR
        if let grid = mainAnchor?.findEntity(named: "Grid") {
            grid.isEnabled = false
        }

        // Hide editor-only buttons that conflict with AR UI
        hideEditorButtons()

        // Hide camera panel in AR mode
        if let cameraPanel = view.viewWithTag(8800) {
            cameraPanel.isHidden = true
        }
        view.viewWithTag(8803)?.isHidden = true  // pull-tab

        // Start AR session with all filmmaker features
        let config = buildARConfig()
        arView.session.delegate = self

        // Double-dispatch: Metal CALayer must commit to compositor before session starts
        DispatchQueue.main.async { [weak self] in
            DispatchQueue.main.async {
                guard let self = self, self.isARModeActive else { return }
                self.arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
            }
        }

        addCoachingOverlay(to: arView)
        showARHintLabel("Point at a flat surface, then tap to place your scene")
        showViewfinderUI()
        showDollyRecordButton()

        arModeButton?.tintColor       = .white
        arModeButton?.backgroundColor = UIColor(red: 0, green: 100/255, blue: 220/255, alpha: 1)
    }

    /// Hides editor-only buttons that would conflict with AR UI
    private func hideEditorButtons() {
        // Rotate button (bottom-left)
        for sub in view.subviews where sub is UIButton {
            if let btn = sub as? UIButton,
               btn.currentImage?.isSymbolImage == true,
               btn !== arModeButton {
                // Tag editor buttons so we can find them later
                if btn.frame.minX < 100 && btn.frame.maxY > view.bounds.height - 100 {
                    btn.tag = 7800  // mark as hidden editor button
                    btn.isHidden = true
                }
            }
        }
        // Movement toggle button
        movementToggleButton.isHidden = true
    }

    /// Restores editor buttons hidden during AR mode
    private func showEditorButtons() {
        for sub in view.subviews where sub.tag == 7800 {
            sub.isHidden = false
            sub.tag = 0  // clear marker
        }
        movementToggleButton.isHidden = false
    }

    // MARK: - Deactivate AR

    func deactivateAR() {
        isARModeActive = false

        // Switch background: camera feed → white
        arView.environment.background = .color(.white)

        // Reconfigure to idle session (keeps Metal rendering for white background)
        let idleConfig = ARWorldTrackingConfiguration()
        idleConfig.planeDetection = []
        idleConfig.isLightEstimationEnabled = false
        arView.session.run(idleConfig)
        arView.session.delegate = nil

        // Re-enable editor grid
        if let grid = mainAnchor?.findEntity(named: "Grid") {
            grid.isEnabled = true
        }

        // Restore editor buttons
        showEditorButtons()

        // Restore camera panel
        if let cameraPanel = view.viewWithTag(8800) {
            cameraPanel.isHidden = false
        }
        view.viewWithTag(8803)?.isHidden = false  // pull-tab

        // Stop dolly recording if active
        stopDollyRecording()

        removeCoachingOverlay()
        removeARHintLabel()
        removePlaneIndicator()
        removeViewfinderUI()
        removeDollyRecordButton()

        arModeButton?.tintColor       = .systemGreen
        arModeButton?.backgroundColor = UIColor(red: 11/255, green: 11/255, blue: 22/255, alpha: 1)
    }

    // MARK: - AR Config (with Filmmaker Features)

    func buildARConfig() -> ARWorldTrackingConfiguration {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection           = [.horizontal, .vertical]
        config.isLightEstimationEnabled = true

        // ── Feature 1: Scene Reconstruction + Occlusion ──
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .meshWithClassification
            arView.environment.sceneUnderstanding.options = [.occlusion, .physics, .collision, .receivesLighting]
        } else {
            arView.environment.sceneUnderstanding.options = []
        }

        // ── Feature 1b: Person Occlusion ──
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            config.frameSemantics.insert(.personSegmentationWithDepth)
        } else if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentation) {
            config.frameSemantics.insert(.personSegmentation)
        }

        // ── Feature 1c: Scene Depth for better occlusion ──
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }

        return config
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Feature 2: Real-World Light Estimation
    // ═══════════════════════════════════════════════════════════════════════

    /// Called every frame from ARSessionDelegate.session(_:didUpdate:) for ARFrame
    func applyLightEstimation(from frame: ARFrame) {
        guard isARModeActive, let estimate = frame.lightEstimate else { return }
        // ambientIntensity is in lumens (typical: ~250 dark, ~1000 normal, ~2000+ bright)
        // Map to RealityKit environment intensity exponent: log2(intensity / 1000)
        let intensity = Float(estimate.ambientIntensity)
        let exponent = log2(max(intensity, 1.0) / 1000.0)
        arView.environment.lighting.intensityExponent = exponent
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Feature 3: AR Viewfinder — Lens & Sensor Emulation
    // ═══════════════════════════════════════════════════════════════════════

    /// iPad wide camera ≈ 29mm equivalent (full-frame 35mm sensor).
    /// Letterbox ratio = iPadFOV / lensFOV. We crop from edges to simulate narrower FOV.
    private static let ipadEquivalentMM: Float = 29.0

    /// Horizontal FOV in degrees for each focal length on a Super-35mm cinema sensor.
    private static let lensFOV: [String: Float] = [
        "iPad":  73.0,  // native, no crop
        "24mm":  73.7,
        "35mm":  54.4,
        "50mm":  39.6,
        "85mm":  23.9,
    ]

    func showViewfinderUI() {
        removeViewfinderUI()

        // Lens selector — positioned at bottom-center, clear of other buttons
        let lensItems = ["24mm", "35mm", "50mm", "85mm"]
        let seg = UISegmentedControl(items: lensItems)
        seg.tag = 9200
        seg.selectedSegmentIndex = -1  // no selection = iPad native (no crop)
        seg.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        seg.selectedSegmentTintColor = UIColor(red: 0, green: 100/255, blue: 220/255, alpha: 1)
        seg.setTitleTextAttributes([.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 13, weight: .bold)], for: .normal)
        seg.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        seg.layer.cornerRadius = 8
        seg.clipsToBounds = true
        seg.translatesAutoresizingMaskIntoConstraints = false
        seg.addAction(UIAction { [weak self] action in
            guard let seg = action.sender as? UISegmentedControl else { return }
            if seg.selectedSegmentIndex >= 0 {
                let label = lensItems[seg.selectedSegmentIndex]
                self?.applyViewfinderCrop(lens: label)
            }
        }, for: .valueChanged)

        view.addSubview(seg)
        NSLayoutConstraint.activate([
            seg.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            seg.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            seg.heightAnchor.constraint(equalToConstant: 36),
            seg.widthAnchor.constraint(equalToConstant: 260),
        ])

        // Letterbox overlay (starts clear — no crop)
        let letterbox = UIView()
        letterbox.tag = 9201
        letterbox.isUserInteractionEnabled = false
        letterbox.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(letterbox, belowSubview: seg)
        NSLayoutConstraint.activate([
            letterbox.topAnchor.constraint(equalTo: view.topAnchor),
            letterbox.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            letterbox.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            letterbox.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    func applyViewfinderCrop(lens: String) {
        guard let container = view.viewWithTag(9201) else { return }

        // Remove previous border views
        container.subviews.forEach { $0.removeFromSuperview() }

        let nativeFOV = Self.lensFOV["iPad"]!
        let targetFOV = Self.lensFOV[lens] ?? nativeFOV

        if targetFOV >= nativeFOV { return }

        // Calculate crop ratio
        let cropRatio = 1.0 - (targetFOV / nativeFOV)
        let screenW = view.bounds.width
        let screenH = view.bounds.height
        let sideW   = screenW * CGFloat(cropRatio / 2.0)
        let topH    = screenH * CGFloat(cropRatio / 2.0)

        // Black bars (letterbox)
        let leftBar = UIView(frame: CGRect(x: 0, y: 0, width: sideW, height: screenH))
        leftBar.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        container.addSubview(leftBar)

        let rightBar = UIView(frame: CGRect(x: screenW - sideW, y: 0, width: sideW, height: screenH))
        rightBar.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        container.addSubview(rightBar)

        let topBar = UIView(frame: CGRect(x: sideW, y: 0, width: screenW - 2*sideW, height: topH))
        topBar.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        container.addSubview(topBar)

        let bottomBar = UIView(frame: CGRect(x: sideW, y: screenH - topH, width: screenW - 2*sideW, height: topH))
        bottomBar.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        container.addSubview(bottomBar)

        // Cinema corner markers
        let ml: CGFloat = 24
        let mc = UIColor.white.withAlphaComponent(0.7)
        let corners: [(CGFloat, CGFloat, Bool, Bool)] = [
            (sideW, topH, true, true),
            (screenW - sideW, topH, false, true),
            (sideW, screenH - topH, true, false),
            (screenW - sideW, screenH - topH, false, false),
        ]
        for (cx, cy, isLeft, isTop) in corners {
            let h = UIView(frame: CGRect(x: isLeft ? cx : cx - ml, y: cy - 0.5, width: ml, height: 1))
            h.backgroundColor = mc; container.addSubview(h)
            let v = UIView(frame: CGRect(x: cx - 0.5, y: isTop ? cy : cy - ml, width: 1, height: ml))
            v.backgroundColor = mc; container.addSubview(v)
        }

        // Center cross
        let cx = screenW / 2, cy = screenH / 2
        let ch = UIView(frame: CGRect(x: cx - 12, y: cy - 0.5, width: 24, height: 1))
        ch.backgroundColor = mc; container.addSubview(ch)
        let cv = UIView(frame: CGRect(x: cx - 0.5, y: cy - 12, width: 1, height: 24))
        cv.backgroundColor = mc; container.addSubview(cv)

        // Lens label in top-left of visible area
        let lensLabel = UILabel()
        lensLabel.text = " \(lens) "
        lensLabel.font = .monospacedSystemFont(ofSize: 12, weight: .bold)
        lensLabel.textColor = mc
        lensLabel.frame = CGRect(x: sideW + 8, y: topH + 8, width: 60, height: 20)
        container.addSubview(lensLabel)
    }

    func removeViewfinderUI() {
        view.viewWithTag(9200)?.removeFromSuperview()  // segment control
        view.viewWithTag(9201)?.removeFromSuperview()  // letterbox container
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Feature 4: Physical Dolly — Camera Path Capture
    // ═══════════════════════════════════════════════════════════════════════

    // Associated object keys for dolly recording
    private static var dollyFramesKey:    UInt8 = 0
    private static var dollyRecordingKey: UInt8 = 0

    var dollyFrames: [DollyFrame] {
        get { objc_getAssociatedObject(self, &Self.dollyFramesKey) as? [DollyFrame] ?? [] }
        set { objc_setAssociatedObject(self, &Self.dollyFramesKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var isDollyRecording: Bool {
        get { objc_getAssociatedObject(self, &Self.dollyRecordingKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &Self.dollyRecordingKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    func showDollyRecordButton() {
        removeDollyRecordButton()

        let btn = UIButton(type: .system)
        btn.tag = 9300
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)
        btn.setImage(UIImage(systemName: "record.circle", withConfiguration: config), for: .normal)
        btn.tintColor = .white
        btn.backgroundColor = UIColor(red: 0.85, green: 0.1, blue: 0.1, alpha: 0.9)
        btn.layer.cornerRadius = 22
        btn.clipsToBounds = true
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addAction(UIAction { [weak self] _ in
            self?.toggleDollyRecording()
        }, for: .touchUpInside)

        view.addSubview(btn)
        NSLayoutConstraint.activate([
            btn.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            btn.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            btn.widthAnchor.constraint(equalToConstant: 44),
            btn.heightAnchor.constraint(equalToConstant: 44),
        ])

        // "REC" label below button
        let label = UILabel()
        label.tag = 9301
        label.text = "REC"
        label.font = .systemFont(ofSize: 9, weight: .heavy)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: btn.centerXAnchor),
            label.topAnchor.constraint(equalTo: btn.bottomAnchor, constant: 3),
        ])
    }

    func removeDollyRecordButton() {
        view.viewWithTag(9300)?.removeFromSuperview()
        view.viewWithTag(9301)?.removeFromSuperview()
        view.viewWithTag(9302)?.removeFromSuperview()  // timer label
    }

    func toggleDollyRecording() {
        if isDollyRecording {
            stopDollyRecording()
        } else {
            startDollyRecording()
        }
    }

    func startDollyRecording() {
        isDollyRecording = true
        dollyFrames = []

        // Update button appearance
        if let btn = view.viewWithTag(9300) as? UIButton {
            let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .bold)
            btn.setImage(UIImage(systemName: "stop.circle.fill", withConfiguration: config), for: .normal)
            btn.backgroundColor = UIColor.red

            // Pulsing animation
            UIView.animate(withDuration: 0.5, delay: 0, options: [.repeat, .autoreverse]) {
                btn.alpha = 0.5
            }
        }

        // Timer label — next to the button
        let timerLabel = UILabel()
        timerLabel.tag = 9302
        timerLabel.text = " ● REC 0.0s "
        timerLabel.font = .monospacedSystemFont(ofSize: 13, weight: .bold)
        timerLabel.textColor = .red
        timerLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        timerLabel.textAlignment = .center
        timerLabel.layer.cornerRadius = 8
        timerLabel.clipsToBounds = true
        timerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(timerLabel)
        NSLayoutConstraint.activate([
            timerLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 64),
            timerLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            timerLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
            timerLabel.heightAnchor.constraint(equalToConstant: 28),
        ])

        showARHintLabel("Walk to record a camera path. Tap STOP when done.")
    }

    func stopDollyRecording() {
        guard isDollyRecording else { return }
        isDollyRecording = false

        // Reset button
        if let btn = view.viewWithTag(9300) as? UIButton {
            btn.layer.removeAllAnimations()
            btn.alpha = 1.0
            let config = UIImage.SymbolConfiguration(pointSize: 22, weight: .bold)
            btn.setImage(UIImage(systemName: "record.circle", withConfiguration: config), for: .normal)
            btn.backgroundColor = UIColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 0.9)
        }

        // Remove timer label
        view.viewWithTag(9302)?.removeFromSuperview()

        let frames = dollyFrames
        guard frames.count >= 2 else {
            showARHintLabel("Too short — walk more to capture a camera path")
            return
        }

        // Convert dolly frames to a motion path and add to timeline
        saveDollyPath(frames)
    }

    /// Called from ARSessionDelegate on every frame while recording
    func recordDollyFrame(from frame: ARFrame) {
        guard isDollyRecording else { return }
        let df = DollyFrame(timestamp: frame.timestamp, transform: frame.camera.transform)
        dollyFrames.append(df)

        // Update timer label
        if let first = dollyFrames.first,
           let timerLabel = view.viewWithTag(9302) as? UILabel {
            let elapsed = frame.timestamp - first.timestamp
            timerLabel.text = String(format: " ● REC %.1fs ", elapsed)
        }
    }

    /// Converts recorded dolly frames into an AnimationClip with BezierMotionPath
    private func saveDollyPath(_ frames: [DollyFrame]) {
        guard frames.count >= 2 else { return }

        let startTime: Float = 0
        let duration = Float(frames.last!.timestamp - frames.first!.timestamp)
        guard duration > 0.1 else { return }

        // Extract positions from transforms
        let positions = frames.map { f -> SIMD3<Float> in
            let col = f.transform.columns.3
            return SIMD3<Float>(col.x, col.y, col.z)
        }

        let startPos = positions.first!
        let endPos   = positions.last!

        // Find control points at 1/3 and 2/3 along the path
        let idx1 = positions.count / 3
        let idx2 = (positions.count * 2) / 3
        let control1 = positions[idx1]
        let control2 = positions[idx2]

        let motionPath = BezierMotionPath(
            start:    startPos,
            control1: control1,
            control2: control2,
            end:      endPos
        )

        let clip = AnimationClip(
            entityName: "EditorCamera",
            type: .move,
            track: .position,
            easing: .linear,
            startTime: startTime,
            duration: duration,
            fromValue: startPos,
            toValue: endPos,
            motionPath: motionPath
        )

        timeline.addClip(clip)

        let frameCount = frames.count
        showARHintLabel("✓ Dolly path saved! \(frameCount) frames, \(String(format: "%.1f", duration))s")
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Surface Placement
    // ═══════════════════════════════════════════════════════════════════════

    func placeSceneOnRealSurface(at screenPoint: CGPoint) {
        guard isARModeActive else { return }
        let mesh  = arView.raycast(from: screenPoint, allowing: .existingPlaneGeometry, alignment: .any)
        let plane = arView.raycast(from: screenPoint, allowing: .estimatedPlane, alignment: .horizontal)
        guard let result = mesh.first ?? plane.first else { return }
        if let anchor = mainAnchor {
            anchor.transform = Transform(matrix: result.worldTransform)
        }
        removeARHintLabel()
        removePlaneIndicator()
        arWorldMapNeedsSave = true
    }

    // MARK: - Coaching Overlay

    private func addCoachingOverlay(to arv: ARView) {
        removeCoachingOverlay()
        let ov = ARCoachingOverlayView()
        ov.session = arv.session
        ov.goal    = .horizontalPlane
        ov.activatesAutomatically = true
        ov.translatesAutoresizingMaskIntoConstraints = false
        ov.tag = 9100
        view.addSubview(ov)
        NSLayoutConstraint.activate([
            ov.topAnchor.constraint(equalTo: view.topAnchor),
            ov.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            ov.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ov.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
    private func removeCoachingOverlay() { view.viewWithTag(9100)?.removeFromSuperview() }

    // MARK: - Plane Indicator

    func showPlaneIndicator(at worldPos: SIMD3<Float>) {
        guard isARModeActive else { return }
        let name = "ARPlaneIndicator"
        if let e = arView.scene.findEntity(named: name) { e.position = worldPos; e.isEnabled = true; return }
        let indicator = ModelEntity(
            mesh: MeshResource.generatePlane(width: 0.4, depth: 0.4, cornerRadius: 0.2),
            materials: [UnlitMaterial(color: UIColor.systemBlue.withAlphaComponent(0.55))])
        indicator.name = name
        let anchor = AnchorEntity(world: worldPos)
        anchor.addChild(indicator)
        arView.scene.addAnchor(anchor)
        var scale: Float = 1.0; var growing = true
        Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { [weak indicator, weak self] t in
            guard let e = indicator, e.parent != nil, self?.isARModeActive == true else { t.invalidate(); return }
            scale = growing ? min(scale+0.02,1.3) : max(scale-0.02,0.85)
            growing = scale>=1.3 ? false : scale<=0.85 ? true : growing
            e.scale = SIMD3(repeating: scale)
        }
    }

    func removePlaneIndicator() {
        arView.scene.anchors
            .first(where: { $0.findEntity(named: "ARPlaneIndicator") != nil })?
            .removeFromParent()
    }

    // MARK: - Hint Label

    private func showARHintLabel(_ text: String) {
        removeARHintLabel()
        let l = UILabel()
        l.tag = 9101; l.text = "  \(text)  "; l.textColor = .white
        l.font = .systemFont(ofSize: 14, weight: .medium)
        l.textAlignment = .center
        l.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        l.layer.cornerRadius = 12; l.clipsToBounds = true
        l.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(l)
        NSLayoutConstraint.activate([
            l.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            l.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100),
            l.heightAnchor.constraint(equalToConstant: 40),
        ])
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak l] in
            UIView.animate(withDuration: 0.4) { l?.alpha = 0 } completion: { _ in l?.removeFromSuperview() }
        }
    }
    func removeARHintLabel() { view.viewWithTag(9101)?.removeFromSuperview() }

    // MARK: - Camera Permission

    private func showCameraDeniedAlert() {
        let a = UIAlertController(title: "Camera Access Required",
            message: "AR mode needs camera access. Enable it in Settings → Privacy → Camera.",
            preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
        })
        a.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(a, animated: true)
    }

    // MARK: - AR World Map Persistence

    var arWorldMapNeedsSave: Bool {
        get { objc_getAssociatedObject(self, &_arWorldMapNeedsSaveKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &_arWorldMapNeedsSaveKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    private var arWorldMapURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ar_world_\(currentSceneID?.uuidString ?? "default").arwm")
    }
    func saveARWorldMap(completion: ((Bool) -> Void)? = nil) {
        guard isARModeActive else { completion?(false); return }
        arView.session.getCurrentWorldMap { [weak self] map, _ in
            guard let self = self, let map = map else { DispatchQueue.main.async { completion?(false) }; return }
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                try data.write(to: self.arWorldMapURL, options: .atomic)
                DispatchQueue.main.async { self.arWorldMapNeedsSave = false; completion?(true) }
            } catch { DispatchQueue.main.async { completion?(false) } }
        }
    }
    func loadARWorldMapIfAvailable() {
        guard FileManager.default.fileExists(atPath: arWorldMapURL.path) else { return }
        guard let data = try? Data(contentsOf: arWorldMapURL),
              let map  = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else { return }
        let config = buildARConfig()
        config.initialWorldMap = map
        arView.session.run(config, options: [])
    }
    func hasSavedARWorldMap() -> Bool { FileManager.default.fileExists(atPath: arWorldMapURL.path) }
    func deleteARWorldMap() { try? FileManager.default.removeItem(at: arWorldMapURL) }
}

// Associated-object key (file-level)
private var _arWorldMapNeedsSaveKey: UInt8 = 0

// MARK: - ARSessionDelegate

extension CanvasViewController: ARSessionDelegate {

    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard isARModeActive else { return }

        // Feature 2: Real-world light estimation
        applyLightEstimation(from: frame)

        // Feature 4: Dolly recording — capture iPad transform every frame
        recordDollyFrame(from: frame)
    }

    public func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        guard isARModeActive else { return }
        for anchor in anchors {
            guard let plane = anchor as? ARPlaneAnchor, plane.alignment == .horizontal else { continue }
            let c = plane.transform.columns.3
            let worldPos = SIMD3<Float>(c.x + plane.center.x, c.y, c.z + plane.center.z)
            DispatchQueue.main.async { self.showPlaneIndicator(at: worldPos) }
        }
    }
    public func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        guard isARModeActive else { return }
        guard let plane = anchors.compactMap({ $0 as? ARPlaneAnchor }).first(where: { $0.alignment == .horizontal }) else { return }
        let c = plane.transform.columns.3
        let worldPos = SIMD3<Float>(c.x + plane.center.x, c.y, c.z + plane.center.z)
        DispatchQueue.main.async { self.showPlaneIndicator(at: worldPos) }
    }
    public func session(_ session: ARSession, didFailWithError error: Error) {
        guard isARModeActive else { return }
        DispatchQueue.main.async { [weak self] in
            self?.deactivateAR()
            if (error as NSError).code == 103 { self?.showCameraDeniedAlert() }
        }
    }
    public func sessionWasInterrupted(_ session: ARSession) { guard isARModeActive else { return }; removePlaneIndicator() }
    public func sessionInterruptionEnded(_ session: ARSession) {
        guard isARModeActive else { return }
        arView.session.run(buildARConfig(), options: [.resetTracking])
    }
}
