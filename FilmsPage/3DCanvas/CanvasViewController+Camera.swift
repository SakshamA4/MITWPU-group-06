import Combine
import PhotosUI
import RealityKit
import UIKit
import ARKit

extension CanvasViewController {

    func handleCameraOrbit(_ gesture: UIPanGestureRecognizer) {
        // In AR mode the real device camera moves — no editor orbit needed
        if isARModeActive { return }
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
                modelEntity.generateCollisionShapes(recursive: true)
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
                modelEntity.generateCollisionShapes(recursive: true)
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
                modelEntity.generateCollisionShapes(recursive: true)
                modelEntity.components.set(ground)
            }
            gesture.scale = 1.0
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
        guard let anchor = arView.scene.findEntity(named: "MainAnchor") else { return }

        let index = sceneCameras.count
        let cameraRoot = Entity()
        cameraRoot.name = "SceneCameraRoot_\(index)"
        cameraRoot.components.set(CategoryComponent(toolType: .camera))

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
        sceneCameraItems.append(SceneCameraItem(camera: camera, cameraRoot: cameraRoot))

        cameraCollectionView?.reloadData()
        startCameraPreviewUpdates()
        setCameraPanelExpanded(true, animated: true)
        setupCameraPanelSwipeGestures()

        // Load the cam1 model asset asynchronously.
        // Falls back to the procedural mesh visual if the asset is not found.
        Task { @MainActor in
            do {
                let model = try await Entity(named: "cam1")

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
            } catch {
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

        // Animate the cell out and reload
        let indexPath = IndexPath(item: index, section: 0)
        cameraCollectionView?.performBatchUpdates({
            cameraCollectionView?.deleteItems(at: [indexPath])
        }, completion: nil)

        if sceneCameraItems.isEmpty {
            stopCameraPreviewUpdates()
            setCameraPanelExpanded(false, animated: true)  // ← add this
        }
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
        showAllMotionPaths()
        showAllRotationArcs()
        hideExitCameraButton()
        // Restore gizmos in editor view
        gizmoRoot?.isEnabled = true
        rotationGizmo?.isEnabled = true
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
        }
        // Hide gizmos and all editor overlays — they obstruct the camera preview
        gizmoRoot?.isEnabled = false
        rotationGizmo?.isEnabled = false
        hideAllMotionPaths()
        hideAllRotationArcs()
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


    // MARK: - Live Camera Preview
    // Uses a dedicated off-screen ARView that is NEVER added to the view hierarchy.
    // The main arView's camera is never switched — zero flicker.

    /// A single hidden ARView used only for rendering preview snapshots.
    var previewARView: ARView {
        if let existing = objc_getAssociatedObject(self, &PreviewARViewKey.key) as? ARView {
            return existing
        }
        let offscreen = ARView(frame: CGRect(x: 0, y: 0, width: 200, height: 150))
        offscreen.automaticallyConfigureSession = false
        offscreen.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disableHDR]
        offscreen.environment.background = .color(.white)
        offscreen.cameraMode = .nonAR
        // Never added to any view hierarchy — purely off-screen
        objc_setAssociatedObject(self, &PreviewARViewKey.key, offscreen, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return offscreen
    }

    func startCameraPreviewUpdates() {
        stopCameraPreviewUpdates()
        // 3fps thumbnail refresh — lightweight, still feels live
        cameraPreviewTimer = Timer.scheduledTimer(withTimeInterval: 0.33, repeats: true) { [weak self] _ in
            self?.updateAllCameraPreviews()
        }
    }

    func stopCameraPreviewUpdates() {
        cameraPreviewTimer?.invalidate()
        cameraPreviewTimer = nil
    }

    private func updateAllCameraPreviews() {
        guard !sceneCameraItems.isEmpty else { return }
        snapshotPreviewCamera(at: 0)
    }

    /// Processes each scene camera serially to avoid overlapping snapshot calls.
    private func snapshotPreviewCamera(at index: Int) {
        guard index < sceneCameraItems.count else { return }

        let item = sceneCameraItems[index]
        let indexPath = IndexPath(item: index, section: 0)
        let offscreen = previewARView

        // 1. Build a minimal preview scene — only non-camera entities + a camera.
        //    We deliberately do NOT clone the full scene because USDZ camera
        //    visuals (cam1) contain geometry that triggers Metal validation errors
        //    in the off-screen ARView's renderer.
        offscreen.scene.anchors.removeAll()

        let previewAnchor = AnchorEntity(world: .zero)
        previewAnchor.name = "PreviewAnchor"

        // Copy only renderable scene entities — exclude everything that is
        // editor UI (cameras, gizmos, motion paths, rotation arcs, grid)
        if let mainAnchor = arView.scene.findEntity(named: "MainAnchor") as? AnchorEntity {
            for child in mainAnchor.children {
                guard child.components[CategoryComponent.self]?.toolType != .camera,
                      !child.name.hasPrefix("SceneCameraRoot_"),
                      !child.name.hasPrefix("GizmoRoot"),
                      !child.name.hasPrefix("PathRoot_"),
                      !child.name.hasPrefix("RotationArc_"),
                      child.name != "Grid",
                      child.name != "EditorCamera" else { continue }
                previewAnchor.addChild(child.clone(recursive: true))
            }
        }

        // 2. Add a camera positioned at the exact world transform of the scene camera
        let previewCam = PerspectiveCamera()
        previewCam.transform = item.camera.transform
        // If camera is nested under cameraRoot, compute world-space transform
        if let parent = item.camera.parent {
            let worldPos  = item.camera.position(relativeTo: nil)
            let worldOri  = item.camera.orientation(relativeTo: nil)
            previewCam.position    = worldPos
            previewCam.orientation = worldOri
        }
        previewCam.isEnabled = true
        previewAnchor.addChild(previewCam)

        offscreen.scene.addAnchor(previewAnchor)

        // 3. Snapshot
        offscreen.snapshot(saveToHDR: false) { [weak self] image in
            guard let self = self, let image = image else { return }
            DispatchQueue.main.async {
                if let cell = self.cameraCollectionView?.cellForItem(at: indexPath) as? CameraPreviewCell {
                    cell.updatePreview(image: image, name: "Camera \(index + 1)")
                }
                self.snapshotPreviewCamera(at: index + 1)
            }
        }
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
        activateEditorCamera()
        cameraCollectionView?.reloadData()
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
        cell.label.text = "Camera \(indexPath.item + 1)"
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



// MARK: - Storage key for the off-screen preview ARView
private enum PreviewARViewKey {
    static var key = "previewARView"
}
