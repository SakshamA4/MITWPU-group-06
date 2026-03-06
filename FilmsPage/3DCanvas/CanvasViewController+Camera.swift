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
        
        // Apply position relative to the center (cameraTarget)
        camera.position = [x, y, z] + cameraTarget
        
        // Look at the center of the grid
        camera.look(at: cameraTarget, from: camera.position, relativeTo: nil)
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
        
        cameraRoot.position = [0, 1, -1.0]
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
