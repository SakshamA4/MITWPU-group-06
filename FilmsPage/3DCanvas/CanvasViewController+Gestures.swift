import Combine
import PhotosUI
import RealityKit
import UIKit
import ARKit
import ObjectiveC.runtime

// MARK: - Stored properties for ring gesture (via ObjC associated objects)
private var _ringPanGRKey:      UInt8 = 0
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

        // ── 7. Long press — path/arc context menu ─────────────────────────────
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handlePathLongPress(_:)))
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
        let translation = gesture.translation(in: arView)
        pitch += Float(translation.y) * 0.005
        pitch  = max(-1.4, min(1.4, pitch))
        gesture.setTranslation(.zero, in: arView)
        updateEditorCamera()
    }

    // ── Twist — yaw (empty) or entity Y-rotation (selected) ──────────────────

    @objc func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        guard !isARModeActive, editorMode == .edit else { return }

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
                if e.name == "GizmoRoot" || e.name.contains("Gizmo")       { return false }
                if e.name == "MotionPath" || e.name.hasPrefix("PathRoot_")
                    || e.name.hasPrefix("path.")                            { return false }
                if e.name.hasPrefix("RotationArc_") || e.name == "startLine"
                    || e.name == "endLine" || e.name == "arcCurve"
                    || e.name.hasPrefix("arcHandle.")                       { return false }
                if e.components[MotionPathHandleComponent.self] != nil
                    || e.components[RotationArcComponent.self]  != nil      { return false }
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
            setEntityTransparency(root, alpha: 0.9)
            updateGizmoMode()
            showActionMenu(at: location)
            
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

        let menu = EntityActionMenu()
        menu.configure(mode: isCamera ? .camera : .standard, isLocked: isCurrentlyLocked, showColorOption: showColorOption)
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

            case .changeColour:
                // Open color picker for wall/ground entities
                menu.removeFromSuperview()
                if let modelEntity = entity as? ModelEntity {
                    self.showColorPicker(for: modelEntity)
                }

            // ── Camera entity actions ───────────────────────────────────────
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
                    self.setEntityTransparency(entity, alpha: 0.9)
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
        if entity.components[CategoryComponent.self]?.toolType == .character {
            alert.addAction(UIAlertAction(title: "Walk (Path + Animation)", style: .default) { [weak self] _ in
                self?.interactionMode = .move
                self?.animateWalk()
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
        }
        entity.position = newPosition
        updateGizmoPosition()
    }

    func calculateWorldDragDelta(_ gesture: UIPanGestureRecognizer) -> SIMD3<Float> {
        let translation = gesture.translation(in: arView)
        gesture.setTranslation(.zero, in: arView)
        let dx = Float(translation.x) * 0.005
        let dz = Float(translation.y) * 0.005
        let camOri = activeCamera.orientation(relativeTo: nil)
        return (camOri.act([1,0,0]) * dx) + (camOri.act([0,0,1]) * dz)
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

            // Circular motion: project the gizmo centre to screen space,
            // then measure the angle of the touch around that centre.
            // The delta angle between frames is the rotation amount.
            if let gizmo = gizmoRoot,
               let centre2D = arView.project(gizmo.position(relativeTo: nil)) {

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
                t.rotation = simd_normalize(simd_quatf(angle: -delta, axis: [0,1,0]) * t.rotation)
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

    @objc func handleRotationPan(_ gesture: UIPanGestureRecognizer) {
        guard interactionMode == .rotate else { return }
        let location = gesture.location(in: arView)
        switch gesture.state {
        case .began:
            // FIX 5: Do NOT call saveCurrentStateToUndo() unconditionally.
            // Camera-orbit / deselect pans mustn't create empty undo entries.
            let hits = arView.hitTest(location)
            activeRotationAxis = nil
            activeGizmoPart    = .none
            if let hit = hits.first(where: { ["xRing","yRing","zRing"].contains($0.entity.name) }) {
                // The RotationRingGizmo is parented directly to the entity, so its
                // world-space matrix columns ARE the entity's current local axes in
                // world space. Read those columns from the gizmo itself (not from
                // the individual ring entities, which carry extra per-ring orientations
                // that don't correspond to the rotation axes).
                //   column 0 = entity's world +X  (red ring rotates around this)
                //   column 1 = entity's world +Y  (green ring rotates around this)
                //   column 2 = entity's world +Z  (blue ring rotates around this)
                // The torus mesh is built in the XY plane (face normal = [0,0,1]).
                // Each ring then gets an orientation baked in RotationRingGizmo:
                //   xRing: pi/2 around Y  → face normal becomes [1,0,0]  → col 0
                //   yRing: pi/2 around X  → face normal becomes [0,-1,0] → -col 1
                //   zRing: identity       → face normal stays  [0,0,1]   → col 2
                // We read these from the RotationRingGizmo's world matrix so the
                // axes follow the entity's current orientation correctly.
                let gizmoMatrix = (rotationGizmo ?? hit.entity).transformMatrix(relativeTo: nil)
                switch hit.entity.name {
                case "xRing":
                    activeRotationAxis = simd_normalize(SIMD3<Float>( gizmoMatrix.columns.0.x,
                                                                       gizmoMatrix.columns.0.y,
                                                                       gizmoMatrix.columns.0.z))
                    activeGizmoPart    = .rotateX
                case "yRing":
                    // yRing face normal is [0,-1,0] in local gizmo space → negate col 1
                    activeRotationAxis = simd_normalize(SIMD3<Float>(-gizmoMatrix.columns.1.x,
                                                                     -gizmoMatrix.columns.1.y,
                                                                     -gizmoMatrix.columns.1.z))
                    activeGizmoPart    = .rotateY
                default:
                    activeRotationAxis = simd_normalize(SIMD3<Float>( gizmoMatrix.columns.2.x,
                                                                       gizmoMatrix.columns.2.y,
                                                                       gizmoMatrix.columns.2.z))
                    activeGizmoPart    = .rotateZ
                }
                saveCurrentStateToUndo()
                highlightGizmoPart(activeGizmoPart)
                lastPanLocation = location
                return
            }
            if let hit = arView.entity(at: location) {
                var root: Entity? = hit
                while let parent = root?.parent, parent.name != "MainAnchor" { root = parent }
                if root?.name.contains("Gizmo") == false {
                    saveCurrentStateToUndo()   // FIX 5: only when an entity is selected
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
            guard let sel = selectedEntity else { return }
            let dx = Float(location.x - lastPanLocation.x)
            let dy = Float(location.y - lastPanLocation.y)

            // Get the ring entity directly from the gizmo so we can read its
            // true world-space normal — the axis the ring is physically lying on
            // right now, after all prior rotations.
            guard let gizmo = rotationGizmo else { lastPanLocation = location; return }

            let ringName: String
            switch activeGizmoPart {
            case .rotateX: ringName = "xRing"
            case .rotateY: ringName = "yRing"
            case .rotateZ: ringName = "zRing"
            default: lastPanLocation = location; return
            }

            guard let ring = gizmo.findEntity(named: ringName) else {
                lastPanLocation = location; return
            }

            // The ring's world orientation quaternion directly gives us its
            // local axes. The torus mesh is built in the XY plane so its face
            // normal is local +Z. After the ring's own baked orientation:
            //   xRing (pi/2 around Y): local Z rotates to world X  → use act([0,0,1])
            //   yRing (pi/2 around X): local Z rotates to world -Y → use act([0,0,1])
            //   zRing (identity):      local Z stays world Z        → use act([0,0,1])
            // In all cases we just rotate [0,0,1] by the ring's world quaternion.
            let ringWorldQuat = ring.orientation(relativeTo: nil)
            let liveAxis = simd_normalize(ringWorldQuat.act([0, 0, 1]))

            let angle: Float
            switch activeGizmoPart {
            case .rotateX: angle = (abs(dy) > abs(dx) ?  dy : -dx) * 0.006
            case .rotateZ: angle = (abs(dy) > abs(dx) ?  dy : -dx) * 0.006
            default:       angle = (abs(dx) > abs(dy) ?  dx : -dy) * 0.006
            }
            guard angle.isFinite else { return }

            // Apply rotation in world space using setOrientation so we don't
            // have to manually convert between local and world quaternion spaces.
            let deltaQuat    = simd_quatf(angle: angle, axis: liveAxis)
            let currentWorld = sel.orientation(relativeTo: nil)
            sel.setOrientation(simd_normalize(deltaQuat * currentWorld), relativeTo: nil)
            lastPanLocation = location
        case .ended, .cancelled:
            activeRotationAxis = nil
            resetGizmoColors()
        default: break
        }
    }
}
