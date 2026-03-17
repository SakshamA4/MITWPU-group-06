import Combine
import PhotosUI
import RealityKit
import UIKit
import ARKit

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
        
        let index = sceneCameras.count
        let cameraRoot = Entity()
        // FIX: unique name uses UUID so reopening never collides
        cameraRoot.name = "SceneCamera_\(UUID().uuidString)"
        cameraRoot.components.set(CategoryComponent(toolType: .camera))
        cameraRoot.components.set(EntityIDComponent(id: UUID()))
        
        let visual = makeCameraVisual()
        visual.generateCollisionShapes(recursive: true)
        visual.components.set(InputTargetComponent())
        
        let camera = PerspectiveCamera()
        camera.name = "PerspCam_\(UUID().uuidString)"
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
        sceneCameraItems.append(SceneCameraItem(camera: camera, cameraRoot: cameraRoot))
        
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


    // MARK: - Camera Preview (on-demand, no timer)
    //
    // Previews are stale thumbnails stored in SceneCameraItem.previewImage.
    // A capture is triggered only at specific moments (camera spawn, exit camera view)
    // so there is NO repeating timer and the editor camera is NEVER disabled except
    // for the single frame during the actual snapshot.
    //
    // Capture flow:
    //   1. Remember the currently active camera.
    //   2. Enable the target scene camera; disable everything else.
    //   3. Call arView.snapshot() — captures the *next rendered frame*.
    //   4. In the snapshot callback, immediately restore the previous camera state.
    //   5. Store the image in sceneCameraItems[index].previewImage and reload the cell.
    //
    // Because the restore happens inside the snapshot callback (which fires on the main
    // thread after the frame is written to the framebuffer), the live viewport is
    // affected for exactly one frame — not perceptibly visible to the user.

    /// Capture a one-shot preview for the camera at `index` and store it in sceneCameraItems.
    /// Safe to call at any time; does nothing if index is out of range or a capture is already running.
    func capturePreview(forCameraAt index: Int) {
        guard index < sceneCameraItems.count else { return }

        // Global guard: only one capture in flight at a time across all cameras.
        guard !isCapturingPreview else { return }

        let item = sceneCameraItems[index]
        guard !item.isCapturing else { return }

        isCapturingPreview = true
        sceneCameraItems[index].isCapturing = true

        // Save which camera was active before we touch anything.
        let previousCamera = activeCamera
        let wasEditorCamera = (previousCamera === editorCamera)

        // Hide the live viewport so the single-frame camera swap is invisible to the user.
        arView.alpha = 0

        // Activate the target camera.
        for cam in sceneCameras { cam.isEnabled = false }
        editorCamera?.isEnabled = false
        item.camera.isEnabled = true

        // Wait for RealityKit to render exactly ONE frame with the new camera active,
        // then snapshot. Without this the snapshot captures the previous frame (old POV).
        var token: AnyCancellable?
        token = arView.scene.publisher(for: SceneEvents.Update.self)
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                token?.cancel()
                token = nil

                self.arView.snapshot(saveToHDR: false) { [weak self] image in
                    guard let self = self else { return }

                    // Restore previous camera state.
                    for cam in self.sceneCameras { cam.isEnabled = false }
                    self.editorCamera?.isEnabled = false
                    if wasEditorCamera {
                        self.editorCamera?.isEnabled = true
                        self.activeCamera = self.editorCamera
                        // Snap editor camera back to its correct orbit position so
                        // RealityKit doesn't interpolate from a stale transform.
                        self.updateEditorCamera()
                    } else if let prev = previousCamera as? PerspectiveCamera,
                              prev !== self.editorCamera {
                        prev.isEnabled = true
                        self.activeCamera = prev
                    } else {
                        self.editorCamera?.isEnabled = true
                        self.activeCamera = self.editorCamera
                        self.updateEditorCamera()
                    }

                    // Fade the viewport back in.
                    UIView.animate(withDuration: 0.15) { self.arView.alpha = 1 }

                    // Store result and refresh the cell.
                    guard index < self.sceneCameraItems.count else {
                        self.isCapturingPreview = false
                        return
                    }
                    self.sceneCameraItems[index].isCapturing = false
                    self.isCapturingPreview = false
                    if let image = image {
                        self.sceneCameraItems[index].previewImage = image
                        let ip = IndexPath(item: index, section: 0)
                        self.cameraCollectionView?.reloadItems(at: [ip])
                    }
                }
            }
        if let t = token { previewCancellables.insert(t) }
    }

    /// Capture preview thumbnails for every scene camera, serially.
    /// Called once after a scene is loaded so all cells get an initial thumbnail.
    func captureAllPreviews() {
        capturePreviewSerially(at: 0)
    }

    private func capturePreviewSerially(at index: Int) {
        guard index < sceneCameraItems.count else {
            // Serial chain complete — restore viewport and clear flag.
            UIView.animate(withDuration: 0.15) { self.arView.alpha = 1 }
            isCapturingPreview = false
            return
        }
        let item = sceneCameraItems[index]
        guard !item.isCapturing else {
            capturePreviewSerially(at: index + 1)
            return
        }
        sceneCameraItems[index].isCapturing = true
        isCapturingPreview = true

        let previousCamera = activeCamera
        let wasEditorCamera = (previousCamera === editorCamera)

        // Hide the live viewport so the single-frame camera swap is invisible to the user.
        arView.alpha = 0

        for cam in sceneCameras { cam.isEnabled = false }
        editorCamera?.isEnabled = false
        item.camera.isEnabled = true

        // Wait for RealityKit to render ONE frame with the new camera before snapshotting.
        var token: AnyCancellable?
        token = arView.scene.publisher(for: SceneEvents.Update.self)
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                token?.cancel()
                token = nil

                self.arView.snapshot(saveToHDR: false) { [weak self] image in
                    guard let self = self else { return }

                    // Restore previous camera state.
                    for cam in self.sceneCameras { cam.isEnabled = false }
                    self.editorCamera?.isEnabled = false
                    if wasEditorCamera {
                        self.editorCamera?.isEnabled = true
                        self.activeCamera = self.editorCamera
                        self.updateEditorCamera()
                    } else if let prev = previousCamera as? PerspectiveCamera,
                              prev !== self.editorCamera {
                        prev.isEnabled = true
                        self.activeCamera = prev
                    } else {
                        self.editorCamera?.isEnabled = true
                        self.activeCamera = self.editorCamera
                        self.updateEditorCamera()
                    }

                    if index < self.sceneCameraItems.count {
                        self.sceneCameraItems[index].isCapturing = false
                        if let image = image {
                            self.sceneCameraItems[index].previewImage = image
                            let ip = IndexPath(item: index, section: 0)
                            self.cameraCollectionView?.reloadItems(at: [ip])
                        }
                    }

                    // Chain to next camera after a short delay.
                    self.isCapturingPreview = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                        self?.capturePreviewSerially(at: index + 1)
                    }
                }
            }
        if let t = token { previewCancellables.insert(t) }
    }

    // Kept as no-ops for any call sites that still reference the old timer API.
    func startCameraPreviewUpdates() {}
    func stopCameraPreviewUpdates() {}

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
        let name = "Camera \(indexPath.item + 1)"
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


