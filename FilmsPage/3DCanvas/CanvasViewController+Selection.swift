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
        
        self.selectedEntity = entity
        self.refreshSidebarContent()
        
        if let screenPosition = arView.project(entity.position(relativeTo: nil))
        {
            
            currentActionMenu?.removeFromSuperview()
            
            showActionMenu(at: screenPosition)
            
            if let animation = entity.availableAnimations.first {
                entity.playAnimation(animation.repeat(count: 1))
            }
        }
    }

}
