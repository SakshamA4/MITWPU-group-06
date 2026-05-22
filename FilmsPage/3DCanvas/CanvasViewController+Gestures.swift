import Combine
import PhotosUI
import RealityKit
import UIKit
import ARKit
import ObjectiveC.runtime

// MARK: - Stored properties for ring gesture (via ObjC associated objects)
private var _ringPanGRKey: UInt8 = 0
private var _ringDragActiveKey: UInt8 = 0

extension CanvasViewController {

    var ringPanGestureRecognizer: UIPanGestureRecognizer? {
        get { objc_getAssociatedObject(self, &_ringPanGRKey) as? UIPanGestureRecognizer }
        set { objc_setAssociatedObject(self, &_ringPanGRKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var ringDragActive: Bool {
        get { (objc_getAssociatedObject(self, &_ringDragActiveKey) as? Bool) ?? false }
        set { objc_setAssociatedObject(self, &_ringDragActiveKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

extension CanvasViewController {
    
    func resolveLightEntity(from entity: Entity) -> Entity? {
        if entity.components[LightConfigComponent.self] != nil { return entity }
        if let childLight = entity.children.first(where: { $0.components[LightConfigComponent.self] != nil }) {
            return childLight
        }
        var parent = entity.parent
        while let p = parent, p.name != "MainAnchor" {
            if p.components[LightConfigComponent.self] != nil { return p }
            parent = p.parent
        }
        return nil
    }

    func presentLightAnimationCard(for lightEntity: Entity) {
        guard let config = lightEntity.components[LightConfigComponent.self] else { return }
        let card = LightAnimationInputCard(
            entityName: lightEntity.name,
            currentIntensity: config.intensity,
            currentKelvin: config.colorTemperatureKelvin
        )
        card.onConfirm = { [weak self] clip in
            guard let self else { return }
            self.saveCurrentStateToUndo()
            self.timeline.addClip(clip)
            if self.baseTransforms[lightEntity.name] == nil {
                self.baseTransforms[lightEntity.name] = lightEntity.transform
            }
            self.debugPrintTimeline()
        }
        present(card, animated: false)
    }

    func setupGestures() {
        // ── 1. Single tap ─────────────────────────────────────────────────────
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.numberOfTapsRequired = 1
        arView.addGestureRecognizer(tap)

        // ── 2. Double tap — focus/frame entity ────────────────────────────────
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        tap.require(toFail: doubleTap)
        arView.addGestureRecognizer(doubleTap)

        // ── 3a. Ring drag — registered first to capture ring touches ──────────
        let ringPan = UIPanGestureRecognizer(target: self, action: #selector(handleRingPan(_:)))
        ringPan.maximumNumberOfTouches = 1
        arView.addGestureRecognizer(ringPan)
        ringPanGestureRecognizer = ringPan

        // ── 3b. 1-finger pan — gizmo drag OR camera pan on empty space ────────
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        pan.delegate = self
        arView.addGestureRecognizer(pan)

        // ── 4. 2-finger pan — camera pitch ────────────────────────────────────
        let twoPan = UIPanGestureRecognizer(target: self, action: #selector(handleTwoFingerPan(_:)))
        twoPan.minimumNumberOfTouches = 2
        twoPan.maximumNumberOfTouches = 2
        arView.addGestureRecognizer(twoPan)

        // ── 5. Pinch — zoom / scale ───────────────────────────────────────────
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        arView.addGestureRecognizer(pinch)

        // ── 6. Twist — camera yaw or entity Y-rotation ────────────────────────
        let rotation = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        arView.addGestureRecognizer(rotation)

        // ── 7. Long press — entity action menu OR path/arc context menu ──────
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.45
        longPress.cancelsTouchesInView = false
        arView.addGestureRecognizer(longPress)

        pinch.delegate    = self
        rotation.delegate = self
        twoPan.delegate   = self
    }

    // ── 2-finger pitch ────────────────────────────────────────────────────────

    @objc func handleTwoFingerPan(_ gesture: UIPanGestureRecognizer) {
        guard !isARModeActive, editorMode == .edit else { return }
        // When looking through a scene camera, 2-finger pan = dolly XY
        guard activeCamera === editorCamera else { return }
        let translation = gesture.translation(in: arView)
        pitch += Float(translation.y) * 0.005
        pitch  = max(0.05, min(1.4, pitch))
        gesture.setTranslation(.zero, in: arView)
        updateEditorCamera()
    }

    // ── Twist — yaw (empty) or entity Y-rotation (selected) ──────────────────

    @objc func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        guard !isARModeActive, editorMode == .edit else { return }
        // When looking through a scene camera, twist = roll (handled by camera-view gestures)
        guard activeCamera === editorCamera else { return }

        // Two-finger twist always rotates the camera (yaw), never the entity.
        // Entity rotation is only via the rotation rings or the outer ring gizmo.
        switch gesture.state {
        case .began:    initialCameraYaw = yaw
        case .changed:
            guard let startYaw = initialCameraYaw else { return }
            yaw = startYaw + Float(gesture.rotation)
            updateEditorCamera()
        case .ended, .cancelled: initialCameraYaw = nil
        default: break
        }
    }

    // ── Single tap ────────────────────────────────────────────────────────────

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: arView)

        if isARModeActive {
            placeSceneOnRealSurface(at: location)
            return
        }

        pathEditToolbar?.removeFromSuperview()
        pathEditToolbar = nil

        // 0️⃣ Rotation arc handle
        let arcHitResults = arView.hitTest(location)
        if let arcHit = arcHitResults.first(where: {
            $0.entity.components[RotationArcComponent.self] != nil
        }), let arcComp = arcHit.entity.components[RotationArcComponent.self] {
            selectedArcClipID  = arcComp.clipID
            setEntityTransparency(selectedEntity, alpha: 1.0)
            selectedEntity     = nil
            activeHandleEntity = nil
            hideRotationGizmo()
            hideGizmo()
            return
        }

        // 1️⃣ Motion path handle
        if let hit = arView.entity(at: location),
           let handle = hit.components[MotionPathHandleComponent.self] {
            selectedPathClipID = handle.clipID
            updatePathSelection()
            setEntityTransparency(selectedEntity, alpha: 1.0)
            selectedEntity     = nil
            hideRotationGizmo()
            activeHandleEntity = hit
            hideGizmo()
            showGizmo(at: hit)
            return
        }

        currentActionMenu?.removeFromSuperview()
        currentActionMenu = nil

        let hits = arView.hitTest(location)
        let objectHit = hits.first { hit in
            var current: Entity? = hit.entity
            while let e = current {
                if e.name == "GizmoRoot" || e.name.contains("Gizmo") { return false }
                if e.name == "MotionPath" || e.name.hasPrefix("PathRoot_")
                    || e.name.hasPrefix("path.") { return false }
                if e.name.hasPrefix("RotationArc_") || e.name == "startLine"
                    || e.name == "endLine" || e.name == "arcCurve"
                    || e.name.hasPrefix("arcHandle.") { return false }
                if e.components[MotionPathHandleComponent.self] != nil
                    || e.components[RotationArcComponent.self]  != nil { return false }
                if e.name == "MainAnchor" { break }
                current = e.parent
            }
            return true
        }

        if let hitResult = objectHit {
            var root: Entity = hitResult.entity
            while let parent = root.parent, parent.name != "MainAnchor" { root = parent }

            // Locked entities: select them (so long-press → action menu works)
            // but hide the gizmo — only the context menu should be reachable.
            let isLocked = root.components[LockComponent.self]?.isLocked ?? false
            if isLocked {
                if let previous = selectedEntity, previous != root {
                    setEntityTransparency(previous, alpha: 1.0)
                }
                selectedEntity     = root
                activeHandleEntity = nil
                setEntityTransparency(root, alpha: 0.9)
                hideGizmo()
                hideRotationGizmo()
                hideAnimationPanel()
                refreshSidebarContent()
                return
            }

            if let previous = selectedEntity, previous != root {
                setEntityTransparency(previous, alpha: 1.0)
            }
            selectedEntity     = root
            activeHandleEntity = nil
            setEntityTransparency(root, alpha: 0.9)
            updateGizmoMode()
            // Menu is now triggered by long press, not tap

            // commented this to stop auto animation playing
//            if let anim = root.availableAnimations.first {
//                root.playAnimation(anim.repeat(count: 1))
//            }
        } else {
            setEntityTransparency(selectedEntity, alpha: 1.0)
            selectedEntity     = nil
            activeHandleEntity = nil
            updateGizmoMode()
            hideGizmo()
            hideRotationGizmo()
            hideAnimationPanel()
            refreshSidebarContent()
        }
    }

    // ── Double tap — focus/frame entity ──────────────────────────────────────

    @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard !isARModeActive, editorMode == .edit else { return }
        let location = gesture.location(in: arView)
        let hits     = arView.hitTest(location)
        let objectHit = hits.first { hit in
            var current: Entity? = hit.entity
            while let e = current {
                if e.name.contains("Gizmo") || e.name == "MotionPath"
                    || e.name.hasPrefix("PathRoot_") || e.name.hasPrefix("path.")
                    || e.name.hasPrefix("RotationArc_") || e.name.hasPrefix("arcHandle.")
                    || e.components[MotionPathHandleComponent.self] != nil
                    || e.components[RotationArcComponent.self] != nil { return false }
                if e.name == "MainAnchor" { break }
                current = e.parent
            }
            return true
        }
        guard let hit = objectHit else { return }
        var root: Entity = hit.entity
        while let parent = root.parent, parent.name != "MainAnchor" { root = parent }
        frameEntityAnimated(root)
    }

    func frameEntityAnimated(_ entity: Entity) {
        guard !isARModeActive else { return }
        let bounds     = modelOnlyBounds(for: entity, relativeTo: nil)
        let targetPos  = (bounds.min + bounds.max) * 0.5
        let maxDim     = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
        let targetDist = max(1.5, min(15.0, maxDim * 3.0))
        framingStartTarget = cameraTarget
        framingEndTarget   = targetPos
        framingStartDist   = distance
        framingEndDist     = targetDist
        framingStartTime   = CACurrentMediaTime()
        framingDuration    = 0.35
        framingDisplayLink?.invalidate()
        let link = CADisplayLink(target: self, selector: #selector(framingTick(_:)))
        link.add(to: .main, forMode: .common)
        framingDisplayLink = link
    }

    @objc func framingTick(_ link: CADisplayLink) {
        let elapsed = CACurrentMediaTime() - framingStartTime
        let raw     = Float(min(elapsed / framingDuration, 1.0))
        let t       = 1 - pow(1 - raw, 3)
        cameraTarget = simd_mix(framingStartTarget, framingEndTarget, SIMD3<Float>(repeating: t))
        distance     = framingStartDist + (framingEndDist - framingStartDist) * t
        updateEditorCamera()
        if raw >= 1.0 { link.invalidate(); framingDisplayLink = nil }
    }

    // ── Action menu ───────────────────────────────────────────────────────────

    func showActionMenu(at point: CGPoint) {
        guard let entity = selectedEntity else { return }
        let isCurrentlyLocked = entity.components[LockComponent.self]?.isLocked ?? false
        let isCamera = entity.name.lowercased().contains("scenecamera")
            || entity.components[CategoryComponent.self]?.toolType == .camera

        // ── Check if entity is a wall or ground (colorable) ──────────────────
        let isWall = entity.components[CanvasViewController.WallComponent.self] != nil
        let isGround = entity.components[CanvasViewController.GroundComponent.self] != nil
        let showColorOption = isWall || isGround

        // ── Check if entity is a light (has LightConfigComponent) ────────────
        let resolvedLightEntity = resolveLightEntity(from: entity)
        let isLight = resolvedLightEntity != nil

        // ── Check if entity is a background (suppress Duplicate) ─────────────
        let isBG = entity.components[CategoryComponent.self]?.toolType == .background

        let menu = EntityActionMenu()
        menu.configure(mode: isCamera ? .camera : .standard, isLocked: isCurrentlyLocked, showColorOption: showColorOption, showLightOption: isLight, isBackground: isBG)
        menu.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(menu)
        NSLayoutConstraint.activate([
            menu.centerXAnchor.constraint(equalTo: view.leadingAnchor, constant: point.x),
            menu.bottomAnchor.constraint(equalTo: view.topAnchor, constant: point.y - 40)
        ])
        menu.onAction = { [weak self] action in
            guard let self else { return }
            switch action {
            case .move:
                guard !(entity.components[LockComponent.self]?.isLocked ?? false) else { return }
                menu.removeFromSuperview()
                self.interactionMode = .move
                self.presentAnimationPrompt(type: .move)
            case .rotate:
                guard !(entity.components[LockComponent.self]?.isLocked ?? false) else { return }
                menu.removeFromSuperview()
                self.interactionMode = .rotate
                self.presentAnimationPrompt(type: .rotate)
            case .addMovement:
                menu.removeFromSuperview()
                self.presentAddMovementPicker(for: entity)

            case .changeColour:
                // Open color picker for wall/ground entities
                menu.removeFromSuperview()
                if let modelEntity = entity as? ModelEntity {
                    self.showColorPicker(for: modelEntity)
                }

            case .editMaterial:
                // Open full material editor for wall/ground entities
                menu.removeFromSuperview()
                if let modelEntity = entity as? ModelEntity {
                    self.presentMaterialEditor(for: modelEntity)
                }

            case .setRatio:
                // Open ratio lock input for wall/ground entities
                menu.removeFromSuperview()
                guard let modelEntity = entity as? ModelEntity else { return }

                let isWall = modelEntity.components[WallComponent.self] != nil
                let secondLabel = isWall ? "Height" : "Depth"
                let currentRatio: CGSize? = isWall
                    ? modelEntity.components[WallComponent.self]?.aspectRatio
                    : modelEntity.components[GroundComponent.self]?.aspectRatio

                let alert = UIAlertController(
                    title: "Set Ratio",
                    message: "Enter Width : \(secondLabel) ratio for pinch resize.\nLeave empty or tap Clear for free resize.",
                    preferredStyle: .alert
                )
                alert.addTextField { tf in
                    tf.placeholder = "Width (e.g. 16)"
                    tf.keyboardType = .decimalPad
                    if let r = currentRatio { tf.text = "\(Int(r.width))" }
                }
                alert.addTextField { tf in
                    tf.placeholder = "\(secondLabel) (e.g. 9)"
                    tf.keyboardType = .decimalPad
                    if let r = currentRatio { tf.text = "\(Int(r.height))" }
                }

                alert.addAction(UIAlertAction(title: "Confirm", style: .default) { _ in
                    let wText = alert.textFields?[0].text ?? ""
                    let hText = alert.textFields?[1].text ?? ""
                    if let rw = Float(wText), let rh = Float(hText), rw > 0, rh > 0 {
                        let ratio = CGSize(width: CGFloat(rw), height: CGFloat(rh))
                        if isWall {
                            var comp = modelEntity.components[WallComponent.self]!
                            comp.aspectRatio = ratio
                            modelEntity.components.set(comp)
                        } else {
                            var comp = modelEntity.components[GroundComponent.self]!
                            comp.aspectRatio = ratio
                            modelEntity.components.set(comp)
                        }
                    }
                })
                alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { _ in
                    if isWall {
                        var comp = modelEntity.components[WallComponent.self]!
                        comp.aspectRatio = nil
                        modelEntity.components.set(comp)
                    } else {
                        var comp = modelEntity.components[GroundComponent.self]!
                        comp.aspectRatio = nil
                        modelEntity.components.set(comp)
                    }
                })
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                self.present(alert, animated: true)

            case .lightSettings:
                // Open light control panel for light entities
                menu.removeFromSuperview()
                if let lightEntity = resolvedLightEntity,
                   var config = lightEntity.components[LightConfigComponent.self] {
                    let panelVC = LightControlPanelViewController(
                        entity: lightEntity,
                        config: config
                    ) { [weak self] updatedConfig in
                        guard let self else { return }
                        // This fires on every slider drag — updates the live 3D scene in real time
                        self.updateLightProperties(for: lightEntity, config: updatedConfig)
                    }

                    if self.view.bounds.width >= 375 {
                        panelVC.modalPresentationStyle = .custom
                        panelVC.transitioningDelegate = self.rightPanelTransitioningDelegate
                    } else {
                        panelVC.modalPresentationStyle = .pageSheet
                        if let sheet = panelVC.sheetPresentationController {
                            sheet.detents = [.medium()]
                            sheet.prefersGrabberVisible = true
                        }
                    }
                    self.present(panelVC, animated: true)
                }

            // ── Camera entity actions ───────────────────────────────────────
            case .addShot:
                menu.removeFromSuperview()
                self.presentShotPicker(for: entity)
            case .aspectRatio:
                menu.removeFromSuperview()
                self.presentAspectRatioPicker(for: entity)
            case .lock:
                let newState = !isCurrentlyLocked
                var lockComp = entity.components[LockComponent.self] ?? LockComponent()
                lockComp.isLocked = newState
                entity.components.set(lockComp)
                menu.removeFromSuperview()
                if newState {
                    // Locked — deselect entirely so entity becomes non-interactive
                    self.setEntityTransparency(entity, alpha: 1.0)
                    self.selectedEntity = nil
                    self.activeHandleEntity = nil
                    self.interactionMode = .move
                    self.hideGizmo()
                    self.hideRotationGizmo()
                    self.hideAnimationPanel()
                    self.updateGizmoMode()
                } else {
                    // Unlocked — keep selected so user can interact immediately
                    self.setEntityTransparency(entity, alpha: 0.9)
                    self.updateGizmoMode()
                }
            case .duplicate:
                menu.removeFromSuperview()
                self.duplicateSelected()
            case .delete:
                self.setEntityTransparency(self.selectedEntity, alpha: 1.0)
                self.deleteSelected()
                self.hideGizmo()
                menu.removeFromSuperview()
            }
        }
        self.currentActionMenu = menu
    }

    // ── Add Movement picker ───────────────────────────────────────────────────

    func presentAddMovementPicker(for entity: Entity) {
        let lightEntity = resolveLightEntity(from: entity)
        let alert = UIAlertController(
            title: lightEntity == nil ? "Add Movement" : "Add Animations",
            message: lightEntity == nil
                ? "Choose the type of animation to add"
                : "Choose movement or light animation",
            preferredStyle: .actionSheet
        )
        if let lightEntity {
            alert.addAction(UIAlertAction(title: "Animate Light", style: .default) { [weak self] _ in
                self?.presentLightAnimationCard(for: lightEntity)
            })
        }
        alert.addAction(UIAlertAction(title: "Move (Position Path)", style: .default) { [weak self] _ in
            self?.interactionMode = .move
            self?.presentAnimationPrompt(type: .move)
        })
        alert.addAction(UIAlertAction(title: "Rotate", style: .default) { [weak self] _ in
            self?.interactionMode = .rotate
            self?.presentAnimationPrompt(type: .rotate)
        })
        if entity.components[CategoryComponent.self]?.toolType == .character,
           entity.components[CharacterPoseComponent.self]?.isStandingPose == true {
            alert.addAction(UIAlertAction(title: "Walk (Path + Animation)", style: .default) { [weak self] _ in
                self?.interactionMode = .move
                self?.animateWalk()
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = alert.popoverPresentationController {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.maxY - 120, width: 1, height: 1)
            pop.permittedArrowDirections = []
        }
        present(alert, animated: true)
    }

    // ── Aspect Ratio picker ──────────────────────────────────────────────────

    func presentAspectRatioPicker(for entity: Entity) {
        // Walk up to the camera root if needed
        var cameraRoot: Entity = entity
        while let parent = cameraRoot.parent, parent.name != "MainAnchor" { cameraRoot = parent }

        // Find the camera and current ratio
        let currentRatio = cameraRoot.components[CameraAspectComponent.self]?.aspectRatio ?? .default
        guard let cameraItem = sceneCameraItems.first(where: { $0.cameraRoot === cameraRoot }) else { return }

        let alert = UIAlertController(
            title: "Aspect Ratio",
            message: "Choose the framing ratio for this camera",
            preferredStyle: .actionSheet
        )

        for ratio in CameraAspectRatio.allCases {
            let prefix = ratio == currentRatio ? "✓ " : ""
            alert.addAction(UIAlertAction(title: "\(prefix)\(ratio.displayName)", style: .default) { [weak self] _ in
                guard let self = self else { return }
                self.applyAspectRatio(ratio, to: cameraItem.camera, cameraRoot: cameraRoot)
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    // ── Body drag (called from handlePan when no gizmo part is hit) ───────────
    // Uses the virtual editor camera for direction, not arView.cameraTransform

    func handleBodyDrag(_ gesture: UIPanGestureRecognizer, entity: Entity) {
        if dragStartPosition == nil {
            dragStartPosition = entity.position
            gesture.setTranslation(.zero, in: arView)
            return
        }
        guard let startPos = dragStartPosition else { return }
        let translation = gesture.translation(in: arView)
        var newPosition = startPos
        // FIX: sensitivity now scales with camera distance, matching panCameraTarget()
        // which uses distance * 0.0015. At distance=5 this gives 0.0015; at distance=15
        // it gives 0.0045 — so dragging feels consistent regardless of zoom level.
        // The old fixed 0.005 was too fast when zoomed in and too slow when zoomed out.
        let sensitivity: Float = max(0.001, distance * 0.0003)
        let dx =  Float(translation.x) * sensitivity
        let dy = -Float(translation.y) * sensitivity

        if currentDragMode == .ground {
            let camPos      = activeCamera.position(relativeTo: nil)
            let scenePos    = entity.position(relativeTo: nil)
            let forward3D   = simd_normalize(scenePos - camPos)
            let flatForward = simd_normalize(SIMD3<Float>(forward3D.x, 0, forward3D.z))
            let flatRight   = simd_normalize(simd_cross(flatForward, SIMD3<Float>(0, 1, 0)))
            newPosition    += (flatRight * dx) + (flatForward * dy)
            newPosition.y   = startPos.y
        } else {
            newPosition.y = startPos.y + (dy * 2.0)
            let skipYClamp: Bool = {
                if let cat = entity.components[CategoryComponent.self] {
                    return cat.toolType == .light || cat.toolType == .camera
                }
                return entity.name.hasPrefix("SceneCamera") || entity.name.contains("Light")
            }()
            if !skipYClamp {
                let bounds = modelOnlyBounds(for: entity, relativeTo: entity)
                newPosition.y = max(-bounds.min.y, newPosition.y)
            }
        }
        let clampedPosition = clampPositionAvoidingOverlap(entity: entity, proposedPosition: newPosition)
        entity.position = clampedPosition
        updateGizmoPosition()
    }

    func calculateWorldDragDelta(_ gesture: UIPanGestureRecognizer) -> SIMD3<Float> {
        let translation = gesture.translation(in: arView)
        gesture.setTranslation(.zero, in: arView)
        let dx = Float(translation.x) * 0.005
        let dz = Float(translation.y) * 0.005
        let camOri = activeCamera.orientation(relativeTo: nil)
        return (camOri.act([1, 0, 0]) * dx) + (camOri.act([0, 0, 1]) * dz)
    }

    @objc func toggleMovementTapped(_ sender: UIButton) {
        if currentDragMode == .ground {
            currentDragMode = .vertical
            sender.setImage(UIImage(systemName: "arrow.up.and.down"), for: .normal)
            sender.tintColor = .yellow
        } else {
            currentDragMode = .ground
            sender.setImage(UIImage(systemName: "arrow.left.and.right"), for: .normal)
            sender.tintColor = .white
        }
    }

    func calculateAxisMovement(entity: Entity, axis: GizmoAxis,
                                mouseDelta: SIMD2<Float>, view: ARView) -> SIMD3<Float> {
        var axisVector: SIMD3<Float> = [0, 0, 0]
        switch axis {
        case .x:    axisVector = [1, 0, 0]
        case .y:    axisVector = [0, 1, 0]
        case .z:    axisVector = [0, 0, 1]
        case .none: return [0, 0, 0]
        }
        let op = entity.position
        guard let sp = view.project(op), let se = view.project(op + axisVector) else { return [0, 0, 0] }
        let screenDir  = simd_normalize(SIMD2<Float>(Float(se.x-sp.x), Float(se.y-sp.y)))
        let projection = simd_dot(mouseDelta, screenDir)
        return axisVector * (projection * 0.002)
    }

    // ── Gesture recogniser delegate ───────────────────────────────────────────
    // Only blocks handlePan when the ring is touched (ringPan owns those touches).
    // All other touches — gizmo arrows, entity body, empty space — always allowed.

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer is UIPanGestureRecognizer else { return true }
        if gestureRecognizer.numberOfTouches >= 2 { return true }
        let location = gestureRecognizer.location(in: arView)
        let hits     = arView.hitTest(location)
        // Block handlePan when ring is touched — ringPan handles it.
        // Walk up parents since ring collider segments are children of Gizmo_Ring_XZ.
        for hit in hits {
            var e: Entity? = hit.entity
            while let entity = e {
                if entity.name == "Gizmo_Ring_XZ" { return false }
                e = entity.parent
            }
        }
        return true
    }

    // ── Ring pan — Y-axis rotation via outer ring ─────────────────────────────

    func ringPanShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
        let location = gesture.location(in: arView)
        return arView.hitTest(location).contains { hit in
            var e: Entity? = hit.entity
            while let entity = e {
                if entity.name == "Gizmo_Ring_XZ" { return true }
                e = entity.parent
            }
            return false
        }
    }

    @objc func handleRingPan(_ gesture: UIPanGestureRecognizer) {
        guard let selected = selectedEntity else { return }
        let isLocked = selected.components[LockComponent.self]?.isLocked ?? false
        guard !isLocked else { return }
        let location = gesture.location(in: arView)

        switch gesture.state {
        case .began:
            let hits = arView.hitTest(location)
            let ringHit = hits.contains { hit in
                var e: Entity? = hit.entity
                while let entity = e {
                    if entity.name == "Gizmo_Ring_XZ" { return true }
                    e = entity.parent
                }
                return false
            }
            guard ringHit else { return }
            saveCurrentStateToUndo()
            ringDragActive  = true
            lastPanLocation = location
            highlightGizmoPart(.rotateY)

        case .changed:
            guard ringDragActive else { return }

            // Circular motion: project the ENTITY centre to screen space,
            // then measure the angle of the touch around that centre.
            // (Using entity centre, not gizmo base, so rotation feels centred.)
            let entityCentre = selected.position(relativeTo: nil)
            if let centre2D = arView.project(entityCentre) {

                let prev = CGPoint(x: lastPanLocation.x  - centre2D.x,
                                   y: lastPanLocation.y  - centre2D.y)
                let curr = CGPoint(x: location.x         - centre2D.x,
                                   y: location.y         - centre2D.y)

                // Only act when fingers are far enough from centre to give a stable angle
                let prevLen = sqrt(prev.x*prev.x + prev.y*prev.y)
                let currLen = sqrt(curr.x*curr.x + curr.y*curr.y)
                guard prevLen > 8, currLen > 8 else {
                    lastPanLocation = location
                    return
                }

                let prevAngle = Float(atan2(prev.y, prev.x))
                let currAngle = Float(atan2(curr.y, curr.x))

                // Wrap delta to (-π, π]
                var delta = currAngle - prevAngle
                if delta >  Float.pi { delta -= 2 * Float.pi }
                if delta < -Float.pi { delta += 2 * Float.pi }

                guard delta.isFinite, abs(delta) > 0.0001 else {
                    lastPanLocation = location
                    return
                }

                // Clockwise screen drag → clockwise Y rotation (negate UIKit angle convention)
                var t = selected.transform
                t.rotation = simd_normalize(simd_quatf(angle: -delta, axis: [0, 1, 0]) * t.rotation)
                selected.transform = t
                updateGizmoPosition()
            }
            lastPanLocation = location

        case .ended, .cancelled:
            ringDragActive = false
            resetGizmoColors()
        default: break
        }
    }

    // ── 3-ring rotation gizmo pan (.rotate mode only) ─────────────────────────
    //
    // Uses CameraRelativeRotationSolver for camera-independent rotation.
    // The rotation axis is FROZEN at drag start and rotation amount is computed
    // from ray-plane intersection — same gesture always produces the same
    // rotation regardless of camera orbit angle.

    @objc func handleRotationPan(_ gesture: UIPanGestureRecognizer) {
        guard interactionMode == .rotate else { return }
        let location = gesture.location(in: arView)
        switch gesture.state {
        case .began:
            let hits = arView.hitTest(location)
            activeRotationAxis = nil
            activeGizmoPart    = .none

            if let hit = hits.first(where: { ["xRing", "yRing", "zRing"].contains($0.entity.name) }) {
                guard let selected = selectedEntity,
                      let gizmo = rotationGizmo else { return }

                // ── Compute frozen world-space axis from the gizmo's matrix ──
                // The RotationRingGizmo is entity-parented, so its world matrix
                // columns are the entity's current local axes in world space.
                let gizmoMatrix = gizmo.transformMatrix(relativeTo: nil)
                let worldAxis: SIMD3<Float>
                let part: GizmoPart

                switch hit.entity.name {
                case "xRing":
                    worldAxis = simd_normalize(SIMD3<Float>(gizmoMatrix.columns.0.x,
                                                             gizmoMatrix.columns.0.y,
                                                             gizmoMatrix.columns.0.z))
                    part = .rotateX
                case "yRing":
                    // yRing face normal is [0,-1,0] in local gizmo space → negate col 1
                    worldAxis = simd_normalize(SIMD3<Float>(-gizmoMatrix.columns.1.x,
                                                             -gizmoMatrix.columns.1.y,
                                                             -gizmoMatrix.columns.1.z))
                    part = .rotateY
                default:
                    worldAxis = simd_normalize(SIMD3<Float>(gizmoMatrix.columns.2.x,
                                                             gizmoMatrix.columns.2.y,
                                                             gizmoMatrix.columns.2.z))
                    part = .rotateZ
                }

                activeRotationAxis = worldAxis
                activeGizmoPart    = part

                // ── Freeze axis in the solver and create interaction plane ──
                let pivot = selected.position(relativeTo: nil)
                let ok = rotationSolver.beginRotation(
                    axis: worldAxis,
                    pivot: pivot,
                    touchPoint: location,
                    arView: arView
                )

                if ok {
                    saveCurrentStateToUndo()
                    highlightGizmoPart(part)
                    lastPanLocation = location
                } else {
                    // Grazing angle fallback — store lastPanLocation for screen-space fallback
                    saveCurrentStateToUndo()
                    highlightGizmoPart(part)
                    lastPanLocation = location
                }
                return
            }

            // ── Non-ring hit: select/deselect entity ──
            if let hit = arView.entity(at: location) {
                var root: Entity? = hit
                while let parent = root?.parent, parent.name != "MainAnchor" { root = parent }
                if root?.name.contains("Gizmo") == false {
                    saveCurrentStateToUndo()
                    setEntityTransparency(selectedEntity, alpha: 1.0)
                    selectedEntity = root
                    setEntityTransparency(root, alpha: 0.9)
                    updateGizmoMode()
                }
            } else {
                setEntityTransparency(selectedEntity, alpha: 1.0)
                selectedEntity = nil
                hideGizmo(); hideRotationGizmo()
            }

        case .changed:
            guard let sel = selectedEntity,
                  activeGizmoPart == .rotateX || activeGizmoPart == .rotateY || activeGizmoPart == .rotateZ
            else { return }

            if rotationSolver.tracking {
                // ── Primary path: camera-relative ray-plane intersection ──
                if let deltaQuat = rotationSolver.updateRotation(touchPoint: location, arView: arView) {
                    let currentWorld = sel.orientation(relativeTo: nil)
                    sel.setOrientation(simd_normalize(deltaQuat * currentWorld), relativeTo: nil)
                }
            } else {
                // ── Fallback: screen-space angular tracking ──
                // Used when the initial projection failed (camera nearly parallel
                // to the rotation plane). This uses the projected entity centre
                // to compute screen-space angles, similar to handleRingPan.
                guard let axis = activeRotationAxis else { return }
                let entityCentre = sel.position(relativeTo: nil)
                guard let centre2D = arView.project(entityCentre) else {
                    lastPanLocation = location; return
                }

                let prev = CGPoint(x: lastPanLocation.x - centre2D.x,
                                   y: lastPanLocation.y - centre2D.y)
                let curr = CGPoint(x: location.x - centre2D.x,
                                   y: location.y - centre2D.y)
                let prevLen = sqrt(prev.x*prev.x + prev.y*prev.y)
                let currLen = sqrt(curr.x*curr.x + curr.y*curr.y)
                guard prevLen > 8, currLen > 8 else {
                    lastPanLocation = location; return
                }
                let prevAngle = Float(atan2(prev.y, prev.x))
                let currAngle = Float(atan2(curr.y, curr.x))
                var delta = currAngle - prevAngle
                if delta >  Float.pi { delta -= 2 * Float.pi }
                if delta < -Float.pi { delta += 2 * Float.pi }
                guard delta.isFinite, abs(delta) > 0.001 else {
                    lastPanLocation = location; return
                }
                let deltaQuat = simd_quatf(angle: -delta, axis: axis)
                let currentWorld = sel.orientation(relativeTo: nil)
                sel.setOrientation(simd_normalize(deltaQuat * currentWorld), relativeTo: nil)
            }
            lastPanLocation = location

        case .ended, .cancelled:
            rotationSolver.endRotation()
            activeRotationAxis = nil
            resetGizmoColors()
        default: break
        }
    }
}
