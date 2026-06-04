import Combine
import PhotosUI
import RealityKit
import UIKit
import ARKit

extension CanvasViewController {

    @objc func deleteSelected() {

        // ───────────────────────────────
        // 1️⃣ DELETE MOTION PATH ONLY
        // ───────────────────────────────
        if let clipID = selectedPathClipID {

            guard
                let clipIndex = timeline.clips.firstIndex(
                    where: { $0.id == clipID }
                )
            else {
                selectedPathClipID = nil
                return
            }

            // Remove path visuals (start handle is parented to entity, remove it too)
            if let visual = activeMotionPaths[clipID] {
                visual.startHandle?.removeFromParent()
                visual.root.removeFromParent()
            }
            activeMotionPaths.removeValue(forKey: clipID)

            // Remove rotation arc if this was a rotation clip
            hideRotationArc(for: clipID)

            // Remove ONLY this clip
            timeline.clips.remove(at: clipIndex)

            // Clear selection
            selectedPathClipID = nil

            // ❗ IMPORTANT
            // DO NOT:
            // - evaluate timeline
            // - touch entity transform
            // - touch baseTransforms
            // The entity must stay exactly where it is

            refreshSidebarContent()
            return
        }

        // ───────────────────────────────
        // 2️⃣ DELETE ENTITY + ALL ITS CLIPS
        // ───────────────────────────────
        guard let entity = selectedEntity else { return }

        // If this is a scene camera root, delegate to the dedicated camera delete path.
        // That path removes the camera from sceneCameras/sceneCameraItems and removes
        // its collection-view cell — the generic path below does neither.
        if entity.components[CategoryComponent.self]?.toolType == .camera {
            selectedEntity = nil
            deleteSceneCamera(cameraRoot: entity)
            return
        }

        let entityName = entity.name

        // Remove all motion path visuals and rotation arcs
        for clip in timeline.clips where clip.entityName == entityName {
            if let visual = activeMotionPaths[clip.id] {
                visual.startHandle?.removeFromParent()
                visual.root.removeFromParent()
            }
            activeMotionPaths.removeValue(forKey: clip.id)
            hideRotationArc(for: clip.id)
        }

        // Remove all clips for this entity
        timeline.clips.removeAll { $0.entityName == entityName }

        // Remove base transform
        baseTransforms.removeValue(forKey: entityName)

        // Remove entity itself
        entity.removeFromParent()
        selectedEntity = nil

        updateEntityFinalTransforms()
        refreshSidebarContent()
    }

    func selectEntityFromSidebar(named name: String) {
        guard let entity = mainAnchor?.findEntity(named: name) else { return }

        // Clear previous selection visual state
        if let previous = selectedEntity, previous != entity {
            setEntityTransparency(previous, alpha: 1.0)
        }

        // Dismiss any stale action menus
        currentActionMenu?.removeFromSuperview()
        currentActionMenu = nil

        // Select the entity
        selectedEntity     = entity
        activeHandleEntity = nil
        setEntityTransparency(entity, alpha: 0.9)

        // Show gizmos (move/rotate based on current interactionMode)
        updateGizmoMode()

        // Focus the camera on the selected entity
        frameEntityAnimated(entity)

        // Refresh sidebar highlight
        refreshSidebarContent()
    }

    // MARK: - Duplicate

    /// Creates an exact copy of the currently selected entity, offset slightly
    /// so it doesn't sit on top of the original. The clone spawns unlocked
    /// and immediately selectable.
    func duplicateSelected() {
        guard let entity = selectedEntity,
              let anchor = mainAnchor else { return }

        saveCurrentStateToUndo()

        // ─── Camera duplication ──────────────────────────────────────────────
        // Cameras need special handling: the PerspectiveCamera must be freshly
        // created (cloned RealityKit cameras don't function as live cameras),
        // and the new camera must be registered in all tracking arrays.
        if entity.components[CategoryComponent.self]?.toolType == .camera {
            duplicateCamera(entity, anchor: anchor)
            return
        }

        // ─── Standard entity duplication ─────────────────────────────────────

        // 1. Deep clone — copies entire entity tree including children & materials
        let clone = entity.clone(recursive: true)

        // 2. Generate unique name: "EntityName_copy", "EntityName_copy_2", etc.
        let baseName = entity.name + "_copy"
        let existing = anchor.children.filter {
            $0.name == baseName || $0.name.hasPrefix(baseName + "_")
        }.count
        clone.name = existing == 0 ? baseName : "\(baseName)_\(existing + 1)"

        // 3. Offset position so the clone is visible next to the original
        clone.position.x += 0.3
        clone.position.z += 0.3

        // 4. Assign a fresh stable UUID for animation binding
        clone.components.set(EntityIDComponent(id: UUID()))

        // 5. Re-apply collision shapes + input target (clone may not carry these)
        clone.generateCollisionShapes(recursive: true)
        clone.components.set(InputTargetComponent())

        // 6. Manually copy custom ECS components that .clone() may not carry
        if let cat = entity.components[CategoryComponent.self] {
            clone.components.set(cat)
        }
        if let pose = entity.components[CharacterPoseComponent.self] {
            clone.components.set(pose)
        }
        if let lightConfig = entity.components[LightConfigComponent.self] {
            clone.components.set(lightConfig)
        }
        if let wall = entity.components[WallComponent.self] {
            clone.components.set(wall)
        }
        if let ground = entity.components[GroundComponent.self] {
            clone.components.set(ground)
        }
        if let bg = entity.components[BackgroundComponent.self] {
            clone.components.set(bg)
        }
        if let customProp = entity.components[CustomPropComponent.self] {
            clone.components.set(customProp)
        }

        // 7. Always spawn the clone unlocked
        clone.components.remove(LockComponent.self)

        // 8. Light duplication note:
        //    .clone(recursive: true) copies the entire entity tree including
        //    light child entities (SpotLight, PointLight nodes) with their
        //    transforms intact. We do NOT call attachLight() here because
        //    that would rebuild the light from default config, destroying
        //    any user-applied rotation/direction.

        // 9. Pause any baked auto-animations on the clone (Mixamo models auto-play)
        pauseAllAnimations(in: clone)

        // 10. Add to scene
        anchor.addChild(clone)
        refreshSidebarContent()
        CanvasTutorialManager.shared.handleEntityDuplicatedOrRenamed()
    }

