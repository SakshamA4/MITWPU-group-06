import Combine
import PhotosUI
import RealityKit
import UIKit
import ARKit

extension CanvasViewController {

    func setupGizmo() {
        let root = Entity()
        root.name = "GizmoRoot"
        
        // 1. VERTICAL ARROW (Y Axis) - Green
        let arrowMat = UnlitMaterial(color: .systemGreen)
        let shaft = ModelEntity(mesh: .generateCylinder(height: 1.0, radius: 0.02), materials: [arrowMat])
        shaft.position = [0, 0.5, 0]
        
        let cone = ModelEntity(mesh: .generateCone(height: 0.25, radius: 0.08), materials: [arrowMat])
        cone.position = [0, 1.0, 0]
        
        // Arrow Collider (Invisible box for easier grabbing)
        let arrowCollider = ModelEntity(
            mesh: .generateBox(size: [0.2, 1.3, 0.2]),
            materials: [SimpleMaterial(color: .clear, isMetallic: false)]
        )
        arrowCollider.components.set(OpacityComponent(opacity: 0.0))
        arrowCollider.position = [0, 0.65, 0]
        arrowCollider.name = "Gizmo_Arrow_Y" // Name explicit for hit testing
        arrowCollider.generateCollisionShapes(recursive: false)
        
        let arrowHandle = Entity()
        arrowHandle.name = "Gizmo_Arrow_Y"
        arrowHandle.addChild(shaft)
        arrowHandle.addChild(cone)
        arrowHandle.addChild(arrowCollider)
        
        // 2. CONCENTRIC CIRCLES (Plane XZ) - Blue
        let planeMat = UnlitMaterial(color: .systemBlue)
        let innerDot = ModelEntity(mesh: .generateCylinder(height: 0.02, radius: 0.15), materials: [planeMat])
        // We keep the visual dot, but the collider below handles the interaction now
        
        let ringMat = UnlitMaterial(color: .systemBlue.withAlphaComponent(0.4))
        
        // Visual Rings
        let ring1 = ModelEntity(mesh: .generateCylinder(height: 0.001, radius: 0.4), materials: [ringMat])
        let ring2 = ModelEntity(mesh: .generateCylinder(height: 0.001, radius: 0.7), materials: [ringMat])
        
        // Plane Collider (Invisible Big Disc)
        // This allows you to grab anywhere inside the large ring to move the object
        let planeCollider = ModelEntity(
            mesh: .generateCylinder(height: 0.01, radius: 0.7),
            materials: [SimpleMaterial(color: .clear, isMetallic: false)]
        )
        planeCollider.components.set(OpacityComponent(opacity: 0.0))
        planeCollider.name = "Gizmo_Plane_XZ" // This name triggers the Plane logic
        planeCollider.generateCollisionShapes(recursive: false)
        
        let planeHandle = Entity()
        planeHandle.name = "PlaneHandle"
        planeHandle.addChild(innerDot)
        planeHandle.addChild(ring1)
        planeHandle.addChild(ring2)
        planeHandle.addChild(planeCollider) // Add the big invisible grab area
        
        // Assemble
        root.addChild(arrowHandle)
        root.addChild(planeHandle)
        
        self.gizmoRoot = root
    }

    
    
    func showGizmo(at entity: Entity) {
        guard let anchor = arView.scene.findEntity(named: "MainAnchor"),
              let gizmo = gizmoRoot else { return }
        
        // 1. Calculate the size of the object
        // visualBounds gives us the "box" that fits around the model
        let bounds = entity.visualBounds(relativeTo: nil)
        let width = bounds.extents.x
        let depth = bounds.extents.z
        let maxDimension = max(width, depth)
        
        // 2. Determine Scale
        // We want the circle to be slightly wider than the object.
        // We set a minimum of 0.4 so it's always tappable.
        let targetScale = max(0.4, maxDimension * 1.2)
        
        // 3. Apply scale ONLY to the floor circles (PlaneHandle)
        // We don't scale gizmoRoot because that would make the Green Arrow huge too.
        if let planeHandle = gizmo.findEntity(named: "PlaneHandle") {
            planeHandle.scale = [targetScale, 1.0, targetScale]
        }
        
        if gizmo.parent == nil {
            anchor.addChild(gizmo)
        }
        
        // Sync position to the selected object
        gizmo.position = entity.position(relativeTo: anchor)
        gizmo.isEnabled = true
        resetGizmoColors()
    }

    
    
    func hideGizmo() {
        gizmoRoot?.isEnabled = false
        gizmoRoot?.removeFromParent()
    }

    
    func updateGizmoPosition() {
        guard let entity = selectedEntity, let gizmo = gizmoRoot else { return }
        // Move gizmo with the object
        gizmo.position = entity.position(relativeTo: nil)
    }

    func getLocalAxis(for part: GizmoPart, from entity: Entity) -> SIMD3<Float> {
        switch part {
        case .rotateX: return simd_normalize(entity.transform.matrix.columns.0.xyz)
        case .rotateZ: return simd_normalize(entity.transform.matrix.columns.2.xyz)
        default: return simd_normalize(entity.transform.matrix.columns.1.xyz) // Default Y
        }
    }

