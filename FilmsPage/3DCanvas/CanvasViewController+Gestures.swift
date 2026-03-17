import Combine
import PhotosUI
import RealityKit
import UIKit
import ARKit

extension CanvasViewController {

    func setupGestures() {
        // 1. Tap to select (Existing)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        arView.addGestureRecognizer(tap)

        // 2. Camera Rotation (2-Finger Pan)
        let cameraPan = UIPanGestureRecognizer(target: self, action: #selector(handleCameraPan(_:)))
        cameraPan.minimumNumberOfTouches = 2
        arView.addGestureRecognizer(cameraPan)

        // 3. Object/Gizmo Interaction (1-Finger Pan) — handles move gizmo AND rotation rings
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        pan.delegate = self
        arView.addGestureRecognizer(pan)

        // 4. Long Press (Existing)
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handlePathLongPress(_:)))
        longPress.minimumPressDuration = 0.45
        longPress.cancelsTouchesInView = false
        arView.addGestureRecognizer(longPress)

        // 5. Camera Zoom (Pinch)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        arView.addGestureRecognizer(pinch)

        // 6. Non-uniform axis resize (2-finger drag on Wall / Ground)
        let twoFingerPan = UIPanGestureRecognizer(target: self, action: #selector(handleTwoFingerPan(_:)))
        twoFingerPan.minimumNumberOfTouches = 2
        twoFingerPan.maximumNumberOfTouches = 2
        arView.addGestureRecognizer(twoFingerPan)

        // 7. Rotation (Existing)
        let rotation = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        arView.addGestureRecognizer(rotation)
    }


    
    @objc func handleCameraPan(_ gesture: UIPanGestureRecognizer) {
        // In AR mode the physical device IS the camera — editor orbit does nothing useful
        guard !isARModeActive else { return }

        let translation = gesture.translation(in: arView)

        // Sensitivity: how fast the camera turns
        let sensitivity: Float = 0.005

        // Update yaw (horizontal) and pitch (vertical)
        yaw -= Float(translation.x) * sensitivity
        pitch += Float(translation.y) * sensitivity

        // Constraint: Prevent the camera from flipping upside down
        pitch = max(min(pitch, 1.5), -1.5)

        gesture.setTranslation(.zero, in: arView)
        updateEditorCamera()
    }

    
    @objc func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        guard let entity = selectedEntity else { return }
        guard editorMode == .edit else { return }

        // LOCK CHECK
        let isLocked = entity.components[LockComponent.self]?.isLocked ?? false
        if isLocked { return }

