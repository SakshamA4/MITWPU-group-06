import Combine
import PhotosUI
import RealityKit
import UIKit
import ARKit
import ObjectiveC.runtime

// MARK: - Stored properties for ring gesture (via ObjC associated objects)
// Swift extensions cannot store properties directly; associated objects are
// the standard pattern for adding stored state in an extension.
private var _ringPanGRKey:     UInt8 = 0
private var _ringDragActiveKey: UInt8 = 0

extension CanvasViewController {

    /// The dedicated UIPanGestureRecognizer for the outer ring.
    /// Stored here so gestureRecognizerShouldBegin can identify it by ===.
    var ringPanGestureRecognizer: UIPanGestureRecognizer? {
        get { objc_getAssociatedObject(self, &_ringPanGRKey) as? UIPanGestureRecognizer }
        set { objc_setAssociatedObject(self, &_ringPanGRKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// True while a ring-drag gesture is in progress.
    var ringDragActive: Bool {
        get { (objc_getAssociatedObject(self, &_ringDragActiveKey) as? Bool) ?? false }
        set { objc_setAssociatedObject(self, &_ringDragActiveKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}

extension CanvasViewController {

    func setupGestures() {
        // ── 1. Single tap — select entity / path handle ───────────────────────
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.numberOfTapsRequired = 1
        arView.addGestureRecognizer(tap)

        // ── 2. Double tap — focus/frame the tapped entity ─────────────────────
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        tap.require(toFail: doubleTap)
        arView.addGestureRecognizer(doubleTap)

        // ── 3. 1-finger pan — object/gizmo drag OR camera pan on empty space ──
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        pan.delegate = self
        arView.addGestureRecognizer(pan)

        // ── 4. 2-finger pan — camera pitch (vertical orbit) ───────────────────
        let twoPan = UIPanGestureRecognizer(target: self, action: #selector(handleTwoFingerPan(_:)))
        twoPan.minimumNumberOfTouches = 2
        twoPan.maximumNumberOfTouches = 2
        arView.addGestureRecognizer(twoPan)

        // ── 5. Pinch — zoom in/out (or scale entity if selected) ─────────────
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        arView.addGestureRecognizer(pinch)

        // ── 6. Twist — camera yaw (nothing selected) or entity Y-rotation ─────
        let rotation = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        arView.addGestureRecognizer(rotation)

        // ── 7. Long press — path/arc context menu ────────────────────────────
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handlePathLongPress(_:)))
        longPress.minimumPressDuration = 0.45
        longPress.cancelsTouchesInView = false
        arView.addGestureRecognizer(longPress)

        pinch.delegate    = self
        rotation.delegate = self
        twoPan.delegate   = self
    }

    // ── 2-finger vertical drag → camera pitch ────────────────────────────────

    @objc func handleTwoFingerPan(_ gesture: UIPanGestureRecognizer) {
        guard !isARModeActive, editorMode == .edit else { return }
        let translation = gesture.translation(in: arView)
        pitch += Float(translation.y) * 0.005
        pitch  = max(-1.4, min(1.4, pitch))
        gesture.setTranslation(.zero, in: arView)
        updateEditorCamera()
    }

    // ── Twist — camera yaw (nothing selected) or entity Y-rotation ───────────

    @objc func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        guard !isARModeActive, editorMode == .edit else { return }

        if let entity = selectedEntity {
            let isLocked = entity.components[LockComponent.self]?.isLocked ?? false
            if isLocked { return }
            switch gesture.state {
            case .began:
                saveCurrentStateToUndo()
                initialRotation = entity.orientation
            case .changed:
                if let start = initialRotation {
                    let q = simd_quatf(angle: -Float(gesture.rotation), axis: [0, 1, 0])
                    entity.orientation = simd_normalize(q * start)
                    cameraCollectionView?.reloadData()
                }
            case .ended, .cancelled:
                initialRotation = nil
            default: break
            }
            return
        }

        switch gesture.state {
        case .began:
            initialCameraYaw = yaw
        case .changed:
            guard let startYaw = initialCameraYaw else { return }
            yaw = startYaw + Float(gesture.rotation)
            updateEditorCamera()
        case .ended, .cancelled:
            initialCameraYaw = nil
        default: break
        }
    }

    // ── Single tap — select entity / handle ──────────────────────────────────

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
           let handle = hit.components[MotionPathHandleComponent.self]
        {
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
                if e.name == "GizmoRoot" || e.name.contains("Gizmo")    { return false }
                if e.name == "MotionPath" || e.name.hasPrefix("PathRoot_")
                    || e.name.hasPrefix("path.")                         { return false }
                if e.name.hasPrefix("RotationArc_") || e.name == "startLine"
                    || e.name == "endLine" || e.name == "arcCurve"
                    || e.name.hasPrefix("arcHandle.")                    { return false }
                if e.components[MotionPathHandleComponent.self] != nil
                    || e.components[RotationArcComponent.self]  != nil   { return false }
                if e.name == "MainAnchor" { break }
                current = e.parent
            }
            return true
        }

        if let hitResult = objectHit {
            var root: Entity = hitResult.entity
            while let parent = root.parent, parent.name != "MainAnchor" { root = parent }

            if let previous = selectedEntity, previous != root {
                setEntityTransparency(previous, alpha: 1.0)
            }
            selectedEntity     = root
            activeHandleEntity = nil
            setEntityTransparency(root, alpha: 0.7)
            updateGizmoMode()
            showActionMenu(at: location)
            if let anim = root.availableAnimations.first {
                root.playAnimation(anim.repeat(count: 1))
            }
        } else {
            setEntityTransparency(selectedEntity, alpha: 1.0)
            selectedEntity     = nil
            activeHandleEntity = nil
            updateGizmoMode()
            hideGizmo()
            hideRotationGizmo()
            hideAnimationPanel()
        }
    }

    // ── Double tap — smoothly focus/frame the tapped entity ──────────────────

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

    /// Smoothly animates the camera to frame `entity` over 0.35 s.
    func frameEntityAnimated(_ entity: Entity) {
        guard !isARModeActive else { return }

        let bounds     = entity.visualBounds(relativeTo: nil)
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
        let t       = 1 - pow(1 - raw, 3)   // ease-out cubic

        cameraTarget = simd_mix(framingStartTarget, framingEndTarget,
                                SIMD3<Float>(repeating: t))
        distance     = framingStartDist + (framingEndDist - framingStartDist) * t
        updateEditorCamera()

        if raw >= 1.0 {
            link.invalidate()
            framingDisplayLink = nil
        }
    }

    // ── Action menu ───────────────────────────────────────────────────────────

    func showActionMenu(at point: CGPoint) {
        guard let entity = selectedEntity else { return }

        let isCurrentlyLocked = entity.components[LockComponent.self]?.isLocked ?? false
        let isCamera = entity.name.lowercased().contains("scenecamera")
            || entity.components[CategoryComponent.self]?.toolType == .camera

        let menu = EntityActionMenu()
        menu.configure(mode: isCamera ? .camera : .standard, isLocked: isCurrentlyLocked)
        menu.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(menu)

        NSLayoutConstraint.activate([
            menu.centerXAnchor.constraint(equalTo: view.leadingAnchor, constant: point.x),
            menu.bottomAnchor.constraint(equalTo: view.topAnchor,      constant: point.y - 40),
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
            case .addShot:
                menu.removeFromSuperview()
                self.presentShotPicker(for: entity)
            case .lock:
                let newState = !isCurrentlyLocked
                var lockComp = entity.components[LockComponent.self] ?? LockComponent()
                lockComp.isLocked = newState
                entity.components.set(lockComp)
                if newState {
                    self.interactionMode = .move
                    self.setEntityTransparency(entity, alpha: 1.0)
                    self.hideGizmo()
                    self.hideRotationGizmo()
                } else {
                    // No transparency on unlock — gizmo renders on top via UnlitMaterial
                    self.updateGizmoMode()
                }
                menu.removeFromSuperview()
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
        let alert = UIAlertController(title: "Add Movement",
                                      message: "Choose the type of animation to add",
                                      preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Move (Position Path)", style: .default) { [weak self] _ in
            self?.interactionMode = .move
            self?.presentAnimationPrompt(type: .move)
        })
        alert.addAction(UIAlertAction(title: "Rotate", style: .default) { [weak self] _ in
            self?.interactionMode = .rotate
            self?.presentAnimationPrompt(type: .rotate)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    func handleBodyDrag(_ gesture: UIPanGestureRecognizer, entity: Entity) {
        // If dragStartPosition wasn't set in .began (e.g. touch landed on the
        // object body / foot rather than a named gizmo part), bootstrap it now
        // from the entity's current world position so the drag still works.
        if dragStartPosition == nil {
            dragStartPosition = entity.position
            gesture.setTranslation(.zero, in: arView)
            return
        }
        guard let startPos = dragStartPosition else { return }

        let translation = gesture.translation(in: arView)
        let mouseDelta  = SIMD2<Float>(Float(translation.x), Float(translation.y))
        var newPosition = startPos
        let dx = mouseDelta.x * 0.005
        let dy = -mouseDelta.y * 0.005
        if currentDragMode == .ground {
            let camOri      = arView.cameraTransform.rotation
            let flatForward = simd_normalize(SIMD3<Float>(camOri.act([0,0,-1]).x, 0, camOri.act([0,0,-1]).z))
            let flatRight   = simd_normalize(SIMD3<Float>(camOri.act([1,0,0]).x,  0, camOri.act([1,0,0]).z))
            newPosition    += (flatRight * dx) + (flatForward * dy)
            newPosition.y   = startPos.y
        } else {
            newPosition.y = startPos.y + (dy * 2.0)
        }
        entity.position = newPosition
        updateGizmoPosition()
    }

    func calculateWorldDragDelta(_ gesture: UIPanGestureRecognizer) -> SIMD3<Float> {
        let translation = gesture.translation(in: arView)
        gesture.setTranslation(.zero, in: arView)
        let dx = Float(translation.x) * 0.005
        let dz = Float(translation.y) * 0.005
        let cam = arView.cameraTransform.rotation
        return (cam.act([1,0,0]) * dx) + (cam.act([0,0,1]) * dz)
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
        var axisVector: SIMD3<Float> = [0,0,0]
        switch axis {
        case .x:    axisVector = [1,0,0]
        case .y:    axisVector = [0,1,0]
        case .z:    axisVector = [0,0,1]
        case .none: return [0,0,0]
        }
        let op = entity.position
        guard let sp = view.project(op), let se = view.project(op + axisVector) else { return [0,0,0] }
        let screenDir  = simd_normalize(SIMD2<Float>(Float(se.x-sp.x), Float(se.y-sp.y)))
        let projection = simd_dot(mouseDelta, screenDir)
        return axisVector * (projection * 0.002)
    }

    // ── Gesture recogniser delegate ───────────────────────────────────────────

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {

        guard gestureRecognizer is UIPanGestureRecognizer else { return true }
        if gestureRecognizer.numberOfTouches >= 2 { return true }
        let location = gestureRecognizer.location(in: arView)
        let hits     = arView.hitTest(location)
        let hitNames = Set(hits.map { $0.entity.name })

        // If the touch started on the outer ring, ringPan owns it exclusively.
        // Block handlePan so it doesn't also fire.
        if hitNames.contains("Gizmo_Ring_XZ") {
            return false
        }

        // In ROTATE mode: only allow handlePan on the 3-ring rotation gizmo
        if interactionMode == .rotate {
            let ringNames: Set<String> = ["xRing", "yRing", "zRing"]
            return !hitNames.isDisjoint(with: ringNames)
        }

        // Move mode / no mode: always allow — handlePan routes arrow/dot/body internally
        return true
    }


    
    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - handleRingPan
    //
    // Dedicated 1-finger pan recognizer registered BEFORE handlePan so it
    // gets first priority on touches that start on the outer ring collider
    // ("Gizmo_Ring_XZ").
    //
    // Behaviour: dragging along the ring rotates the selected entity around
    // its own world-space Y axis.  Works in any interactionMode — the ring is
    // always part of the move gizmo.
    //
    // gestureRecognizerShouldBegin returns false when the touch did NOT start
    // on the ring, so handlePan fires normally for all other touches.
    // ─────────────────────────────────────────────────────────────────────────

    /// Returns true only when the touch begins on "Gizmo_Ring_XZ".
    /// Because this recognizer is registered first it wins priority; handlePan
    /// falls through for every other touch location.
    func ringPanShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
        let location = gesture.location(in: arView)
        let hits     = arView.hitTest(location)
        return hits.contains { $0.entity.name == "Gizmo_Ring_XZ" }
    }

    @objc func handleRingPan(_ gesture: UIPanGestureRecognizer) {

        // Only act when there is a selected, unlocked entity
        guard let selected = selectedEntity else { return }
        let isLocked = selected.components[LockComponent.self]?.isLocked ?? false
        guard !isLocked else { return }

        let location = gesture.location(in: arView)

        switch gesture.state {

        case .began:
            // Confirm the touch really started on the ring collider
            let hits = arView.hitTest(location)
            guard hits.contains(where: { $0.entity.name == "Gizmo_Ring_XZ" }) else {
                return
            }
            saveCurrentStateToUndo()
            ringDragActive  = true
            lastPanLocation = location
            highlightGizmoPart(.rotateY)

        case .changed:
            guard ringDragActive else { return }

            let dx   = Float(location.x - lastPanLocation.x)
            let dy   = Float(location.y - lastPanLocation.y)
            // Map horizontal screen drag → Y-axis rotation angle.
            // Negate dx: positive dx (drag right) → negative angle → clockwise
            // rotation when viewed from above (right-hand rule around +Y).
            let angle: Float = -dx * 0.012
            guard angle.isFinite, angle != 0 else {
                lastPanLocation = location
                return
            }

            // Rotate around the WORLD Y axis so the object spins in place
            // regardless of its current orientation.
            var t      = selected.transform
            let rot    = simd_quatf(angle: angle, axis: SIMD3<Float>(0, 1, 0))
            t.rotation = simd_normalize(rot * t.rotation)
            selected.transform = t

            // Gizmo follows the entity
            updateGizmoPosition()
            lastPanLocation = location

        case .ended, .cancelled:
            ringDragActive = false
            resetGizmoColors()

        default:
            break
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - handleRotationPan  (3-ring rotation gizmo — .rotate mode only)
    // ─────────────────────────────────────────────────────────────────────────
    @objc func handleRotationPan(_ gesture: UIPanGestureRecognizer) {

        // Only run in rotation mode — the 3-ring gizmo is only shown then
        guard interactionMode == .rotate else { return }

        let location = gesture.location(in: arView)

        switch gesture.state {

        case .began:
            let hits = arView.hitTest(location)
            activeRotationAxis = nil
            activeGizmoPart    = .none

            if let hit = hits.first(where: {
                ["xRing","yRing","zRing"].contains($0.entity.name)
            }) {
                switch hit.entity.name {
                case "xRing": activeRotationAxis = [1,0,0]; activeGizmoPart = .rotateX
                case "yRing": activeRotationAxis = [0,1,0]; activeGizmoPart = .rotateY
                default:      activeRotationAxis = [0,0,1]; activeGizmoPart = .rotateZ
                }
                saveCurrentStateToUndo()
                highlightGizmoPart(activeGizmoPart)
                lastPanLocation = location
                return
            }

            // Object selection in rotate mode
            if let hit = arView.entity(at: location) {
                var root: Entity? = hit
                while let parent = root?.parent, parent.name != "MainAnchor" { root = parent }
                if root?.name.contains("Gizmo") == false {
                    setEntityTransparency(selectedEntity, alpha: 1.0)
                    selectedEntity = root
                    setEntityTransparency(root, alpha: 0.7)
                    updateGizmoMode()
                }
            } else {
                setEntityTransparency(selectedEntity, alpha: 1.0)
                selectedEntity = nil
                hideGizmo(); hideRotationGizmo()
            }

        case .changed:
            guard let axis     = activeRotationAxis,
                  let selected = selectedEntity else { return }
            let dx    = Float(location.x - lastPanLocation.x)
            let dy    = Float(location.y - lastPanLocation.y)
            let drag  = abs(dx) > abs(dy) ? dx : -dy
            let angle = drag * 0.006
            guard angle.isFinite else { return }
            var t      = selected.transform
            t.rotation = simd_normalize(simd_quatf(angle: angle, axis: axis) * t.rotation)
            selected.transform = t
            lastPanLocation    = location

        case .ended, .cancelled:
            activeRotationAxis = nil
            resetGizmoColors()

        default:
            break
        }
    }
}
