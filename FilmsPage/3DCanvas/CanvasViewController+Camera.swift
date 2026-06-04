import PhotosUI
import RealityKit
import UIKit
import ARKit
import Combine

extension CanvasViewController {

    func handleCameraOrbit(_ gesture: UIPanGestureRecognizer) {
        // In AR mode the real device camera moves — no editor orbit needed
        if isARModeActive { return }
        // When looking through a scene camera, camera-view gestures handle movement
        if activeCamera !== editorCamera { return }
        let translation = gesture.translation(in: arView)

        yaw -= Float(translation.x) * 0.005
        pitch += Float(translation.y) * 0.005
        pitch = max(0.05, min(1.4, pitch))

        updateEditorCamera()
        gesture.setTranslation(.zero, in: arView)
    }

    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        // When looking through a scene camera, pinch = truck Z (handled by camera-view gestures)
        if activeCamera !== editorCamera {
            gesture.scale = 1.0
            return
        }
        if gesture.state == .began {
            saveCurrentStateToUndo()
        }
        guard editorMode == .edit, !isARModeActive else {
            gesture.scale = 1.0
            return
        }

        if gesture.state == .changed {
            let capturedScale = Float(gesture.scale)
            gesture.scale = 1.0

            // ── If a resizable environment entity is selected, resize it only ──
            // Pinch does NOT zoom the camera in this case, giving the user full
            // control over the wall / background / ground size.
            if let entity = selectedEntity,
               !(entity.components[LockComponent.self]?.isLocked ?? false) {

                // ── Prop / Character entities — uniform scale ──────────────────
                // Props and characters are loaded from USDZ as plain Entity roots,
                // not ModelEntity, so this check must come before the ModelEntity cast.
                if entity.components[CategoryComponent.self]?.toolType == .prop
                    || entity.components[CategoryComponent.self]?.toolType == .character {
                    var newScale = entity.scale * capturedScale
                    newScale = simd_clamp(newScale, SIMD3(repeating: 0.05), SIMD3(repeating: 10.0))
                    entity.scale = newScale
                    return
                }

                // ── Wall / Background / Ground — procedural mesh resize ───────
                if let modelEntity = entity as? ModelEntity {

                    if var wall = modelEntity.components[WallComponent.self] {
                        if let ratio = wall.aspectRatio, ratio.width > 0 {
                            // Ratio-locked: drive width, derive height
                            wall.width *= capturedScale
                            wall.width  = max(0.3, min(wall.width, 10))
                            wall.height = wall.width / Float(ratio.width / ratio.height)
                            wall.height = max(0.3, min(wall.height, 6))
                        } else {
                            // Free resize
                            wall.width  *= capturedScale
                            wall.height *= capturedScale
                            wall.width  = max(0.3, min(wall.width, 10))
                            wall.height = max(0.3, min(wall.height, 6))
                        }
                        modelEntity.model?.mesh = MeshResource.generateBox(
                            width: wall.width, height: wall.height, depth: wall.thickness)
                        modelEntity.generateCollisionShapes(recursive: true)
                        modelEntity.components.set(wall)
                        return   // skip camera zoom
                    }

                    if var bg = modelEntity.components[BackgroundComponent.self] {
                        bg.width  *= capturedScale
                        bg.height *= capturedScale
                        bg.width  = max(0.5, min(bg.width, 15))
                        bg.height = max(0.5, min(bg.height, 10))
                        modelEntity.model?.mesh = MeshResource.generateBox(
                            width: bg.width, height: bg.height, depth: 0.05)
                        modelEntity.generateCollisionShapes(recursive: true)
                        modelEntity.components.set(bg)
                        return   // skip camera zoom
                    }

                    if var ground = modelEntity.components[GroundComponent.self] {
                        if let ratio = ground.aspectRatio, ratio.width > 0 {
                            // Ratio-locked: drive width, derive depth
                            ground.width *= capturedScale
                            ground.width = max(0.5, min(ground.width, 20))
                            ground.depth = ground.width / Float(ratio.width / ratio.height)
                            ground.depth = max(0.5, min(ground.depth, 20))
                        } else {
                            // Free resize
                            ground.width *= capturedScale
                            ground.depth *= capturedScale
                            ground.width = max(0.5, min(ground.width, 20))
                            ground.depth = max(0.5, min(ground.depth, 20))
                        }
                        modelEntity.model?.mesh = MeshResource.generatePlane(
                            width: ground.width, depth: ground.depth)
                        modelEntity.generateCollisionShapes(recursive: true)
                        modelEntity.components.set(ground)
                        return   // skip camera zoom
                    }
                }
            }

            // ── No resizable entity selected — normal camera zoom ──────────────
            distance /= capturedScale
            distance = max(1.5, min(15, distance))
            updateEditorCamera()
            gesture.scale = 1.0
            return
        }

