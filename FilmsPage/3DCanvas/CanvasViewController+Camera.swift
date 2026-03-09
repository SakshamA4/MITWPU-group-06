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
        guard let anchor = arView.scene.findEntity(named: "MainAnchor") else { return }
        
        let index = sceneCameras.count
        let cameraRoot = Entity()
        cameraRoot.name = "SceneCameraRoot_\(index)"
        cameraRoot.components.set(CategoryComponent(toolType: .camera))
        
        let visual = makeCameraVisual()
        visual.generateCollisionShapes(recursive: true)
        visual.components.set(InputTargetComponent())
        
        let camera = PerspectiveCamera()
        camera.name = "SceneCamera_\(index)"
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
        startCameraPreviewUpdates()
    }

    
    /// Call this whenever a camera's cameraRoot entity is deleted from the scene.
    /// Cleans up sceneCameras, sceneCameraItems, cameraToVisualMap, and refreshes the collection view.
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

        // Stop the timer if no cameras remain
        if sceneCameraItems.isEmpty {
            stopCameraPreviewUpdates()
        }
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

        // 1. Clone the live main scene into the off-screen ARView
        offscreen.scene.anchors.removeAll()
        guard let mainAnchor = arView.scene.findEntity(named: "MainAnchor") as? AnchorEntity else { return }
        let clonedAnchor = mainAnchor.clone(recursive: true)
        offscreen.scene.addAnchor(clonedAnchor)

        // 2. Disable all cameras in clone, then enable only the target one
        clonedAnchor.forEachDescendant { entity in
            if let cam = entity as? PerspectiveCamera { cam.isEnabled = false }
        }

        if let targetCam = clonedAnchor.findEntity(named: item.camera.name) as? PerspectiveCamera {
            targetCam.isEnabled = true
        } else {
            // Fallback: attach a camera at the same world transform
            let fallback = PerspectiveCamera()
            fallback.transform = item.camera.transform
            fallback.isEnabled = true
            clonedAnchor.addChild(fallback)
        }

        // 3. Snapshot the off-screen view — main arView is completely untouched
        offscreen.snapshot(saveToHDR: false) { [weak self] image in
            guard let self = self, let image = image else { return }
            DispatchQueue.main.async {
                if let cell = self.cameraCollectionView?.cellForItem(at: indexPath) as? CameraPreviewCell {
                    cell.updatePreview(image: image, name: "Camera \(index + 1)")
                }
                // Chain to next camera
                self.snapshotPreviewCamera(at: index + 1)
            }
        }
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
