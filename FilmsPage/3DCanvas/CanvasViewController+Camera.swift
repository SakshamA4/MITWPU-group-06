import PhotosUI
import RealityKit
import UIKit
import ARKit
import Combine

extension CanvasViewController {

    func handleCameraOrbit(_ gesture: UIPanGestureRecognizer) {
        // In AR mode the real device camera moves — no editor orbit needed
        if isARModeActive { return }
        if selectedEntity != nil { return }
        let translation = gesture.translation(in: arView)
        
        yaw -= Float(translation.x) * 0.005
        pitch += Float(translation.y) * 0.005
        pitch = max(-1.0, min(1.4, pitch))
        
        updateEditorCamera()
        gesture.setTranslation(.zero, in: arView)
    }

    
    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .began {
            saveCurrentStateToUndo()
        }
        guard editorMode == .edit else { return }
        
        guard let entity = selectedEntity else {
            guard !isARModeActive else {
                gesture.scale = 1.0
                return
            }
            distance /= Float(gesture.scale)
            distance = max(1.5, min(15, distance))
            updateEditorCamera()
            gesture.scale = 1.0
            return
        }
        
        let isLocked = entity.components[LockComponent.self]?.isLocked ?? false
        if isLocked { return }
        
        guard let modelEntity = entity as? ModelEntity else {
            gesture.scale = 1.0
            return
        }
        