        switch gesture.state {
        case .began:
            saveCurrentStateToUndo()
            initialRotation = entity.orientation

        case .changed:
            // Direct 1:1 mapping — gesture.rotation is accumulated radians since .began
            let totalGestureRotation = Float(gesture.rotation)
            if let startRotation = initialRotation {
                let rotationQuaternion = simd_quatf(angle: -totalGestureRotation, axis: [0, 1, 0])
                entity.orientation = rotationQuaternion * startRotation
                // NOTE: cameraCollectionView?.reloadData() intentionally removed.
                // Rotating a scene entity does not change the camera list, so rebuilding
                // the collection view at 60 fps here was pure wasted CPU/GPU work.
            }

        case .ended, .cancelled:
            // Refresh camera preview if the user rotated a scene camera.
            if entity.components[CategoryComponent.self]?.toolType == .camera,
               let idx = sceneCameraItems.firstIndex(where: { $0.cameraRoot === entity }) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.capturePreview(forCameraAt: idx)
                }
            }
            initialRotation = nil

        default:
            break
        }
    }

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: arView)

        // In AR mode: tap to place / reposition the entire scene on the real floor
        if isARModeActive {
            placeSceneOnRealSurface(at: location)
            return
        }

        pathEditToolbar?.removeFromSuperview()
        pathEditToolbar = nil

        // ─────────────────────────────
        // 0️⃣ ROTATION ARC HANDLE SELECTION
        // Tap just records which arc is selected for context menus.
        // Actual drag is handled entirely in handlePan (self-contained).
        // ─────────────────────────────
        if let hit = arView.entity(at: location),
           let arcComp = hit.components[RotationArcComponent.self]
        {
            selectedArcClipID = arcComp.clipID
            setEntityTransparency(selectedEntity, alpha: 1.0)
            selectedEntity    = nil
            activeHandleEntity = nil
            hideGizmo()
            hideRotationGizmo()
            return
        }

        // ─────────────────────────────
        // 1️⃣ MOTION PATH HANDLE SELECTION
        // ─────────────────────────────
        if let hit = arView.entity(at: location),
            let handle = hit.components[MotionPathHandleComponent.self]
        {
            selectedPathClipID = handle.clipID
            updatePathSelection()

            setEntityTransparency(selectedEntity, alpha: 1.0)
            selectedEntity = nil
            hideRotationGizmo()

            // Show gizmo on tapped handle so user can drag via gizmo arrows/plane
            activeHandleEntity = hit
            hideGizmo()
            showGizmo(at: hit)

            return
        }

        
        currentActionMenu?.removeFromSuperview()
        currentActionMenu = nil
        
        // 1. Perform Hit Test
        let hits = arView.hitTest(location)
        
        // 2. Filter hits: ignore Gizmo, motion path, and arc entities
        let objectHit = hits.first { hit in
            var current: Entity? = hit.entity
            while let checkEntity = current {
                if checkEntity.name == "GizmoRoot" || checkEntity.name.contains("Gizmo") {
                    return false
                }
                if checkEntity.name == "MotionPath" || checkEntity.name.hasPrefix("PathRoot_")
                    || checkEntity.name.hasPrefix("path.") {
                    return false
                }
                if checkEntity.name.hasPrefix("RotationArc_")
                    || checkEntity.name == "startLine" || checkEntity.name == "endLine"
                    || checkEntity.name == "arcCurve"
                    || checkEntity.name.hasPrefix("arcHandle.") {
                    return false
                }
                if checkEntity.components[MotionPathHandleComponent.self] != nil
                    || checkEntity.components[RotationArcComponent.self] != nil {
                    return false
                }
                if checkEntity.name == "MainAnchor" { break }
                current = checkEntity.parent
            }
            return true
        }
        
        if let hitResult = objectHit {
            // 3. Find the valid scene object's root
            var root: Entity = hitResult.entity
            while let parent = root.parent, parent.name != "MainAnchor" {
                root = parent
            }
            
            // 4. Handle Selection Transitions
            if let previous = selectedEntity, previous != root {
                setEntityTransparency(previous, alpha: 1.0)
            }
            
            selectedEntity = root

            activeHandleEntity = nil          // no longer editing a path handle
            // Apply transparency so gizmo/rings are visible
            setEntityTransparency(root, alpha: 0.7)
            
            // 🔥 This decides whether we show move gizmo OR rotation rings
            updateGizmoMode()
            
            showActionMenu(at: location)
            
            if let animation = root.availableAnimations.first {
                root.playAnimation(animation.repeat(count: 1))
            }
            
        } else {
            // 5. Tapped empty space -> Clean up everything
            setEntityTransparency(selectedEntity, alpha: 1.0)
            selectedEntity = nil
            activeHandleEntity = nil
            
            updateGizmoMode()
            
            hideGizmo()
            hideRotationGizmo()
            hideAnimationPanel()
        }
        
        
    }


    func showActionMenu(at point: CGPoint) {

        guard let entity = selectedEntity else { return }

        let isCurrentlyLocked = entity.components[LockComponent.self]?.isLocked ?? false

        // ── Determine camera vs standard entity ────────────────────────────
        // Camera roots are named "SceneCamera_N" and carry CategoryComponent(.camera).
        let isCamera = entity.name.lowercased().contains("scenecamera")
            || entity.components[CategoryComponent.self]?.toolType == .camera

        let menu = EntityActionMenu()

        // ⚠️  configure() MUST be called before addSubview.
        //     It calls buildButtons() which reads mode — if you addSubview first
        //     the view is already in the hierarchy with no buttons built yet.
        menu.configure(
            mode: isCamera ? .camera : .standard,
            isLocked: isCurrentlyLocked
        )

        menu.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(menu)

        NSLayoutConstraint.activate([
            menu.centerXAnchor.constraint(equalTo: view.leadingAnchor, constant: point.x),
            menu.bottomAnchor.constraint(equalTo: view.topAnchor,      constant: point.y - 40),
        ])

        menu.onAction = { [weak self] action in
            guard let self = self else { return }

            switch action {

            // ── Standard entity actions ─────────────────────────────────────
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
                // Presents a simple alert letting the user choose Move or Rotate animation.
                // Each choice goes through the existing presentAnimationPrompt() pipeline
                // so timing, path creation, and showMotionPath() all work automatically.
                menu.removeFromSuperview()
                self.presentAddMovementPicker(for: entity)

            // ── Camera entity actions ───────────────────────────────────────
            case .addShot:
                // Opens the full shot-picker sheet (camera movements + static shots).
                menu.removeFromSuperview()
                self.presentShotPicker(for: entity)

            // ── Shared actions ──────────────────────────────────────────────
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
                    self.setEntityTransparency(entity, alpha: 0.7)
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

    // ── Add Movement picker (non-camera entities) ──────────────────────────
    // Simple action sheet: "Move" or "Rotate" — feeds into the standard
    // presentAnimationPrompt() path so timing/path creation are unchanged.
    func presentAddMovementPicker(for entity: Entity) {
        let alert = UIAlertController(
            title: "Add Movement",
            message: "Choose the type of animation to add",
            preferredStyle: .actionSheet
        )
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

    
    
    // @objc func handlePan(_ gesture: UIPanGestureRecognizer) { (SAKSHAM GITHUB 3D canvas file)

    
    func handleBodyDrag(_ gesture: UIPanGestureRecognizer, entity: Entity) {
        guard let startPos = dragStartPosition else { return }
        let translation = gesture.translation(in: arView)
        let mouseDelta = SIMD2<Float>(Float(translation.x), Float(translation.y))

        var newPosition = startPos
        // FIX: sensitivity now scales with camera distance, matching panCameraTarget()
        // which uses distance * 0.0015. At distance=5 this gives 0.0015; at distance=15
        // it gives 0.0045 — so dragging feels consistent regardless of zoom level.
        // The old fixed 0.005 was too fast when zoomed in and too slow when zoomed out.
        let sensitivity: Float = max(0.001, distance * 0.0003)
        let dx = mouseDelta.x * sensitivity
        let dy = -mouseDelta.y * sensitivity
        
        if currentDragMode == .ground {
            let camOri = arView.cameraTransform.rotation
            let right = camOri.act([1, 0, 0])
            let forward = camOri.act([0, 0, -1])
            
            let flatForward = simd_normalize(SIMD3<Float>(forward.x, 0, forward.z))
            let flatRight = simd_normalize(SIMD3<Float>(right.x, 0, right.z))
            
            newPosition += (flatRight * dx) + (flatForward * dy)
            newPosition.y = startPos.y
        } else {
            newPosition.y = startPos.y + (dy * 2.0)
        }
        
        entity.position = newPosition
        updateGizmoPosition()
    }




    func calculateWorldDragDelta(_ gesture: UIPanGestureRecognizer) -> SIMD3<
        Float
    > {
        
        let translation = gesture.translation(in: arView)
        gesture.setTranslation(.zero, in: arView)
        
        let sensitivity: Float = 0.005
        
        let dx = Float(translation.x) * sensitivity
        let dz = Float(translation.y) * sensitivity
        
        let cam = arView.cameraTransform.rotation
        
        let right = cam.act([1, 0, 0])
        let forward = cam.act([0, 0, 1])
        
        return (right * dx) + (forward * dz)
    }

    
    @objc func toggleMovementTapped(_ sender: UIButton) {
        if currentDragMode == .ground {
            currentDragMode = .vertical
            print("Switched to Vertical (Y) Movement")
            // Update button icon here if needed
            sender.setImage(
                UIImage(systemName: "arrow.up.and.down"),
                for: .normal
            )
            sender.tintColor = .yellow  // Visual feedback
        } else {
            currentDragMode = .ground
            print("Switched to Ground (XZ) Movement")
            // Update button icon here if needed
            sender.setImage(
                UIImage(systemName: "arrow.left.and.right"),
                for: .normal
            )
            sender.tintColor = .white
        }
    }

    
    func calculateAxisMovement(
        entity: Entity,
        axis: GizmoAxis,
        mouseDelta: SIMD2<Float>,
        view: ARView
    ) -> SIMD3<Float> {
        
        var axisVector: SIMD3<Float> = [0, 0, 0]
        
        switch axis {
        case .x: axisVector = [1, 0, 0]
        case .y: axisVector = [0, 1, 0]
        case .z: axisVector = [0, 0, 1]
        case .none: return [0, 0, 0]
        }
        
        // 2. Project 3D points to 2D Screen Space to find the "Visual Line"
        let objectWorldPos = entity.position
        // A point slightly further along the axis
        let axisEndWorldPos = objectWorldPos + axisVector
        
        // Project both to screen coordinates
        guard let screenPosCenter = view.project(objectWorldPos),
              let screenPosAxisEnd = view.project(axisEndWorldPos)
        else {
            return [0, 0, 0]
        }
        
        // 3. Calculate the Screen Vector (The direction of the arrow on screen)
        let screenVector = SIMD2<Float>(
            Float(screenPosAxisEnd.x - screenPosCenter.x),
            Float(screenPosAxisEnd.y - screenPosCenter.y)
        )
        
        // Normalize to get direction only
        let screenDir = simd_normalize(screenVector)
        
        // 4. Dot Product
        // This tells us how much we moved the mouse *along* that line
        let projection = simd_dot(mouseDelta, screenDir)
        
        // 5. Sensitivity Factor
        // Adjust this to make the movement feel 1:1 or slower
        let sensitivity: Float = 0.002
        
        // 6. Return the 3D delta
        // We multiply the World Axis Vector by the projected amount
        return axisVector * (projection * sensitivity)
    }

    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer is UIPanGestureRecognizer else { return true }

        let location = gestureRecognizer.location(in: arView)

        // FIX 11: Use a single hitTest for both arc-component check and gizmo check —
        // previously arView.entity(at:) + arView.hitTest() were both called on the same
        // location, performing two separate BVH traversals per gesture recognition cycle.
        let hits = arView.hitTest(location)

        // Always allow pans that start on an arc handle tip
        if hits.first(where: { $0.entity.components[RotationArcComponent.self] != nil }) != nil {
            return true
        }

        // Allow gizmo and ring hits
        for hit in hits {
            let name = hit.entity.name
            if name.contains("Gizmo") || name == "xRing" || name == "yRing" || name == "zRing" {
                return true
            }
        }

        // In rotate mode: only allow if an entity is selected
        if interactionMode == .rotate {
            return selectedEntity != nil || activeHandleEntity != nil
        }

        return true
    }


    
    @objc func handleRotationPan(_ gesture: UIPanGestureRecognizer) {
        
        
        // Only run in rotation mode
        guard interactionMode == .rotate else { return }
        
        let location = gesture.location(in: arView)
        
        switch gesture.state {
            
        case .began:
            // FIX 5: Do NOT call saveCurrentStateToUndo() unconditionally.
            // Camera-orbit / deselect pans mustn't create empty undo entries.
            let hits = arView.hitTest(location)
            
            // 1. Reset selection state for this touch
            activeRotationAxis = nil
            activeGizmoPart = .none
            
            // 2. Priority: Check if we hit a GIZMO part
            if let gizmoHit = hits.first(where: { $0.entity.name.contains("Ring") || $0.entity.name.contains("Arrow") || $0.entity.name.contains("Plane") }) {
                saveCurrentStateToUndo()   // FIX 5: only on real gizmo hit
                let name = gizmoHit.entity.name
                
                // Handle Movement Parts
                if name.contains("Arrow_Y") {
                    activeGizmoPart = .arrowY
                } else if name.contains("Plane_XZ") {
                    activeGizmoPart = .planeXZ
                }
                // Handle Rotation Rings
                else if name == "xRing" {
                    activeRotationAxis = [1, 0, 0]
                    activeGizmoPart = .rotateX
                } else if name == "yRing" {
                    activeRotationAxis = [0, 1, 0]
                    activeGizmoPart = .rotateY
                } else if name == "zRing" {
                    activeRotationAxis = [0, 0, 1]
                    activeGizmoPart = .rotateZ
                }
                
                highlightGizmoPart(activeGizmoPart)
                lastPanLocation = location
                return // Stop here if we touched the gizmo
            }

            // 3. Secondary: Check if we hit an OBJECT
            if let hit = arView.entity(at: location) {
                var root: Entity? = hit
                while let parent = root?.parent, parent.name != "MainAnchor" { root = parent }

                if root?.name.contains("Gizmo") == false {
                    saveCurrentStateToUndo()   // FIX 5: only when an entity is selected
                    setEntityTransparency(selectedEntity, alpha: 1.0)
                    selectedEntity = root
                    setEntityTransparency(root, alpha: 0.7)
                    updateGizmoMode()   // spawns rings immediately on the new entity
                }
            } else {
                // 4. Final: Hit BLANK SPACE -> Deselect and Hide
                setEntityTransparency(selectedEntity, alpha: 1.0)
                selectedEntity = nil
                hideGizmo()
                hideRotationGizmo()
            }
        case .changed:
            
            
            guard let axis = activeRotationAxis,
                  let selected = selectedEntity else { return }
            
            let dx = Float(location.x - lastPanLocation.x)
            let dy = Float(location.y - lastPanLocation.y)
            
            let drag = abs(dx) > abs(dy) ? dx : -dy
            let angle = drag * 0.005
            
            // Safety check — prevent NaN rotations
            guard angle.isFinite else { return }
            
            let rotation = simd_quatf(angle: angle, axis: axis)
            
            var transform = selected.transform
            
            // Stable incremental rotation
            transform.rotation = rotation * transform.rotation
            
            // Safety normalize quaternion
            transform.rotation = simd_normalize(transform.rotation)
            
            selected.transform = transform
            
            lastPanLocation = location
            
            
        case .ended, .cancelled:
            
            activeRotationAxis = nil
            
        default:
            break
        }
        
    }

    // MARK: - Non-Uniform Scaling (Two-Finger Drag)

    /// Two-finger drag resizes Wall and Ground along individual axes:
    ///   • Horizontal drag  → width
    ///   • Vertical drag    → height (Wall) / depth (Ground)
    /// When no entity is selected the gesture is silently ignored so the
    /// existing 2-finger camera-orbit gesture continues to work.
    @objc func handleTwoFingerPan(_ gesture: UIPanGestureRecognizer) {
        guard editorMode == .edit,
              let entity = selectedEntity as? ModelEntity else { return }

        let isLocked = entity.components[LockComponent.self]?.isLocked ?? false
        guard !isLocked else { return }

        switch gesture.state {
        case .began:
            saveCurrentStateToUndo()

        case .changed:
            let translation = gesture.translation(in: arView)
            let dx = Float(translation.x)
            let dy = Float(translation.y)

            // Use whichever axis is dominant to drive the resize.
            let horizontal = abs(dx) >= abs(dy)

            let sensitivity: Float = 0.002   // metres per point

            // --- WallComponent ---
            if var wall = entity.components[WallComponent.self] {
                if horizontal {
                    wall.width += dx * sensitivity
                } else {
                    wall.height -= dy * sensitivity   // drag down → smaller
                }
                wall.width  = max(0.3, min(wall.width,  10))
                wall.height = max(0.3, min(wall.height,  6))
                entity.model?.mesh = MeshResource.generateBox(
                    width: wall.width,
                    height: wall.height,
                    depth: 0.05
                )
                // NOTE: generateCollisionShapes is NOT called here — it is expensive
                // (rebuilds the physics shape) and calling it every .changed frame
                // (60 fps) was a major cause of the app hanging. It is called once
                // in .ended below.
                entity.components.set(wall)
                gesture.setTranslation(.zero, in: arView)
            }

            // --- GroundComponent ---
            if var ground = entity.components[GroundComponent.self] {
                if horizontal {
                    ground.width += dx * sensitivity
                } else {
                    ground.depth -= dy * sensitivity   // drag down → shallower
                }
                ground.width = max(0.5, min(ground.width, 20))
                ground.depth = max(0.5, min(ground.depth, 20))
                entity.model?.mesh = MeshResource.generatePlane(
                    width: ground.width,
                    depth: ground.depth
                )
                // Same rationale: defer to .ended
                entity.components.set(ground)
                gesture.setTranslation(.zero, in: arView)
            }

        case .ended, .cancelled:
            // Rebuild collision shapes once the gesture is complete.
            // This is the correct time to call this — the mesh has its final size
            // and we only pay the cost once per drag, not once per frame.
            entity.generateCollisionShapes(recursive: true)

        default:
            break
        }
    }

}