        if gesture.state == .ended || gesture.state == .cancelled {
            CanvasTutorialManager.shared.handleZoomGestureEnded()
        }
    }

    func updateEditorCamera() {
        guard let camera = editorCamera else { return }
        let x = distance * cos(pitch) * sin(yaw)
        let y = distance * sin(pitch)
        let z = distance * cos(pitch) * cos(yaw)

        // Apply position relative to the orbit pivot (cameraTarget)
        var camPos = SIMD3<Float>(x, y, z) + cameraTarget
        camPos.y = max(0.1, camPos.y)
        camera.position = camPos

        // Always look at the current pivot point
        camera.look(at: cameraTarget, from: camera.position, relativeTo: nil)

        // Rescale gizmos so they stay a constant screen size as the camera moves
        updateGizmoScales()

        // Sync navigation compass
        compassView.updateRotation(yaw: yaw)
    }

    // MARK: - Camera Pivot: Orbit Around Selected Entity
    //
    // Called from handleTap() whenever a scene entity is selected.
    // Moves the orbit pivot to the entity's world position so the camera
    // naturally orbits around the object the user just tapped.
    func pivotCameraToEntity(_ entity: Entity) {
        guard !isARModeActive else { return }
        // World-space position becomes the new orbit center
        cameraTarget = entity.position(relativeTo: nil)
        updateEditorCamera()
    }

    // MARK: - Camera Pivot: Orbit Around Path Handle
    //
    // Called from handleTap() whenever a motion path handle is selected.
    // Moves the orbit pivot to the handle so fine-grained path editing
    // doesn't fight a distant orbit center.
    func pivotCameraToHandle(_ handle: Entity) {
        guard !isARModeActive else { return }
        cameraTarget = handle.position(relativeTo: nil)
        updateEditorCamera()
    }

    // MARK: - Frame Entity (Focus / 'F' key equivalent)
    //
    // Centers the view on an entity and pulls the camera back to a distance
    // proportional to the object's bounding box — like Blender's numpad period.
    func frameEntity(_ entity: Entity) {
        guard !isARModeActive else { return }

        // 1. Compute the world-space bounding box
        let bounds = entity.visualBounds(relativeTo: nil)

        // 2. Center of the bounding box becomes the new orbit pivot
        let center = (bounds.min + bounds.max) * 0.5
        cameraTarget = center

        // 3. Pull camera back based on object size.
        //    maxDimension * 3 gives comfortable framing; clamp to editor limits.
        let maxDimension = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
        distance = max(1.5, min(15.0, maxDimension * 3.0))

        updateEditorCamera()
    }

    // MARK: - Camera Panning (Two-finger slide moves the orbit pivot)
    //
    // Translates cameraTarget along the camera's right and up axes so the
    // scene slides in the direction of the gesture — identical feel to
    // middle-mouse-drag in Maya / Blender.
    //
    // Scale is proportional to `distance` so panning near large scenes
    // moves further per pixel than panning close to a small object.
    func panCameraTarget(translation: CGPoint) {
        guard !isARModeActive else { return }

        // Camera right vector — derived from yaw only so it stays level
        let cameraRight   = SIMD3<Float>(cos(yaw), 0, -sin(yaw))

        // Flat-forward vector — camera look direction projected onto XZ plane
        // so vertical drag moves toward/away from camera, not up/down in world
        let cameraForward = simd_normalize(SIMD3<Float>(-sin(yaw), 0, -cos(yaw)))

        let scale: Float = distance * 0.0015

        // Negate X so scene slides in the same direction as the finger
        cameraTarget -= cameraRight   *  Float(translation.x) * scale
        // Negate forward*(-Y) so dragging down moves scene toward camera
        cameraTarget -= cameraForward * -Float(translation.y) * scale
        cameraTarget.y = max(0, cameraTarget.y)

        updateEditorCamera()
    }

    func makeCameraVisual() -> ModelEntity {
        let body = ModelEntity(
            mesh: .generateBox(size: [0.2, 0.12, 0.1]),
            materials: [SimpleMaterial(color: .darkGray, isMetallic: true)]
        )
        let lens = ModelEntity(
            mesh: .generateCylinder(height: 0.08, radius: 0.03),
            materials: [SimpleMaterial(color: .black, isMetallic: true)]
        )
        lens.position.z = 0.08
        body.addChild(lens)
        return body
    }

    func spawnSceneCamera(modelName: String = "cam1", displayName: String = "DSLR", aspectRatio: CameraAspectRatio = .default) {
        guard let anchor = arView.scene.findEntity(named: "MainAnchor") else { return }

        let index = sceneCameras.count
        let cameraRoot = Entity()
        cameraRoot.name = "SceneCameraRoot_\(index)"
        cameraRoot.components.set(CategoryComponent(toolType: .camera))
        let cameraID = UUID()
        cameraRoot.components.set(EntityIDComponent(id: cameraID))
        // Persist which visual model asset this camera uses
        cameraRoot.components.set(CameraVisualComponent(modelName: modelName, displayName: displayName))
        cameraRoot.components.set(CameraAspectComponent(aspectRatio: aspectRatio))

        let camera = PerspectiveCamera()
        camera.name = "SceneCamera_\(index)"
        camera.isEnabled = false
        // RealityKit cameras shoot along local -Z. The cam1 model lens faces +Z,
        // so rotate 180° around Y to make the camera shoot in the +Z direction.
        camera.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0])

        let randomX = Float.random(in: -2...2)
        let randomZ = Float.random(in: -2...2)
        cameraRoot.position = [randomX, 1, randomZ]

        cameraRoot.addChild(camera)
        anchor.addChild(cameraRoot)

        sceneCameras.append(camera)
        cameraToVisualMap[camera] = cameraRoot
        cameraCounter += 1
        sceneCameraItems.append(SceneCameraItem(
            id: cameraID,
            camera: camera,
            cameraRoot: cameraRoot,
            displayName: "Camera \(cameraCounter)",
            aspectRatio: aspectRatio
        ))

        cameraCollectionView?.reloadData()
        startCameraPreviewUpdates()
        setCameraPanelExpanded(true, animated: true)
        setupCameraPanelSwipeGestures()

        self.notifyEntitySpawned(toolType: .camera)

        // Load the visual model asset asynchronously.
        // Falls back to the procedural mesh visual if the asset is not found.
        loadCameraVisualModel(modelName, onto: cameraRoot, camera: camera)
    }

    /// Loads a camera visual model asset and attaches it to a camera root entity.
    /// Shared between `spawnSceneCamera()` and the persistence restore path.
    func loadCameraVisualModel(_ modelName: String, onto cameraRoot: Entity, camera: PerspectiveCamera) {
        Task { @MainActor in
            do {
                let model = try await Entity(named: modelName)

                // Add to scene FIRST — collision shape generation needs the
                // entity in the render graph or Metal validation will abort
                cameraRoot.addChild(model)

                let bounds = model.visualBounds(relativeTo: nil)
                let maxDim = max(bounds.extents.x, max(bounds.extents.y, bounds.extents.z))
                if maxDim > 0.0001 {
                    model.scale = SIMD3(repeating: 0.2 / maxDim)
                }

                model.generateCollisionShapes(recursive: true)
                model.components.set(InputTargetComponent())

                let scaledBounds = model.visualBounds(relativeTo: cameraRoot)
                camera.position = SIMD3<Float>(
                    scaledBounds.center.x,
                    scaledBounds.center.y,
                    scaledBounds.min.z
                )
                print("📷 Loaded camera visual model: \(modelName)")
            } catch {
                print("⚠️ Camera model '\(modelName)' not found, using procedural fallback")
                let fallback = self.makeCameraVisual()
                cameraRoot.addChild(fallback)
                fallback.generateCollisionShapes(recursive: true)
                fallback.components.set(InputTargetComponent())
                camera.position = SIMD3<Float>(0, 0, -0.05)
            }
        }
    }

    func setupCameraPanelSwipeGestures() {
        guard let panel = view.viewWithTag(8800) else { return }

        // Only add once
        if panel.gestureRecognizers?.contains(where: { $0 is UISwipeGestureRecognizer }) == true { return }

        // Swipe LEFT on panel → collapse
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handlePanelSwipe(_:)))
        swipeLeft.direction = .right  // swiping right = toward the right edge = collapse
        panel.addGestureRecognizer(swipeLeft)

        // Swipe RIGHT from right edge of screen → expand
        // We attach this to the main view so it catches the swipe even when panel is thin
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handlePanelSwipe(_:)))
        swipeRight.direction = .left  // swiping left = pulling out from right edge = expand
        view.addGestureRecognizer(swipeRight)
    }

    @objc private func handlePanelSwipe(_ gesture: UISwipeGestureRecognizer) {
        guard view.viewWithTag(8800) != nil else { return }

        if gesture.direction == .right {
            // Swiped right on the panel → collapse it
            setCameraPanelExpanded(false, animated: true)
        } else if gesture.direction == .left {
            // Swiped left anywhere → only expand if swipe originated near the right edge
            let location = gesture.location(in: view)
            let rightEdgeZone = view.bounds.width - 60  // within 60pt of right edge
            if location.x >= rightEdgeZone || !isCameraPanelExpanded {
                setCameraPanelExpanded(true, animated: true)
            }
        }
    }

    func deleteSceneCamera(cameraRoot: Entity) {
        // Find the matching item by cameraRoot reference
        guard let index = sceneCameraItems.firstIndex(where: { $0.cameraRoot === cameraRoot }) else {
            return
        }

        let item = sceneCameraItems[index]

        // If this camera was the active camera, switch back to editor camera first
        if activeCamera === item.camera {
            activateEditorCamera()
        }

        // Remove from all tracking arrays
        sceneCameras.removeAll { $0 === item.camera }
        cameraToVisualMap.removeValue(forKey: item.camera)
        sceneCameraItems.remove(at: index)

        // Remove the entity from the scene
        cameraRoot.removeFromParent()

        // Reload the collection view — use reloadData for safety since
        // the data source has already been modified above.
        cameraCollectionView?.reloadData()

        if sceneCameraItems.isEmpty {
            stopCameraPreviewUpdates()
            setCameraPanelExpanded(false, animated: true)
            // Hide the pull-tab when there are no cameras left
            view.viewWithTag(8803)?.alpha = 0
        }

        refreshSidebarContent()
    }

    func collectionView(_ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.bounds.width - 16   // full panel width minus padding
        return CGSize(width: width, height: width * 0.75)  // 4:3 aspect, no extra label row
    }

    func activateEditorCamera() {
        for cam in sceneCameras { cam.isEnabled = false }
        editorCamera.isEnabled = true
        activeCamera = editorCamera
        // Restore all camera model visuals when returning to editor view
        for (_, cameraRoot) in cameraToVisualMap {
            cameraRoot.children.forEach { child in
                if !(child is PerspectiveCamera) { child.isEnabled = true }
            }
        }
        // Before showing paths, update all animation clips if the camera was moved
        syncCameraClipsAfterCameraView()
        showAllMotionPaths()
        showAllRotationArcs()
        hideExitCameraButton()
        // Remove aspect ratio overlay — no scene camera is active in editor mode
        removeLetterboxOverlay()
        // Remove camera view HUD overlay and gestures
        cameraViewOverlay?.removeFromSuperview()
        cameraViewOverlay = nil
        enableCameraViewGestures(false)
        // Restore gizmos in editor view
        gizmoRoot?.isEnabled = true
        rotationGizmo?.isEnabled = true
        // Restore camera panel visibility in editor view
        view.viewWithTag(8800)?.isHidden = false
        view.viewWithTag(8803)?.isHidden = false
        // Restore toolbars and buttons
        navigationController?.setNavigationBarHidden(false, animated: true)
        view.viewWithTag(8804)?.isHidden = false // toolbar
        view.viewWithTag(8805)?.isHidden = false // viewModeControl
        view.viewWithTag(8806)?.isHidden = false // rotateBtn
        shotBreakdownBtn.isHidden = false
        sidebarView.isHidden = false
        layersButton.isHidden = false
        movementToggleButton.isHidden = false
    }

    func setActiveCamera(_ camera: PerspectiveCamera) {
        for cam in sceneCameras { cam.isEnabled = false }
        editorCamera.isEnabled = false
        camera.isEnabled = true
        activeCamera = camera
        // Restore visuals for all cameras first, then hide only the active one's visual
        for (_, cameraRoot) in cameraToVisualMap {
            cameraRoot.children.forEach { child in
                if !(child is PerspectiveCamera) { child.isEnabled = true }
            }
        }
        if let activeCameraRoot = cameraToVisualMap[camera] {
            activeCameraRoot.children.forEach { child in
                if !(child is PerspectiveCamera) { child.isEnabled = false }
            }
            // Apply aspect ratio letterbox overlay
            let ratio = activeCameraRoot.components[CameraAspectComponent.self]?.aspectRatio ?? .default
            updateLetterboxOverlay(for: ratio)
        }
        // Hide gizmos and all editor overlays — they obstruct the camera preview
        gizmoRoot?.isEnabled = false
        rotationGizmo?.isEnabled = false
        // Hide yellow drop-shadow projection lines
        hideDropShadow()
        selectedEntity = nil
        // Store camera position on entry so we can compute delta on exit
        if let activeCameraRoot = cameraToVisualMap[camera] {
            cameraViewEntryPos = activeCameraRoot.position(relativeTo: nil)
            cameraViewEntryCameraName = activeCameraRoot.name
        }
        hideAllMotionPaths()
        hideAllRotationArcs()
        showExitCameraButton()
        // Hide the camera panel and its pull tab when looking through a camera
        view.viewWithTag(8800)?.isHidden = true
        view.viewWithTag(8803)?.isHidden = true
        // Hide all toolbars and buttons
        navigationController?.setNavigationBarHidden(true, animated: true)
        view.viewWithTag(8804)?.isHidden = true // toolbar
        view.viewWithTag(8805)?.isHidden = true // viewModeControl
        view.viewWithTag(8806)?.isHidden = true // rotateBtn
        shotBreakdownBtn.isHidden = true
        sidebarView.isHidden = true
        layersButton.isHidden = true
        movementToggleButton.isHidden = true

        // ── Show camera view HUD overlay ──
        showCameraViewOverlay(camera: camera)
        enableCameraViewGestures(true)
    }

    /// Creates (or reuses) the camera-through HUD and configures it for the given camera.
    private func showCameraViewOverlay(camera: PerspectiveCamera) {
        // Ensure focus component exists on the camera root
        guard let camRoot = cameraToVisualMap[camera] else { return }
        if camRoot.components[CameraFocusComponent.self] == nil {
            // Initialize with default values; set focal length from current FOV
            var comp = CameraFocusComponent()
            comp.focalLengthMM = fovToFocalLength(camera.camera.fieldOfViewInDegrees)
            camRoot.components.set(comp)
        }

        let overlay = CameraViewOverlay(frame: view.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.configure(cameraRoot: camRoot, camera: camera)
        overlay.onSettingsChanged = { [weak self] in
            self?.startCameraPreviewUpdates()
        }
        overlay.onAFTap = { [weak self] point in
            self?.handleCameraViewAFTap(at: point)
        }
        // Insert above letterbox but below exit button
        if let exitBtn = view.viewWithTag(9001) {
            view.insertSubview(overlay, belowSubview: exitBtn)
        } else {
            view.addSubview(overlay)
        }
        cameraViewOverlay = overlay
    }

    // MARK: - Auto Focus Raycasting

    /// Called when the user taps the screen in AF mode while looking through a scene camera.
    func handleCameraViewAFTap(at screenPoint: CGPoint) {
        guard let arView = arView,
              activeCamera !== editorCamera,
              let camRoot = cameraToVisualMap[activeCamera] else { return }

        // Raycast from the tapped point
        // Using .all so we can hit any model in the scene
        let hits = arView.hitTest(screenPoint, query: .nearest, mask: .all)
        if let firstHit = hits.first {
            // Calculate distance from camera to hit point
            let camPos = activeCamera.position(relativeTo: nil)
            let distance = simd_distance(camPos, firstHit.position)

            // Update ECS Component
            var comp = camRoot.components[CameraFocusComponent.self] ?? CameraFocusComponent()
            comp.focusDistance = distance
            camRoot.components.set(comp)

            // Update UI Slider and labels
            cameraViewOverlay?.setFocusDistance(distance)
        }
    }

    // MARK: - Aspect Ratio Application

    private enum AspectRatioConstants {
        static let letterboxTag = 9100
        static let overlayOpacity: CGFloat = 1.0
    }

    /// Single entry point for applying an aspect ratio to a camera entity.
    /// Updates the ECS component, the SceneCameraItem record, and refreshes previews.
    func applyAspectRatio(
        _ ratio: CameraAspectRatio,
        to perspectiveCamera: PerspectiveCamera,
        cameraRoot: Entity
    ) {
        // 1. Update ECS component
        cameraRoot.components.set(CameraAspectComponent(aspectRatio: ratio))

        // 2. Update SceneCameraItem record
        if let idx = sceneCameraItems.firstIndex(where: { $0.camera === perspectiveCamera }) {
            sceneCameraItems[idx].aspectRatio = ratio
        }

        // 3. If this camera is currently active, update the viewport overlay
        if activeCamera === perspectiveCamera {
            updateLetterboxOverlay(for: ratio)
        }

        // 4. Trigger preview refresh
        cameraCollectionView?.reloadData()
        startCameraPreviewUpdates()
    }

    /// Adds or updates a semi-transparent letterbox/pillarbox overlay on arView
    /// so the user can see the framing for the active camera's aspect ratio.
    func updateLetterboxOverlay(for ratio: CameraAspectRatio) {
        // Remove any existing overlay
        view.viewWithTag(AspectRatioConstants.letterboxTag)?.removeFromSuperview()

        let viewSize = arView.bounds.size
        guard viewSize.width > 0, viewSize.height > 0 else { return }

        let viewRatio = Float(viewSize.width / viewSize.height)
        let targetRatio = ratio.ratio

        // If the ratios match closely, no overlay needed
        if abs(viewRatio - targetRatio) < 0.01 { return }

        let overlay = UIView()
        overlay.tag = AspectRatioConstants.letterboxTag
        overlay.isUserInteractionEnabled = false
        overlay.frame = arView.bounds
        view.insertSubview(overlay, aboveSubview: arView)

        if targetRatio < viewRatio {
            // Pillarbox: target is narrower — add dark bars on left and right
            let targetWidth = viewSize.height * CGFloat(targetRatio)
            let barWidth = (viewSize.width - targetWidth) / 2.0

            let leftBar = UIView(frame: CGRect(x: 0, y: 0, width: barWidth, height: viewSize.height))
            leftBar.backgroundColor = UIColor.black.withAlphaComponent(AspectRatioConstants.overlayOpacity)
            overlay.addSubview(leftBar)

            let rightBar = UIView(frame: CGRect(x: viewSize.width - barWidth, y: 0, width: barWidth, height: viewSize.height))
            rightBar.backgroundColor = UIColor.black.withAlphaComponent(AspectRatioConstants.overlayOpacity)
            overlay.addSubview(rightBar)
        } else {
            // Letterbox: target is wider — add dark bars on top and bottom
            let targetHeight = viewSize.width / CGFloat(targetRatio)
            let barHeight = (viewSize.height - targetHeight) / 2.0

            let topBar = UIView(frame: CGRect(x: 0, y: 0, width: viewSize.width, height: barHeight))
            topBar.backgroundColor = UIColor.black.withAlphaComponent(AspectRatioConstants.overlayOpacity)
            overlay.addSubview(topBar)

            let bottomBar = UIView(frame: CGRect(x: 0, y: viewSize.height - barHeight, width: viewSize.width, height: barHeight))
            bottomBar.backgroundColor = UIColor.black.withAlphaComponent(AspectRatioConstants.overlayOpacity)
            overlay.addSubview(bottomBar)
        }
    }

    /// Removes the letterbox overlay when exiting camera view.
    func removeLetterboxOverlay() {
        view.viewWithTag(AspectRatioConstants.letterboxTag)?.removeFromSuperview()
    }

    @objc func setTopView() {
        activateEditorCamera()
        yaw = 0
        pitch = 1.45
        distance = 6
        updateEditorCamera()
    }

    @objc func setFrontView() {
        activateEditorCamera()
        yaw = 0
        pitch = 0.3
        distance = 5
        updateEditorCamera()
    }

    // MARK: - Camera Preview (off-screen ARView, timer-driven)
    //
    // A dedicated off-screen ARView (`previewARView`) is created once and never added
    // to the view hierarchy, so the main viewport never flickers.
    //
    // A 3fps repeating Timer (`cameraPreviewTimer`) calls `updateAllCameraPreviews()`
    // which drives `snapshotPreviewCamera(at:)` — a serial chain that:
    //   1. Clones `mainAnchor` into the off-screen ARView.
    //   2. Disables all cameras in the clone; enables only the target camera by name.
    //   3. Snapshots the off-screen view.
    //   4. Stores the image in `sceneCameraItems[index].previewImage`, reloads the cell.
    //   5. Chains to the next index.
    //
    // The main `arView` and its active camera are NEVER touched — zero flicker.

    // MARK: Off-screen ARView (lazy, associated object so it can live on the extension)

    private enum PreviewARViewKey { static var key = "previewARView" }

    /// A dedicated off-screen ARView used exclusively for camera thumbnails.
    /// Never added to any view hierarchy; created once and reused.
    var previewARView: ARView {
        if let existing = objc_getAssociatedObject(self, &PreviewARViewKey.key) as? ARView {
            return existing
        }
        let av = ARView(frame: CGRect(x: 0, y: 0, width: 480, height: 270))
        av.cameraMode = .nonAR
        // Match the main arView's rendering settings so PBR materials are lit correctly
        // and the background matches (white, like the main scene).
        av.environment = arView.environment
        av.renderOptions = arView.renderOptions
        objc_setAssociatedObject(self, &PreviewARViewKey.key, av, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        gizmoRoot?.isEnabled = false
        return av
    }

    /// Resizes the off-screen preview ARView to match a specific aspect ratio
    /// so thumbnails render at the correct proportions.
    func resizePreviewARView(for ratio: CameraAspectRatio) {
        let size = ratio.snapshotSize
        previewARView.frame = CGRect(origin: .zero, size: size)
    }

    // MARK: Timer lifecycle

    func startCameraPreviewUpdates() {
        guard cameraPreviewTimer == nil else { return }
        cameraPreviewTimer = Timer.scheduledTimer(withTimeInterval: 0.33, repeats: true) { [weak self] _ in
            self?.updateAllCameraPreviews()
        }
    }

    func stopCameraPreviewUpdates() {
        cameraPreviewTimer?.invalidate()
        cameraPreviewTimer = nil
    }

    // MARK: Timer callback — kick off serial snapshot chain

     private func updateAllCameraPreviews() {
         guard !sceneCameraItems.isEmpty else { return }
         snapshotPreviewCamera(at: 0)
     }

    // MARK: Serial snapshot chain

     private func snapshotPreviewCamera(at index: Int) {
         guard index < sceneCameraItems.count else { return }
         guard let mainAnchor = arView.scene.findEntity(named: "MainAnchor") as? AnchorEntity else { return }

         let item = sceneCameraItems[index]
         // Capture the item ID so we can validate in the callback
         let itemID = item.id
         // Resize the off-screen ARView to match this camera's aspect ratio
         resizePreviewARView(for: item.aspectRatio)
         captureCameraPreviewImage(for: item) { [weak self] image in
             guard let self = self, let image = image else { return }
             // Guard: the camera might have been deleted while the capture was in-flight.
             // Re-lookup by ID instead of using the captured index.
             guard let currentIndex = self.sceneCameraItems.firstIndex(where: { $0.id == itemID }) else {
                 // Camera was deleted mid-capture — skip and continue the chain
                 self.snapshotPreviewCamera(at: index)
                 return
             }
             self.sceneCameraItems[currentIndex].previewImage = image
             let indexPath = IndexPath(item: currentIndex, section: 0)
             if let cell = self.cameraCollectionView?.cellForItem(at: indexPath) as? CameraPreviewCell {
                 cell.updatePreview(image: image, name: self.sceneCameraItems[currentIndex].displayName)
             }
             self.snapshotPreviewCamera(at: currentIndex + 1)
         }
     }

     func captureCameraPreviewImage(
         for item: SceneCameraItem,
         completion: @escaping (UIImage?) -> Void
     ) {
         guard let mainAnchor = arView.scene.findEntity(named: "MainAnchor") as? AnchorEntity else {
             completion(nil)
             return
         }

         let offscreen = previewARView

         // Remove only the previous preview clone (NOT removeAll which can silently
         // affect the live arView scene due to shared underlying RealityKit resources).
         if let old = offscreen.scene.anchors.first(where: { $0.name == "PreviewAnchor" }) {
             offscreen.scene.removeAnchor(old)
         }

         let clonedAnchor = mainAnchor.clone(recursive: true)
         clonedAnchor.name = "PreviewAnchor"
         offscreen.scene.addAnchor(clonedAnchor)

         // 2. Hide the TARGET camera visual (same as setActiveCamera behavior)
         if let targetCamRoot = clonedAnchor.findEntity(named: item.cameraRoot.name) as? Entity {
             targetCamRoot.children.forEach { child in
                 if !(child is PerspectiveCamera) { child.isEnabled = false }
             }
         }

         // 3. Hide all OTHER scene camera visuals
         clonedAnchor.forEachDescendant { entity in
             let cameraRootName = entity.name
             if cameraRootName.hasPrefix("SceneCameraRoot_"),
                cameraRootName != item.cameraRoot.name {
                 entity.children.forEach { child in
                     if !(child is PerspectiveCamera) { child.isEnabled = false }
                 }
             }
         }

         // 4. Hide editor overlays
         clonedAnchor.forEachDescendant { entity in
             if entity.name.hasPrefix("GizmoRoot") { entity.isEnabled = false }
             if entity.name.hasPrefix("PathRoot_") { entity.isEnabled = false }
             if entity.name.hasPrefix("RotationArc_") { entity.isEnabled = false }
         }

         // 5. Disable ALL cameras in the clone; enable only the target camera
         clonedAnchor.forEachDescendant { entity in
             if let cam = entity as? PerspectiveCamera { cam.isEnabled = false }
         }

         if let targetCam = clonedAnchor.findEntity(named: item.camera.name) as? PerspectiveCamera {
             targetCam.isEnabled = true
         } else {
             let fallback = PerspectiveCamera()
             let worldPos  = item.camera.position(relativeTo: nil)
             let worldOri  = item.camera.orientation(relativeTo: nil)
             fallback.position    = worldPos
             fallback.orientation = worldOri
             fallback.isEnabled   = true
             clonedAnchor.addChild(fallback)
         }

         offscreen.snapshot(saveToHDR: false) { image in
             DispatchQueue.main.async { completion(image) }
         }
     }

    // MARK: On-demand refresh (called after camera moved/rotated or newly spawned)
    //
    // The timer already handles continuous updates, so these just ensure the timer
    // is running. Individual-index refresh is a no-op since the timer covers all cameras.

    func capturePreview(forCameraAt index: Int) {
        startCameraPreviewUpdates()
    }

    func captureAllPreviews() {
        startCameraPreviewUpdates()
    }

    @objc func toggleCameraPanelTapped() {
        setCameraPanelExpanded(!isCameraPanelExpanded, animated: true)
    }

    // AFTER:
    func setCameraPanelExpanded(_ expanded: Bool, animated: Bool) {
        guard let panel = view.viewWithTag(8800) else { return }

        let panelWidth: CGFloat = 200
        // Slide the panel: trailing = -8 → fully visible; trailing = +panelWidth → off-screen right
        let targetTrailing: CGFloat = expanded ? -8 : panelWidth

        // Find the trailing constraint by identifier on the parent view
        for constraint in view.constraints where constraint.identifier == "panelTrailing" {
            constraint.constant = targetTrailing
        }

        // Update pull-tab chevron: right when expanded (panel visible, tap to collapse), left when collapsed (tap to expand)
        let pullTab = view.viewWithTag(8803) as? UIButton
        let tabCfg = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        pullTab?.setImage(
            UIImage(systemName: expanded ? "chevron.right" : "chevron.left", withConfiguration: tabCfg),
            for: .normal
        )

        let collectionView = panel.viewWithTag(8802)

        let block = {
            collectionView?.alpha = expanded ? 1.0 : 0.0
            pullTab?.alpha = 1.0  // always visible once a camera exists
            self.view.layoutIfNeeded()
        }

        if animated {
            UIView.animate(withDuration: 0.3, delay: 0,
                           usingSpringWithDamping: 0.85,
                           initialSpringVelocity: 0.3,
                           options: .curveEaseInOut,
                           animations: block)
        } else {
            block()
        }

        isCameraPanelExpanded = expanded
    }
    // MARK: - Exit Camera Button

    func showExitCameraButton() {
        if view.viewWithTag(9001) != nil { return }

        // Container — 44×44 to match the play button size
        let container = UIView()
        container.tag = 9001
        container.translatesAutoresizingMaskIntoConstraints = false
        container.clipsToBounds = true
        container.layer.cornerRadius = 22

        // Frosted glass background
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blur.translatesAutoresizingMaskIntoConstraints = false
        blur.isUserInteractionEnabled = false
        container.addSubview(blur)

        // Subtle border
        container.layer.borderWidth = 0.5
        container.layer.borderColor = UIColor(white: 1, alpha: 0.15).cgColor

        // Chevron-left icon — native iOS back button style
        let btn = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        btn.setImage(UIImage(systemName: "chevron.left", withConfiguration: cfg), for: .normal)
        btn.tintColor = .white
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(exitCameraViewTapped), for: .touchUpInside)
        container.addSubview(btn)

        view.addSubview(container)
        NSLayoutConstraint.activate([
            // Top-left, aligned with the layers button row
            container.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            container.widthAnchor.constraint(equalToConstant: 44),
            container.heightAnchor.constraint(equalToConstant: 44),

            blur.topAnchor.constraint(equalTo: container.topAnchor),
            blur.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            blur.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            btn.topAnchor.constraint(equalTo: container.topAnchor),
            btn.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            btn.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            btn.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }

    func hideExitCameraButton() {
        view.viewWithTag(9001)?.removeFromSuperview()
    }

    @objc private func exitCameraViewTapped() {
        // Find which camera was active so we can refresh its thumbnail after exiting.
        let activeIndex = sceneCameraItems.firstIndex { $0.camera === activeCamera }

        activateEditorCamera()
        removeLetterboxOverlay()
        cameraCollectionView?.reloadData()

        // Update the thumbnail for the camera the user just exited — it may have
        // been moved while the user was looking through it.
        if let idx = activeIndex {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.capturePreview(forCameraAt: idx)
            }
        }
    }

    // MARK: - Collection View (Camera Panel)

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        sceneCameraItems.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: CameraPreviewCell.reuseID,
            for: indexPath
        ) as? CameraPreviewCell else {
            return UICollectionViewCell()
        }
        let item = sceneCameraItems[indexPath.item]
        let name = item.displayName
        if let img = item.previewImage {
            cell.updatePreview(image: img, name: name)
        } else {
            cell.label.text = name
        }

        // Apply aspect ratio bars over the thumbnail
        cell.updateAspectRatio(item.aspectRatio)

        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        let item = sceneCameraItems[indexPath.item]
        setActiveCamera(item.camera)
    }

    // MARK: - Motion Path Sync (On Exit Camera View)

    /// Called when exiting camera view. Computes the total movement delta while in camera view
    /// and applies it to all animation clips (start, c1, c2, end) belonging to this camera.
    func syncCameraClipsAfterCameraView() {
        guard let oldPos = cameraViewEntryPos,
              let cameraName = cameraViewEntryCameraName,
              let cameraEntity = mainAnchor?.findEntity(named: cameraName) else {
            return
        }

        let newPos = cameraEntity.position(relativeTo: nil)
        let delta = newPos - oldPos

        guard simd_length(delta) > 0.0001 else { return }

        // Update ALL clip points by the same delta — whole path moves together
        for i in 0..<timeline.clips.count {
            let clip = timeline.clips[i]
            guard clip.entityName == cameraName,
                  clip.track == .position else { continue }

            let newFrom = clip.fromValue + delta
            let newTo   = clip.toValue + delta

            var updatedPath: BezierMotionPath?
            if var path = clip.motionPath {
                path.start    += delta
                path.control1 += delta
                path.control2 += delta
                path.end      += delta
                updatedPath = path
            }

            timeline.clips[i] = AnimationClip(
                preservingID: clip,
                fromValue: newFrom,
                toValue: newTo,
                motionPath: updatedPath
            )

            // Rebuild the visual path line so it shows up in the new position
            showMotionPath(for: timeline.clips[i])
        }

        // Update baseTransform so playback starts from the new position
        baseTransforms[cameraName] = cameraEntity.transform

        // Clear the stored entry state
        cameraViewEntryPos = nil
        cameraViewEntryCameraName = nil
    }

}