        switch gesture.state {
        case .changed:
            let scaleFactor = Float(gesture.scale)
            
            if var wall = modelEntity.components[WallComponent.self] {
                wall.width *= scaleFactor
                wall.height *= scaleFactor
                wall.width = max(0.3, min(wall.width, 10))
                wall.height = max(0.3, min(wall.height, 6))
                let newMesh = MeshResource.generateBox(
                    width: wall.width,
                    height: wall.height,
                    depth: 0.05
                )
                modelEntity.model?.mesh = newMesh
                // generateCollisionShapes removed from .changed — it is called once in
                // .ended below. Calling it every pinch frame was a major perf regression.
                modelEntity.components.set(wall)
            }
            
            if var bg = modelEntity.components[BackgroundComponent.self] {
                bg.width *= scaleFactor
                bg.height *= scaleFactor
                bg.width = max(0.5, min(bg.width, 15))
                bg.height = max(0.5, min(bg.height, 10))
                modelEntity.model?.mesh = MeshResource.generateBox(
                    width: bg.width,
                    height: bg.height,
                    depth: 0.05
                )
                // Deferred to .ended (see above)
                modelEntity.components.set(bg)
            }
            
            if var ground = modelEntity.components[GroundComponent.self] {
                ground.width *= scaleFactor
                ground.depth *= scaleFactor
                ground.width = max(0.5, min(ground.width, 20))
                ground.depth = max(0.5, min(ground.depth, 20))
                let newMesh = MeshResource.generatePlane(
                    width: ground.width,
                    depth: ground.depth
                )
                modelEntity.model?.mesh = newMesh
                // Deferred to .ended (see above)
                modelEntity.components.set(ground)
            }
            gesture.scale = 1.0

        case .ended, .cancelled:
            // Rebuild collision shapes once — mesh is at its final size.
            modelEntity.generateCollisionShapes(recursive: true)

        default:
            break
        }
    }

    
    func updateEditorCamera() {
        guard let camera = editorCamera else { return }
        let x = distance * cos(pitch) * sin(yaw)
        let y = distance * sin(pitch)
        let z = distance * cos(pitch) * cos(yaw)
        
        // Apply position relative to the orbit pivot (cameraTarget)
        camera.position = [x, y, z] + cameraTarget
        
        // Always look at the current pivot point
        camera.look(at: cameraTarget, from: camera.position, relativeTo: nil)
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

        // Camera right vector derived from yaw only — no pitch component —
        // so horizontal panning stays level and doesn't drift up/down.
        let cameraRight = SIMD3<Float>(
             cos(yaw),   // x
             0,          // y — intentionally zero to keep right vector horizontal
            -sin(yaw)    // z
        )

        // World up is always +Y: vertical panning moves the pivot up/down.
        let worldUp = SIMD3<Float>(0, 1, 0)

        // Scale panning speed with current zoom distance so it feels consistent
        // whether the user is zoomed in tight or pulled back far.
        let scale: Float = distance * 0.0015

        // Screen +X → world right;  screen +Y → world down (invert Y for UIKit coords)
        cameraTarget += cameraRight  *  Float(translation.x) * scale
        cameraTarget += worldUp      * -Float(translation.y) * scale

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

    
     func spawnSceneCamera() {
         // FIX: use cached mainAnchor — not an O(n) scene DFS
         guard let anchor = mainAnchor else { return }
         
         // Increment counter first so the first camera is "Camera 1"
         cameraCounter += 1
         let cameraNumber = cameraCounter
         let cameraID = UUID()  // Unique backend identifier
         let cameraRoot = Entity()
         // Format: "SceneCamera_<counter>_<UUID>"
         cameraRoot.name = "SceneCamera_\(cameraNumber)_\(cameraID.uuidString)"
         cameraRoot.components.set(CategoryComponent(toolType: .camera))
         cameraRoot.components.set(EntityIDComponent(id: cameraID))
         
         let visual = makeCameraVisual()
         visual.generateCollisionShapes(recursive: true)
         visual.components.set(InputTargetComponent())
         
         let camera = PerspectiveCamera()
         camera.name = "PerspCam_\(cameraID.uuidString)"
         camera.isEnabled = false
         
         cameraRoot.addChild(visual)
         cameraRoot.addChild(camera)
         
         // Spawn at a random XZ position so multiple cameras don't overlap
         let randomX = Float.random(in: -2...2)
         let randomZ = Float.random(in: -2...2)
         cameraRoot.position = [randomX, 1, randomZ]
         anchor.addChild(cameraRoot)
         
         sceneCameras.append(camera)
         cameraToVisualMap[camera] = cameraRoot
         sceneCameraItems.append(SceneCameraItem(
             id: cameraID,
             camera: camera,
             cameraRoot: cameraRoot,
             displayName: "Camera \(cameraNumber)"
         ))
         
         cameraCollectionView?.reloadData()
         // Capture an initial thumbnail for this camera after a short delay so
         // RealityKit has time to render the camera entity into the scene first.
         let newIndex = sceneCameraItems.count - 1
         DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
             self?.capturePreview(forCameraAt: newIndex)
         }
         setCameraPanelExpanded(true, animated: true)
         setupCameraPanelSwipeGestures()
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

        // Animate the cell out and reload
        let indexPath = IndexPath(item: index, section: 0)
        if cameraCollectionView?.numberOfItems(inSection: 0) ?? 0 > index {
            cameraCollectionView?.performBatchUpdates({
                cameraCollectionView?.deleteItems(at: [indexPath])
            }, completion: nil)
        } else {
            cameraCollectionView?.reloadData()
        }

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
        showAllMotionPaths()
        hideExitCameraButton()
    }

    
    func setActiveCamera(_ camera: PerspectiveCamera) {
        for cam in sceneCameras { cam.isEnabled = false }
        editorCamera.isEnabled = false
        camera.isEnabled = true
        activeCamera = camera
        hideAllMotionPaths()
        showExitCameraButton()
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
        let av = ARView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        av.cameraMode = .nonAR
        // Match the main arView's rendering settings so PBR materials are lit correctly
        // and the background matches (white, like the main scene).
        av.environment = arView.environment
        av.renderOptions = arView.renderOptions
        objc_setAssociatedObject(self, &PreviewARViewKey.key, av, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return av
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
        guard let anchor = mainAnchor else { return }

        let item = sceneCameraItems[index]
        let targetCameraName = item.camera.name   // e.g. "PerspCam_<UUID>"

        let pv = previewARView

        // Remove any previous anchor from the off-screen scene so we start clean.
        for existing in pv.scene.anchors { pv.scene.removeAnchor(existing) }

        // Clone the full scene anchor into the off-screen ARView.
        let clonedAnchor = anchor.clone(recursive: true)
        pv.scene.addAnchor(clonedAnchor)

        // Walk the clone: disable all PerspectiveCameras, then enable the target one.
        var found = false
        func configureCameras(in entity: Entity) {
            if let cam = entity as? PerspectiveCamera {
                cam.isEnabled = (entity.name == targetCameraName)
                if cam.isEnabled { found = true }
            }
            for child in entity.children { configureCameras(in: child) }
        }
        configureCameras(in: clonedAnchor)

        guard found else {
            // Camera not found in clone — skip to next index.
            snapshotPreviewCamera(at: index + 1)
            return
        }

        // Wait for one RealityKit render frame before snapshotting.
        // Without this delay the off-screen ARView hasn't rendered any pixels yet
        // and snapshot() returns a black image.
        var token: AnyCancellable?
        token = pv.scene.publisher(for: SceneEvents.Update.self)
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                token = nil   // release the subscription
                guard let self = self else { return }
                pv.snapshot(saveToHDR: false) { [weak self] image in
                    guard let self = self else { return }

                    if let image = image, index < self.sceneCameraItems.count {
                        self.sceneCameraItems[index].previewImage = image
                        // Update the visible cell directly — never call reloadItems here.
                        // reloadItems triggers prepareForReuse which sets image = nil,
                        // causing the cell to flash black on every timer tick.
                        let ip = IndexPath(item: index, section: 0)
                        let name = self.sceneCameraItems[index].displayName
                        if let cell = self.cameraCollectionView?.cellForItem(at: ip) as? CameraPreviewCell {
                            cell.updatePreview(image: image, name: name)
                        }
                    }

                    // Chain to the next camera after a small yield so the run loop can breathe.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                        self?.snapshotPreviewCamera(at: index + 1)
                    }
                }
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
        for constraint in view.constraints {
            if constraint.identifier == "panelTrailing" {
                constraint.constant = targetTrailing
            }
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

        let btn = UIButton(type: .system)
        btn.tag = 9001
        btn.setTitle("Exit Camera", for: .normal)
        btn.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        btn.tintColor = .white
        btn.backgroundColor = UIColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 0.92)
        btn.layer.cornerRadius = 18
        btn.clipsToBounds = true
        btn.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(exitCameraViewTapped), for: .touchUpInside)

        view.addSubview(btn)
        NSLayoutConstraint.activate([
            btn.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            btn.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            btn.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    func hideExitCameraButton() {
        view.viewWithTag(9001)?.removeFromSuperview()
    }

    @objc private func exitCameraViewTapped() {
        // Find which camera was active so we can refresh its thumbnail after exiting.
        let activeIndex = sceneCameraItems.firstIndex { $0.camera === activeCamera }

        activateEditorCamera()
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
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        let item = sceneCameraItems[indexPath.item]
        setActiveCamera(item.camera)
    }

}