    // MARK: - Camera Duplication

    /// Duplicates a scene camera entity. Creates a fresh PerspectiveCamera
    /// (because cloned RK cameras lose live functionality), positions it
    /// near the original, preserves the orientation, and registers it in
    /// all camera tracking systems (sceneCameras, sceneCameraItems, cameraToVisualMap).
    private func duplicateCamera(_ entity: Entity, anchor: Entity) {
        // Read source camera properties
        let sourceAspect = entity.components[CameraAspectComponent.self]?.aspectRatio ?? .default
        let sourceVisual = entity.components[CameraVisualComponent.self]
        let modelName = sourceVisual?.modelName ?? "cam1"
        let displayName = sourceVisual?.displayName ?? "DSLR"

        // Find the original PerspectiveCamera child to copy its orientation
        let sourceCam = entity.children.first(where: { $0 is PerspectiveCamera }) as? PerspectiveCamera

        // Build the new camera root
        let index = sceneCameras.count
        let cameraRoot = Entity()
        cameraRoot.name = "SceneCameraRoot_\(index)"
        cameraRoot.components.set(CategoryComponent(toolType: .camera))
        let cameraID = UUID()
        cameraRoot.components.set(EntityIDComponent(id: cameraID))
        cameraRoot.components.set(CameraVisualComponent(modelName: modelName, displayName: displayName))
        cameraRoot.components.set(CameraAspectComponent(aspectRatio: sourceAspect))

        // Position slightly offset from the original
        cameraRoot.position = entity.position + SIMD3<Float>(0.3, 0, 0.3)
        // Preserve orientation (rotation) of the original camera root
        cameraRoot.orientation = entity.orientation

        // Create a fresh PerspectiveCamera with the same settings
        let camera = PerspectiveCamera()
        camera.name = "SceneCamera_\(index)"
        camera.isEnabled = false
        // Copy orientation from source camera (or use default 180° flip)
        if let src = sourceCam {
            camera.orientation = src.orientation
            camera.position = src.position
            camera.camera.fieldOfViewInDegrees = src.camera.fieldOfViewInDegrees
        } else {
            camera.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0])
        }

        // Copy focus component if present
        if let focus = entity.components[CameraFocusComponent.self] {
            cameraRoot.components.set(focus)
        }

        cameraRoot.addChild(camera)
        anchor.addChild(cameraRoot)

        // Register in all tracking arrays
        sceneCameras.append(camera)
        cameraToVisualMap[camera] = cameraRoot
        cameraCounter += 1
        sceneCameraItems.append(SceneCameraItem(
            id: cameraID,
            camera: camera,
            cameraRoot: cameraRoot,
            displayName: "Camera \(cameraCounter)",
            aspectRatio: sourceAspect
        ))

        cameraCollectionView?.reloadData()
        startCameraPreviewUpdates()
        setCameraPanelExpanded(true, animated: true)
        setupCameraPanelSwipeGestures()

        // Clone the visual model from the source camera (instant — no disk I/O).
        // The source entity has the USDZ model already loaded as child entities.
        // We clone those children (skipping PerspectiveCamera) and attach them.
        var clonedVisual = false
        for child in entity.children where !(child is PerspectiveCamera) {
            let visualClone = child.clone(recursive: true)
            cameraRoot.addChild(visualClone)
            visualClone.generateCollisionShapes(recursive: true)
            visualClone.components.set(InputTargetComponent())
            clonedVisual = true

            // Re-derive camera position from cloned model bounds
            let scaledBounds = visualClone.visualBounds(relativeTo: cameraRoot)
            camera.position = SIMD3<Float>(
                scaledBounds.center.x,
                scaledBounds.center.y,
                scaledBounds.min.z
            )
        }

        // Fallback: if the source had no visual children, load from disk
        if !clonedVisual {
            loadCameraVisualModel(modelName, onto: cameraRoot, camera: camera)
        }

        refreshSidebarContent()
        CanvasTutorialManager.shared.handleEntityDuplicatedOrRenamed()
    }

}
