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
            
            // Remove path visuals
            activeMotionPaths[clipID]?.root.removeFromParent()
            activeMotionPaths.removeValue(forKey: clipID)
            
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
        
        let entityName = entity.name
        
        // Remove all motion path visuals
        for clip in timeline.clips where clip.entityName == entityName {
            activeMotionPaths[clip.id]?.root.removeFromParent()
            activeMotionPaths.removeValue(forKey: clip.id)
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
        
        guard let entity = arView.scene.findEntity(named: name) else { return }
        
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
