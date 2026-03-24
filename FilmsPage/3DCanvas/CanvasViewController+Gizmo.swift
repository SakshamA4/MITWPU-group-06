import Combine
import PhotosUI
import RealityKit
import UIKit
import ARKit

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - DropShadowComponent
// Marker component — attached to both the vertical line and floor circle so
// hideDropShadow() can find and remove them by tag rather than by name.
// ─────────────────────────────────────────────────────────────────────────────
struct DropShadowComponent: Component {}

extension CanvasViewController {

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Ring builder
    //
    // The previous approach used look(at:) on cylinder segments which caused
    // them to stand upright like fence posts — visually wrong.
    //
    // Correct approach:
    //   • Each segment cylinder has its HEIGHT along the local +Y axis.
    //   • We rotate each segment so that local +Y points along the chord
    //     direction on the XZ plane — i.e. we rotate around the X axis by 90°
    //     first (lying the cylinder flat), then rotate around Y to aim at the
    //     next point.
    // ─────────────────────────────────────────────────────────────────────────
    private func makeRing(
        radius:       Float,
        tubeRadius:   Float  = 0.008,   // thin — matches reference image
        segmentCount: Int    = 64,      // high count = smooth continuous ring
        color:        UIColor
    ) -> Entity {
        let container = Entity()
        container.name = "RingContainer"
        let mat   = UnlitMaterial(color: color)
        let count = max(segmentCount, 16)

        for i in 0..<count {
            let a0 = (Float(i)      / Float(count)) * 2.0 * .pi
            let a1 = (Float(i + 1) / Float(count)) * 2.0 * .pi

            // Points on the XZ plane (y = 0)
            let p0 = SIMD3<Float>(sin(a0) * radius, 0, cos(a0) * radius)
            let p1 = SIMD3<Float>(sin(a1) * radius, 0, cos(a1) * radius)

            let chord = p1 - p0
            let segLen = simd_length(chord)
            guard segLen > 0.0001 else { continue }

            let seg = ModelEntity(
                mesh:      MeshResource.generateCylinder(height: segLen, radius: tubeRadius),
                materials: [mat]
            )

            // Position at chord midpoint (y = 0)
            seg.position = (p0 + p1) * 0.5

            // Orient: cylinder height (+Y) must point along the chord direction.
            // chord is already in the XZ plane so we need a rotation that maps
            // [0,1,0] → normalize(chord).
            let up    = SIMD3<Float>(0, 1, 0)
            let dir   = simd_normalize(chord)
            let dot   = simd_dot(up, dir)
            let cross = simd_cross(up, dir)
            let crossLen = simd_length(cross)

            if crossLen < 0.0001 {
                // Parallel or anti-parallel — identity or 180° flip
                seg.orientation = dot > 0
                    ? simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
                    : simd_quatf(angle: .pi, axis: [1, 0, 0])
            } else {
                let angle = atan2(crossLen, dot)
                seg.orientation = simd_quatf(angle: angle, axis: simd_normalize(cross))
            }

            container.addChild(seg)
        }
        return container
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - setupGizmo
    //
    // Entity tree:
    //
    //   GizmoRoot
    //   ├── Gizmo_Arrow_Y          ← Y-axis move arrow (RED at rest, yellow active)
    //   │     ├── shaft            (white cylinder)
    //   │     ├── cone             (white cone)
    //   │     └── arrowCollider    (invisible box, name "Gizmo_Arrow_Y")
    //   └── PlaneHandle            ← scales with object footprint
    //         ├── CentreDot        ← red disc  → XZ-plane drag → move
    //         ├── dotCollider      ← invisible disc, name "Gizmo_Plane_XZ"
    //         ├── OuterRing        ← red continuous ring → drag → axial move (forward/back)
    //         └── ringCollider     ← invisible wide annulus, name "Gizmo_Ring_XZ"
    // ─────────────────────────────────────────────────────────────────────────
    func setupGizmo() {
        let root = Entity()
        root.name = "GizmoRoot"

        // ── 1. Y-AXIS ARROW — Red at rest, Yellow when actively dragged ────────
        let whiteMat = UnlitMaterial(color: .systemRed)

        let shaft = ModelEntity(
            mesh:      MeshResource.generateCylinder(height: 0.85, radius: 0.016),
            materials: [whiteMat]
        )
        shaft.name     = "ArrowShaft"
        shaft.position = [0, 0.425, 0]

        let cone = ModelEntity(
            mesh:      MeshResource.generateCone(height: 0.20, radius: 0.065),
            materials: [whiteMat]
        )
        cone.name     = "ArrowCone"
        cone.position = [0, 0.875, 0]

        // Invisible wide collider so the arrow is easy to grab
        let arrowCollider = ModelEntity(
            mesh:      MeshResource.generateBox(size: [0.15, 1.15, 0.15]),
            materials: [SimpleMaterial(color: .clear, isMetallic: false)]
        )
        arrowCollider.components.set(OpacityComponent(opacity: 0.0))
        arrowCollider.position = [0, 0.55, 0]
        arrowCollider.name     = "Gizmo_Arrow_Y"   // hit-test key
        arrowCollider.generateCollisionShapes(recursive: false)

        let arrowHandle   = Entity()
        arrowHandle.name  = "Gizmo_Arrow_Y"
        arrowHandle.addChild(shaft)
        arrowHandle.addChild(cone)
        arrowHandle.addChild(arrowCollider)

        // ── 2. PLANE HANDLE ──────────────────────────────────────────────────

        let redMat = UnlitMaterial(color: .systemRed)

        // Centre dot — solid red disc, XZ move target. Larger so it's clearly visible
        // and easy to grab even on small entities like cameras.
        let centreDot      = ModelEntity(
            mesh:      MeshResource.generateCylinder(height: 0.016, radius: 0.22),
            materials: [redMat]
        )
        centreDot.name     = "CentreDot"
        centreDot.position = [0, 0.008, 0]

        // Invisible disc collider — fills the entire interior of the outer ring.
        // radius: 0.75 (out of the ring's 1.0) gives a large, easy-to-hit target
        // for XZ-plane dragging, especially on small entities where the ring itself
        // may be larger than the object's footprint.
        let dotCollider    = ModelEntity(
            mesh:      MeshResource.generateCylinder(height: 0.06, radius: 0.75),
            materials: [SimpleMaterial(color: .clear, isMetallic: false)]
        )
        dotCollider.components.set(OpacityComponent(opacity: 0.0))
        dotCollider.name     = "Gizmo_Plane_XZ"
        dotCollider.position = [0, 0.01, 0]
        dotCollider.generateCollisionShapes(recursive: false)

        // Outer ring — smooth continuous red circle
        // radius = 1.0 in local space; PlaneHandle is scaled per-object in showGizmo
        let outerRing      = makeRing(radius: 1.0, tubeRadius: 0.008, segmentCount: 64, color: .systemRed)
        outerRing.name     = "OuterRing"

        // Annular ring collider — built from 32 thin box segments positioned
        // along the ring perimeter so the hit area is only the ring band itself,
        // NOT the interior disc (which belongs to dotCollider / Gizmo_Plane_XZ).
        let ringColliderParent = Entity()
        ringColliderParent.name = "Gizmo_Ring_XZ"
        let ringSegCount = 32
        let ringR: Float = 1.0
        let segWidth: Float = 0.18   // tangential width — wide enough to tap easily
        let segDepth: Float = 0.12   // radial depth — keeps collider on the ring, not inside
        let segHeight: Float = 0.10  // vertical — generous for touch targeting
        for i in 0..<ringSegCount {
            let angle = Float(i) / Float(ringSegCount) * 2 * Float.pi
            let x = sin(angle) * ringR
            let z = cos(angle) * ringR
            let seg = ModelEntity(
                mesh: MeshResource.generateBox(size: [segWidth, segHeight, segDepth]),
                materials: [SimpleMaterial(color: .clear, isMetallic: false)]
            )
            seg.components.set(OpacityComponent(opacity: 0.0))
            seg.position = [x, 0.02, z]
            seg.orientation = simd_quatf(angle: -angle, axis: [0, 1, 0])
            seg.generateCollisionShapes(recursive: false)
            ringColliderParent.addChild(seg)
        }
        // InputTargetComponent on the parent so hit-test works
        ringColliderParent.components.set(InputTargetComponent())

        // Filled disc that lights up when the outer ring is dragged (Y-rotate highlight)
        // Uses PBR transparent so it blends nicely; hidden at rest.
        var planeDiscPBR       = PhysicallyBasedMaterial()
        planeDiscPBR.baseColor = .init(tint: UIColor.systemRed.withAlphaComponent(0.0))
        planeDiscPBR.roughness = .init(floatLiteral: 1.0)
        planeDiscPBR.metallic  = .init(floatLiteral: 0.0)
        planeDiscPBR.blending  = .transparent(opacity: .init(floatLiteral: 0.0))

        let planeDisc      = ModelEntity(
            mesh:      MeshResource.generateCylinder(height: 0.006, radius: 1.0),
            materials: [planeDiscPBR]
        )
        planeDisc.name     = "PlaneDisc"
        planeDisc.position = [0, 0.003, 0]
        planeDisc.isEnabled = false   // hidden until ring drag begins

        let planeHandle    = Entity()
        planeHandle.name   = "PlaneHandle"
        planeHandle.addChild(centreDot)
        planeHandle.addChild(dotCollider)
        planeHandle.addChild(outerRing)
        planeHandle.addChild(ringColliderParent)
        planeHandle.addChild(planeDisc)

        root.addChild(arrowHandle)
        root.addChild(planeHandle)

        // ── Ghost layer — rendered THROUGH the object via OpacityComponent ──────
        //
        // OpacityComponent forces RealityKit to render the entity in the
        // transparent pass AND disables the depth test for those fragments,
        // so the ghost arrow draws through any opaque geometry at the set opacity.

        let ghostMat = UnlitMaterial(color: .systemRed)

        // ── Ghost ring ────────────────────────────────────────────────────────
        let ghostRing  = makeRing(radius: 1.0, tubeRadius: 0.009, segmentCount: 64,
                                   color: .systemRed)
        ghostRing.name = "GhostRing"
        for seg in ghostRing.children {
            if let m = seg as? ModelEntity {
                m.model?.materials = [ghostMat]
                m.components.set(OpacityComponent(opacity: 0.30))
            }
        }

        let ghostPlane  = Entity()
        ghostPlane.name = "GhostPlane"
        ghostPlane.addChild(ghostRing)

        // ── Ghost arrow shaft ─────────────────────────────────────────────────
        let ghostShaft      = ModelEntity(
            mesh:      MeshResource.generateCylinder(height: 0.85, radius: 0.018),
            materials: [ghostMat]
        )
        ghostShaft.name     = "GhostShaft"
        ghostShaft.position = [0, 0.425, 0]
        ghostShaft.components.set(OpacityComponent(opacity: 0.30))

        // ── Ghost cone ────────────────────────────────────────────────────────
        let ghostCone      = ModelEntity(
            mesh:      MeshResource.generateCone(height: 0.20, radius: 0.07),
            materials: [ghostMat]
        )
        ghostCone.name     = "GhostCone"
        ghostCone.position = [0, 0.875, 0]
        ghostCone.components.set(OpacityComponent(opacity: 0.30))

        let ghostArrow  = Entity()
        ghostArrow.name = "GhostArrow"
        ghostArrow.addChild(ghostShaft)
        ghostArrow.addChild(ghostCone)

        root.addChild(ghostArrow)
        root.addChild(ghostPlane)

        self.gizmoRoot = root
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - showGizmo
    // ─────────────────────────────────────────────────────────────────────────
    func showGizmo(at entity: Entity) {
        // Do not show gizmos when viewing through a camera
        guard activeCamera === editorCamera else { return }
        
        guard let anchor = arView.scene.findEntity(named: "MainAnchor"),
              let gizmo  = gizmoRoot else { return }

        // PlaneHandle is always a fixed proportion of the gizmo root scale —
        // no longer driven by object size, so walls/grounds don't bloat the ring.
        let fixedHandleScale: Float = 0.55
        if let planeHandle = gizmo.findEntity(named: "PlaneHandle") {
            planeHandle.scale = [fixedHandleScale, 1.0, fixedHandleScale]
        }
        if let ghostPlane = gizmo.findEntity(named: "GhostPlane") {
            ghostPlane.scale = [fixedHandleScale, 1.0, fixedHandleScale]
        }

        if gizmo.parent == nil {
            anchor.addChild(gizmo)
        }

        // Place gizmo at the entity's XZ position but at the BOTTOM of its
        // bounding box so it always sits at the base regardless of pivot point.
        // This fixes walls and backgrounds where the pivot is at the centre.
        let entityPos  = entity.position(relativeTo: anchor)
        let boundsMinY = entity.visualBounds(relativeTo: nil).min.y
        gizmo.position = SIMD3<Float>(entityPos.x, boundsMinY, entityPos.z)
        gizmo.isEnabled = true

        // Scale the whole gizmo by camera-to-entity distance so it occupies
        // a consistent screen size regardless of zoom level or entity position.
        let entityWorldPos = entity.position(relativeTo: nil)
        let camWorldPos    = activeCamera.position(relativeTo: nil)
        let camToEntity    = simd_distance(camWorldPos, entityWorldPos)
        let screenScale    = max(0.15, min(2.5, camToEntity * 0.15))
        gizmo.scale = SIMD3<Float>(repeating: screenScale)

        resetGizmoColors()
        updateDropShadow(for: entity)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - hideGizmo
    // ─────────────────────────────────────────────────────────────────────────
    func hideGizmo() {
        gizmoRoot?.isEnabled = false
        gizmoRoot?.removeFromParent()
        hideDropShadow()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - updateGizmoPosition  (called every frame while dragging)
    // ─────────────────────────────────────────────────────────────────────────
    func updateGizmoPosition() {
        guard let entity = selectedEntity, let gizmo = gizmoRoot else { return }
        guard let anchor = arView.scene.findEntity(named: "MainAnchor") else { return }
        let entityPos  = entity.position(relativeTo: anchor)
        let boundsMinY = entity.visualBounds(relativeTo: nil).min.y
        gizmo.position = SIMD3<Float>(entityPos.x, boundsMinY, entityPos.z)
        let entityWorldPos = entity.position(relativeTo: nil)
        let camWorldPos    = activeCamera.position(relativeTo: nil)
        let camToEntity    = simd_distance(camWorldPos, entityWorldPos)
        let screenScale    = max(0.15, min(2.5, camToEntity * 0.15))
        gizmo.scale = SIMD3<Float>(repeating: screenScale)
        updateDropShadow(for: entity)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Drop Shadow
    //
    // A solid thin vertical line from the object's world Y position down to
    // Y = 0, plus a small flat circle on the ground.
    //
    // The line uses a single cylinder (not dashes) to match the target image.
    // Opacity is reduced to 0.3 instead of dimming on occlusion (RealityKit
    // occlusion queries are expensive; dim the line uniformly instead so it
    // reads as a subtle guide rather than a hard shadow).
    //
    // Called from: showGizmo (on select), updateGizmoPosition (while dragging).
    // ─────────────────────────────────────────────────────────────────────────
    func updateDropShadow(for entity: Entity) {
        guard let anchor = arView.scene.findEntity(named: "MainAnchor") else { return }

        hideDropShadow()

        let worldPos  = entity.position(relativeTo: nil)
        let baseY     = entity.visualBounds(relativeTo: nil).min.y  // same as gizmo position
        let groundY: Float = 0.0

        // Only draw when the gizmo base is meaningfully above the ground plane
        guard baseY > groundY + 0.02 else { return }

        let lineHeight = baseY - groundY

        let lineMat   = UnlitMaterial(color: UIColor.systemYellow.withAlphaComponent(0.75))
        let circleMat = UnlitMaterial(color: UIColor.systemYellow.withAlphaComponent(0.85))

        let line = ModelEntity(
            mesh:      MeshResource.generateCylinder(height: lineHeight, radius: 0.005),
            materials: [lineMat]
        )
        line.position = SIMD3<Float>(worldPos.x, groundY + lineHeight * 0.5, worldPos.z)
        line.name     = "ShadowLine"
        line.components.set(DropShadowComponent())
        anchor.addChild(line)

        let circle = ModelEntity(
            mesh:      MeshResource.generateCylinder(height: 0.006, radius: 0.07),
            materials: [circleMat]
        )
        circle.position = SIMD3<Float>(worldPos.x, groundY + 0.003, worldPos.z)
        circle.name     = "ShadowCircle"
        circle.components.set(DropShadowComponent())
        anchor.addChild(circle)
    }

    func hideDropShadow() {
        guard let anchor = arView.scene.findEntity(named: "MainAnchor") else { return }
        for child in anchor.children where child.components[DropShadowComponent.self] != nil {
            child.removeFromParent()
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Axis helpers
    // ─────────────────────────────────────────────────────────────────────────
    func getLocalAxis(for part: GizmoPart, from entity: Entity) -> SIMD3<Float> {
        switch part {
        case .rotateX: return simd_normalize(entity.transform.matrix.columns.0.xyz)
        case .rotateZ: return simd_normalize(entity.transform.matrix.columns.2.xyz)
        default:       return simd_normalize(entity.transform.matrix.columns.1.xyz)
        }
    }

    func getPlaneIntersection(
        location:    CGPoint,
        planeNormal: SIMD3<Float>,
        planePoint:  SIMD3<Float>
    ) -> SIMD3<Float>? {
        guard let ray = arView.ray(through: location) else { return nil }
        return rayPlaneIntersection(
            rayOrigin:    ray.origin,
            rayDirection: ray.direction,
            planePoint:   planePoint,
            planeNormal:  planeNormal
        )
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Rotation gizmo (3-ring, shown in .rotate mode)
    // ─────────────────────────────────────────────────────────────────────────
    func showRotationGizmo(for entity: Entity) {
        rotationGizmo?.removeFromParent()
        let gizmo = RotationRingGizmo(target: entity)
        entity.addChild(gizmo)
        rotationGizmo = gizmo
        setupRotationDiscs(on: gizmo)

        // RotationRingGizmo sizes its rings internally from entity bounds
        // (radius = maxDimension * 0.75). We override that by computing the
        // scale needed to reach our desired world-space size.
        //
        // Desired size = camToEntity * 0.15, hard-capped at 0.6m so large
        // entities (walls, grounds) never produce oversized rings.
        let entityWorldPos = entity.position(relativeTo: nil)
        let camWorldPos    = activeCamera.position(relativeTo: nil)
        let camToEntity    = simd_distance(camWorldPos, entityWorldPos)
        let desiredSize    = min(camToEntity * 0.15, 0.6)
        let clampedSize    = max(0.15, desiredSize)

        // The gizmo's internal radius (what it actually built the rings at)
        let bounds         = entity.visualBounds(relativeTo: entity)
        let maxDim         = max(bounds.extents.x, bounds.extents.y, bounds.extents.z)
        let internalRadius = max(maxDim * 0.75, 0.0001)

        // localScale cancels out the internal radius and replaces it with clampedSize.
        // Also account for entity's own world scale since gizmo is entity-parented.
        let entityWorldScale = max(entity.scale(relativeTo: nil).x, 0.0001)
        let localScale       = (clampedSize / internalRadius) / entityWorldScale
        gizmo.scale = SIMD3<Float>(repeating: localScale)
    }

    /// Injects hidden filled-disc entities alongside each rotation ring so they
    /// can be shown/coloured in highlightGizmoPart without modifying RotationRingGizmo.
    private func setupRotationDiscs(on gizmo: Entity) {
        // (ringName → discName, colour, normal-axis rotation)
        let ringConfigs: [(ring: String, disc: String, color: UIColor, axis: SIMD3<Float>, angle: Float)] = [
            ("xRing", "xDisc", .systemRed,   [0, 0, 1], .pi / 2),   // X ring lives in YZ plane
            ("yRing", "yDisc", .systemGreen, [0, 1, 0], 0),          // Y ring lives in XZ plane (flat)
            ("zRing", "zDisc", .systemBlue,  [1, 0, 0], .pi / 2),   // Z ring lives in XY plane
        ]

        for cfg in ringConfigs {
            guard let ring = gizmo.findEntity(named: cfg.ring) else { continue }
            // Don't add twice if gizmo is reused
            if gizmo.findEntity(named: cfg.disc) != nil { continue }

            // Derive radius from the ring's mesh bounding box
            let bounds = ring.visualBounds(relativeTo: ring)
            let radius = max(bounds.extents.x, bounds.extents.y, bounds.extents.z) * 0.5

            var discPBR       = PhysicallyBasedMaterial()
            discPBR.baseColor = .init(tint: cfg.color.withAlphaComponent(0.0))
            discPBR.roughness = .init(floatLiteral: 1.0)
            discPBR.metallic  = .init(floatLiteral: 0.0)
            discPBR.blending  = .transparent(opacity: .init(floatLiteral: 0.0))

            let disc = ModelEntity(
                mesh:      MeshResource.generateCylinder(height: 0.004, radius: max(radius, 0.08)),
                materials: [discPBR]
            )
            disc.name       = cfg.disc
            disc.isEnabled  = false

            // Match the ring's orientation so the disc lies in the same plane
            if cfg.angle != 0 {
                disc.orientation = simd_quatf(angle: cfg.angle, axis: cfg.axis)
            }

            ring.parent?.addChild(disc)
        }
    }

    func hideRotationGizmo() {
        rotationGizmo?.removeFromParent()
        rotationGizmo = nil
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - updateGizmoMode
    // ─────────────────────────────────────────────────────────────────────────
    func updateGizmoMode() {
        // Do not show gizmos when viewing through a camera
        guard activeCamera === editorCamera else {
            hideGizmo()
            hideRotationGizmo()
            return
        }
        
        guard let selected = selectedEntity else {
            hideRotationGizmo()
            hideGizmo()
            return
        }

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

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - updateGizmoVisibility
    // ─────────────────────────────────────────────────────────────────────────
    func updateGizmoVisibility() {
        guard let gizmo = gizmoRoot else { return }

        if selectedEntity == nil {
            gizmo.isEnabled = false
            return
        }

        gizmo.isEnabled  = true
        let isRotateMode = (interactionMode == .rotate)

        for child in gizmo.children {
            if child.name.contains("Arrow") || child.name == "PlaneHandle" {
                child.isEnabled = !isRotateMode
            } else if child.name == "GhostArrow" || child.name == "GhostPlane" {
                // Ghost layers follow the same visibility as their solid counterparts
                child.isEnabled = !isRotateMode
            } else if child.name.contains("Ring") || child.name.contains("Rotate") {
                child.isEnabled = isRotateMode
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - highlightGizmoPart
    //
    // Arrow:   white → yellow only when actively dragging (arrowY)
    // DotXZ:   red   → bright yellow when dragging dot (planeXZ)
    // Ring:    red   → bright yellow when dragging ring (rotateY via ring)
    // ─────────────────────────────────────────────────────────────────────────
    func highlightGizmoPart(_ part: GizmoPart) {
        resetGizmoColors()
        guard let gizmo = gizmoRoot else { return }

        let yellow = UnlitMaterial(color: .systemYellow)

        switch part {
        case .arrowY:
            gizmo.findEntity(named: "Gizmo_Arrow_Y").flatMap { handle -> Void? in
                for child in handle.children {
                    guard let model = child as? ModelEntity else { continue }
                    guard child.name != "Gizmo_Arrow_Y" else { continue }
                    model.model?.materials = [yellow]
                }
                return ()
            }

        case .planeXZ:
            if let dot = gizmo.findEntity(named: "CentreDot") as? ModelEntity {
                dot.model?.materials = [yellow]
            }

        case .rotateY:
            if interactionMode == .rotate {
                // Rotation mode: highlight the green yRing + its disc
                if let ring = gizmo.findEntity(named: "yRing") as? ModelEntity {
                    ring.model?.materials = [yellow]
                }
                if let rotGizmo = rotationGizmo {
                    showDiscHighlight(named: "yDisc", color: .systemGreen, in: rotGizmo)
                }
            } else {
                // Move mode: highlight the red OuterRing + its fill disc
                if let ring = gizmo.findEntity(named: "OuterRing") {
                    applyMaterialRecursive(yellow, to: ring, excludingColliders: false)
                }
                showDiscHighlight(named: "PlaneDisc", color: .systemRed, in: gizmo)
            }

        case .rotateX:
            if let ring = gizmo.findEntity(named: "xRing") as? ModelEntity {
                ring.model?.materials = [yellow]
            }
            if let rotGizmo = rotationGizmo {
                showDiscHighlight(named: "xDisc", color: .systemRed, in: rotGizmo)
            }
        case .rotateZ:
            if let ring = gizmo.findEntity(named: "zRing") as? ModelEntity {
                ring.model?.materials = [yellow]
            }
            if let rotGizmo = rotationGizmo {
                showDiscHighlight(named: "zDisc", color: .systemBlue, in: rotGizmo)
            }
        case .none:
            break
        }
    }

    /// Shows a named disc fill entity with a semi-transparent version of `color`.
    private func showDiscHighlight(named discName: String, color: UIColor, in root: Entity) {
        guard let disc = root.findEntity(named: discName) as? ModelEntity else { return }
        var pbr       = PhysicallyBasedMaterial()
        pbr.baseColor = .init(tint: color.withAlphaComponent(0.45))
        pbr.roughness = .init(floatLiteral: 1.0)
        pbr.metallic  = .init(floatLiteral: 0.0)
        pbr.blending  = .transparent(opacity: .init(floatLiteral: 0.45))
        disc.model?.materials = [pbr]
        disc.isEnabled = true
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - resetGizmoColors
    //
    // Rest state:
    //   Arrow  → white  (NOT yellow — yellow is highlight-only)
    //   Dot    → red
    //   Ring   → red
    // ─────────────────────────────────────────────────────────────────────────
    func resetGizmoColors() {
        guard let gizmo = gizmoRoot else { return }

        // Arrow → red at rest
        if let arrowHandle = gizmo.findEntity(named: "Gizmo_Arrow_Y") {
            let whiteMat = UnlitMaterial(color: .systemRed)
            for child in arrowHandle.children {
                guard let model = child as? ModelEntity else { continue }
                guard child.name != "Gizmo_Arrow_Y" else { continue }   // skip collider
                model.model?.materials = [whiteMat]
            }
        }

        // Centre dot → red
        if let dot = gizmo.findEntity(named: "CentreDot") as? ModelEntity {
            dot.model?.materials = [UnlitMaterial(color: .systemRed)]
        }

        // Outer ring → red
        if let ring = gizmo.findEntity(named: "OuterRing") {
            let redMat = UnlitMaterial(color: .systemRed)
            applyMaterialRecursive(redMat, to: ring, excludingColliders: false)
        }

        // Ghost layer — restore UnlitMaterial + OpacityComponent (same as setupGizmo)
        let ghostMat = UnlitMaterial(color: .systemRed)

        if let ghostRing = gizmo.findEntity(named: "GhostRing") {
            for seg in ghostRing.children {
                if let m = seg as? ModelEntity {
                    m.model?.materials = [ghostMat]
                    m.components.set(OpacityComponent(opacity: 0.30))
                }
            }
        }
        for name in ["GhostShaft", "GhostCone"] {
            if let e = gizmo.findEntity(named: name) as? ModelEntity {
                e.model?.materials = [ghostMat]
                e.components.set(OpacityComponent(opacity: 0.30))
            }
        }

        // RotationRingGizmo rings (unchanged)
        if let xRing = gizmo.findEntity(named: "xRing") as? ModelEntity {
            xRing.model?.materials = [UnlitMaterial(color: .systemRed)]
        }
        if let yRing = gizmo.findEntity(named: "yRing") as? ModelEntity {
            yRing.model?.materials = [UnlitMaterial(color: .systemGreen)]
        }
        if let zRing = gizmo.findEntity(named: "zRing") as? ModelEntity {
            zRing.model?.materials = [UnlitMaterial(color: .systemBlue)]
        }

        // Hide all fill discs (move gizmo + rotation gizmo)
        for discName in ["PlaneDisc"] {
            if let disc = gizmo.findEntity(named: discName) {
                disc.isEnabled = false
            }
        }
        if let rotGizmo = rotationGizmo {
            for discName in ["xDisc", "yDisc", "zDisc"] {
                if let disc = rotGizmo.findEntity(named: discName) {
                    disc.isEnabled = false
                }
            }
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Material helpers
    // ─────────────────────────────────────────────────────────────────────────
    private func applyMaterialRecursive(
        _ material: UnlitMaterial,
        to entity: Entity,
        excludingColliders: Bool
    ) {
        if let model = entity as? ModelEntity {
            let isCollider = entity.name.contains("Collider") ||
                             entity.name == "Gizmo_Plane_XZ"  ||
                             entity.name == "Gizmo_Ring_XZ"
            if !(excludingColliders && isCollider) {
                model.model?.materials = [material]
            }
        }
        for child in entity.children {
            applyMaterialRecursive(material, to: child,
                                   excludingColliders: excludingColliders)
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Live gizmo scale update
    //
    // Called every render frame via SceneEvents.Update subscription so gizmos
    // rescale continuously as the camera moves, not just on tap.
    // ─────────────────────────────────────────────────────────────────────────
    func updateGizmoScales() {
        let camPos = activeCamera.position(relativeTo: nil)

        // ── Move gizmo ────────────────────────────────────────────────────────
        if let gizmo = gizmoRoot, gizmo.isEnabled,
           let entity = selectedEntity {
            let camToEntity = simd_distance(camPos, entity.position(relativeTo: nil))
            let screenScale = max(0.15, min(2.5, camToEntity * 0.15))
            gizmo.scale     = SIMD3<Float>(repeating: screenScale)
        }

        // ── Rotation rings ────────────────────────────────────────────────────
        if let rotGizmo = rotationGizmo,
           let entity   = selectedEntity {
            let camToEntity      = simd_distance(camPos, entity.position(relativeTo: nil))
            let desiredSize      = min(camToEntity * 0.15, 0.6)
            let clampedSize      = max(0.15, desiredSize)
            let bounds           = entity.visualBounds(relativeTo: entity)
            let maxDim           = max(bounds.extents.x, bounds.extents.y, bounds.extents.z)
            let internalRadius   = max(maxDim * 0.75, 0.0001)
            let entityWorldScale = max(entity.scale(relativeTo: nil).x, 0.0001)
            let localScale       = (clampedSize / internalRadius) / entityWorldScale
            rotGizmo.scale       = SIMD3<Float>(repeating: localScale)
        }
    }
}
