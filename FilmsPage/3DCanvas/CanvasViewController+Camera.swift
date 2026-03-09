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
            // In AR mode the real camera handles zoom — don't shift editor distance
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
                // 1. Update the component values
                bg.width *= scaleFactor
                bg.height *= scaleFactor
                
                // 2. Clamp values so it doesn't disappear or get too huge
                bg.width = max(0.5, min(bg.width, 15))
                bg.height = max(0.5, min(bg.height, 10))
                
                // 3. REGENERATE THE MESH (The most important step)
                // This builds a new box with a thickness of 0.05
                modelEntity.model?.mesh = MeshResource.generateBox(
                    width: bg.width,
                    height: bg.height,
                    depth: 0.05
                )
                
                // 4. REFRESH COLLISION
                // This ensures you can still grab the background after it grows
                modelEntity.generateCollisionShapes(recursive: true)
                
                // 5. Save the updated component back to the entity
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
        
        // Convert yaw, pitch, and distance into X, Y, Z coordinates
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
        guard let anchor = arView.scene.findEntity(named: "MainAnchor") else {
            return
        }
        
        let cameraRoot = Entity()
        cameraRoot.name = "SceneCamera_\(sceneCameras.count)"
        
        cameraRoot.components.set(
            CategoryComponent(toolType: .camera)
        )
        
        // Camera visual
        let visual = makeCameraVisual()
        visual.generateCollisionShapes(recursive: true)
        visual.components.set(InputTargetComponent())
        
        // Perspective camera
        let camera = PerspectiveCamera()
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
        
        sceneCameraItems.append(
            SceneCameraItem(camera: camera, cameraRoot: cameraRoot)
        )
        
        cameraCollectionView?.reloadData()
        
    }

    
    func activateEditorCamera() {
        for cam in sceneCameras {
            cam.isEnabled = false
        }
        
        editorCamera.isEnabled = true
        activeCamera = editorCamera
        showAllMotionPaths()
    }

    
    func setActiveCamera(_ camera: PerspectiveCamera) {
        for cam in sceneCameras {
            cam.isEnabled = false
        }
        
        editorCamera.isEnabled = false
        camera.isEnabled = true
        activeCamera = camera
        hideAllMotionPaths()
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


    func setupCameraPreview(
        arView: ARView,
        cameraItem: SceneCameraItem
    ) {

        arView.scene.anchors.removeAll()

        let previewAnchor = AnchorEntity(world: .zero)

        if let mainAnchor = arView.scene.findEntity(named: "MainAnchor") {
            let clone = mainAnchor.clone(recursive: true)
            previewAnchor.addChild(clone)
        }

        let previewCamera = PerspectiveCamera()
        previewCamera.transform = cameraItem.camera.transform
        previewCamera.isEnabled = true

        previewAnchor.addChild(previewCamera)
        arView.scene.addAnchor(previewAnchor)
    }



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

        let cameraItem = sceneCameraItems[indexPath.item]

        guard
            let mainAnchor =
                arView.scene.findEntity(named: "MainAnchor") as? AnchorEntity
        else { return cell }

        cell.configure(
            sourceAnchor: mainAnchor,
            sourceCamera: cameraItem.camera,
            name: "Camera \(indexPath.item + 1)"
        )

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