    func getPlaneIntersection(location: CGPoint, planeNormal: SIMD3<Float>, planePoint: SIMD3<Float>) -> SIMD3<Float>? {
        guard let ray = arView.ray(through: location) else { return nil }
        return rayPlaneIntersection(
            rayOrigin: ray.origin,
            rayDirection: ray.direction,
            planePoint: planePoint,
            planeNormal: planeNormal
        )
    }

    
    func showRotationGizmo(for entity: Entity) {
        
        rotationGizmo?.removeFromParent()
        
        let gizmo = RotationRingGizmo(target: entity)
        entity.addChild(gizmo)
        
        rotationGizmo = gizmo
    }

    
    func hideRotationGizmo() {
        rotationGizmo?.removeFromParent()
        rotationGizmo = nil
    }


    func updateGizmoMode() {
        guard let selected = selectedEntity else {
            hideRotationGizmo()
            hideGizmo()
            return
        }

        // Never show gizmos on a locked entity
        let isLocked = selected.components[LockComponent.self]?.isLocked ?? false
        if isLocked {
            hideGizmo()
            hideRotationGizmo()
            return
        }

        switch interactionMode {
        case .move:
            hideRotationGizmo()
            showGizmo(at: selected)
        case .rotate:
            hideGizmo()
            showRotationGizmo(for: selected)
        case .none:
            hideGizmo()
            hideRotationGizmo()
        }
    }

    func updateGizmoVisibility() {
        guard let gizmo = gizmoRoot else { return }
        
        // Hide everything if no object is selected
        if selectedEntity == nil {
            gizmo.isEnabled = false
            return
        }
        
        gizmo.isEnabled = true
        let isRotateMode = (interactionMode == .rotate)
        
        for child in gizmo.children {
            // Hide movement arrows/circles when in Rotate Mode
            if child.name.contains("Arrow") || child.name.contains("Plane") {
                child.isEnabled = !isRotateMode
            }
            // Hide rings when in Move Mode
            else if child.name.contains("Ring") || child.name.contains("Rotate") {
                child.isEnabled = isRotateMode
            }
        }
    }


    func highlightGizmoPart(_ part: GizmoPart) {
        // 1. Reset everything first to ensure clean state
        resetGizmoColors()
        
        guard let gizmo = gizmoRoot else { return }
        
        // Define the highlight color
        let highlightMaterial = UnlitMaterial(color: .systemYellow)
        
        switch part {
        case .arrowY:
            // Find the Arrow Group
            if let arrowHandle = gizmo.findEntity(named: "Gizmo_Arrow_Y") {
                // Apply yellow to all visible parts (Shaft, Cone), ignoring the invisible collider
                for child in arrowHandle.children {
                    if let model = child as? ModelEntity {
                        // Only color it if it's NOT the invisible collider
                        if !model.name.contains("Collider") {
                            model.model?.materials = [highlightMaterial]
                        }
                    }
                }
            }
            
        case .planeXZ:
            // Find the Plane Group
            if let planeHandle = gizmo.findEntity(named: "PlaneHandle") {
                // Apply yellow to all visible rings/dots
                for child in planeHandle.children {
                    if let model = child as? ModelEntity {
                        if !model.name.contains("Collider") {
                            model.model?.materials = [highlightMaterial]
                        }
                    }
                }
            }
            
        // Keep your existing rotation ring logic
        case .rotateX:
            if let ring = gizmo.findEntity(named: "xRing") as? ModelEntity {
                ring.model?.materials = [highlightMaterial]
            }
        case .rotateY:
            if let ring = gizmo.findEntity(named: "yRing") as? ModelEntity {
                ring.model?.materials = [highlightMaterial]
            }
        case .rotateZ:
            if let ring = gizmo.findEntity(named: "zRing") as? ModelEntity {
                ring.model?.materials = [highlightMaterial]
            }
            
        case .none:
            resetGizmoColors()
        }
    }


    func resetGizmoColors() {
        guard let gizmo = gizmoRoot else { return }
        
        // 1. Reset Arrow to Green
        if let arrowHandle = gizmo.findEntity(named: "Gizmo_Arrow_Y") {
            let greenMat = UnlitMaterial(color: .systemGreen)
            for child in arrowHandle.children {
                if let model = child as? ModelEntity {
                    // Ensure we don't accidentally make the collider visible
                    if !model.name.contains("Collider") {
                        model.model?.materials = [greenMat]
                    }
                }
            }
        }
        
        // 2. Reset Plane to Blue (Rings are semi-transparent blue usually, but standard blue works for clarity)
        if let planeHandle = gizmo.findEntity(named: "PlaneHandle") {
            let planeMat = UnlitMaterial(color: .systemBlue)
            let ringMat = UnlitMaterial(color: .systemBlue.withAlphaComponent(0.4))
            
            for child in planeHandle.children {
                if let model = child as? ModelEntity {
                    if !model.name.contains("Collider") {
                        // Differentiate between the solid dot and the transparent rings if you wish,
                        // or just use planeMat for everything. Here we restore your setup:
                        if child.name.contains("Ring") { // Assuming mesh generation didn't name them explicitly, but this is safe
                             model.model?.materials = [ringMat]
                        } else {
                             model.model?.materials = [planeMat]
                        }
                    }
                }
            }
        }
        
        // 3. Reset Rotation Rings
        if let xRing = gizmo.findEntity(named: "xRing") as? ModelEntity {
            xRing.model?.materials = [UnlitMaterial(color: .systemRed)]
        }
        if let yRing = gizmo.findEntity(named: "yRing") as? ModelEntity {
            yRing.model?.materials = [UnlitMaterial(color: .systemGreen)]
        }
        if let zRing = gizmo.findEntity(named: "zRing") as? ModelEntity {
            zRing.model?.materials = [UnlitMaterial(color: .systemBlue)]
        }
    }

}
