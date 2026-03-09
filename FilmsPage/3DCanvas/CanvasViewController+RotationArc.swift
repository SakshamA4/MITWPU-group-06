import RealityKit
import UIKit

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - RotationArcComponent
//
// Marks every arc handle tip entity with its owning clipID.
// Mirrors MotionPathHandleComponent so the same tap/drag pattern applies.
// ─────────────────────────────────────────────────────────────────────────────

struct RotationArcComponent: Component {
    let clipID: UUID
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - RotationArcVisual
//
// Container that holds every scene entity that belongs to one arc, so we can
// update or tear down the whole thing by reference — exactly like MotionPathVisual.
// ─────────────────────────────────────────────────────────────────────────────

struct RotationArcVisual {
    let root:        Entity          // arcRoot — positioned at entity world centre
    let startHandle: ModelEntity     // orange tip at fromValue.y angle
    let endHandle:   ModelEntity     // blue   tip at toValue.y   angle
    var arcCurve:    Entity          // the arc curve segments (replaced on update)
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - RotationArcRenderer
//
// Static geometry factory that mirrors MotionPathRenderer's API:
//
//   makeArc(clip:entity:)       → builds a full RotationArcVisual
//   update(visual:clip:entity:) → rebuilds the arc curve and repositions handles
//
// Geometry:
//   • Two radial lines (thin boxes) from the entity centre outward at the
//     start and end angles.
//   • A tappable sphere tip at the end of each line — carries RotationArcComponent
//     so handleTap() and handlePan() can identify it.
//   • An arc of thin cylinder segments connecting the two tips.
//
// All positions are in local space relative to arcRoot (which sits at the
// entity's world-space centre), exactly like MotionPathVisual.root/handles.
// ─────────────────────────────────────────────────────────────────────────────

enum RotationArcRenderer {

    // ── Public ──────────────────────────────────────────────────────────────

    static func makeArc(clip: AnimationClip, entity: Entity) -> RotationArcVisual {
        let centre = entity.position(relativeTo: nil)
        let radius: Float = 0.6     // slightly wider than the rotation gizmo rings

        let arcRoot = Entity()
        arcRoot.name     = "RotationArc_\(clip.id)"
        arcRoot.position = centre

        let fromAngle = clip.fromValue.y
        let toAngle   = clip.toValue.y

        // Start handle — orange
        let startHandle = makeHandle(
            angle: fromAngle,
            radius: radius,
            color: .systemOrange,
            clipID: clip.id,
            name: "arcHandle.start"
        )
        arcRoot.addChild(startHandle)

        // End handle — blue
        let endHandle = makeHandle(
            angle: toAngle,
            radius: radius,
            color: .systemBlue,
            clipID: clip.id,
            name: "arcHandle.end"
        )
        arcRoot.addChild(endHandle)

        // Arc curve
        let curve = makeArcCurve(from: fromAngle, to: toAngle, radius: radius)
        curve.name = "arcCurve"
        arcRoot.addChild(curve)

        return RotationArcVisual(
            root:        arcRoot,
            startHandle: startHandle,
            endHandle:   endHandle,
            arcCurve:    curve
        )
    }

    /// Repositions handles and replaces the arc curve mesh for an existing visual.
    /// Called every frame while the end handle is being dragged.
    static func update(
        visual: RotationArcVisual,
        clip: AnimationClip,
        entity: Entity
    ) {
        let radius: Float = 0.6
        let fromAngle = clip.fromValue.y
        let toAngle   = clip.toValue.y

        // Re-centre the root in case the entity moved
        visual.root.position = entity.position(relativeTo: nil)

        // Update handle orientations (the tip child keeps its local offset so
        // only the parent line rotation needs to change)
        visual.startHandle.orientation = simd_quatf(angle: fromAngle, axis: [0, 1, 0])
        visual.endHandle.orientation   = simd_quatf(angle: toAngle,   axis: [0, 1, 0])

        // Replace the arc curve with a freshly-built one
        visual.arcCurve.removeFromParent()
        let newCurve = makeArcCurve(from: fromAngle, to: toAngle, radius: radius)
        newCurve.name = "arcCurve"
        visual.root.addChild(newCurve)

        // NOTE: visual is a struct so we can't mutate arcCurve in-place —
        // the new curve is parented to root and the old one removed.
        // The caller must replace its stored RotationArcVisual if needed,
        // but for pure rendering the root entity is the source of truth.
    }

    // ── Private geometry helpers ─────────────────────────────────────────────

    /// A radial line + tappable sphere tip at `angle` on the XZ plane.
    ///
    ///   arcRoot (at entity centre)
    ///     └── lineEntity   (thin box, oriented along +Z, rotated to `angle`)
    ///           └── tipSphere  (at local z = radius * 0.5, carries component)
    ///
    static func makeHandle(
        angle: Float,
        radius: Float,
        color: UIColor,
        clipID: UUID,
        name: String
    ) -> ModelEntity {
        let material = UnlitMaterial(color: color)

        // Thin box pointing along local +Z; we rotate the root to aim it at `angle`
        let lineMesh = MeshResource.generateBox(size: SIMD3<Float>(0.008, 0.008, radius))
        let line = ModelEntity(mesh: lineMesh, materials: [material])
        line.name        = name
        line.position    = .zero
        line.orientation = simd_quatf(angle: angle, axis: [0, 1, 0])

        // Tip sphere — tappable, carries the component
        let tipMesh = MeshResource.generateSphere(radius: 0.045)
        let tip = ModelEntity(mesh: tipMesh, materials: [material])
        // Place at the far end of the line in local space (local +Z = radius/2 from centre)
        tip.position = SIMD3<Float>(0, 0, radius * 0.5)
        tip.name     = name     // same name so handlePan can read it
        tip.generateCollisionShapes(recursive: false)
        tip.components.set(InputTargetComponent())
        tip.components.set(RotationArcComponent(clipID: clipID))
        line.addChild(tip)

        return line
    }

    /// Builds an arc of thin cylinder segments from `startAngle` to `endAngle`.
    static func makeArcCurve(
        from startAngle: Float,
        to endAngle: Float,
        radius: Float,
        steps: Int = 32
    ) -> Entity {
        let container = Entity()
        let material  = UnlitMaterial(color: UIColor.white.withAlphaComponent(0.55))
        let stepCount = max(steps, 4)

        var prevAngle = startAngle
        for i in 1...stepCount {
            let t     = Float(i) / Float(stepCount)
            let angle = startAngle + (endAngle - startAngle) * t

            let p0 = SIMD3<Float>(sin(prevAngle) * radius, 0, cos(prevAngle) * radius)
            let p1 = SIMD3<Float>(sin(angle)     * radius, 0, cos(angle)     * radius)

            let segLen = simd_length(p1 - p0)
            guard segLen > 0.0001 else { prevAngle = angle; continue }

            let seg = ModelEntity(
                mesh:      MeshResource.generateCylinder(height: segLen, radius: 0.006),
                materials: [material]
            )
            seg.position = (p0 + p1) * 0.5
            seg.look(at: p1, from: seg.position, relativeTo: nil)
            container.addChild(seg)

            prevAngle = angle
        }
        return container
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - CanvasViewController: Arc Show / Hide
// ─────────────────────────────────────────────────────────────────────────────

extension CanvasViewController {

    // MARK: Show

    func showRotationArc(for clip: AnimationClip, on entity: Entity) {
        guard clip.track == .rotation else { return }

        // Tear down any existing arc for this clip
        activeRotationArcs[clip.id]?.root.removeFromParent()

        guard let anchor = arView.scene.findEntity(named: "MainAnchor") else { return }

        let visual = RotationArcRenderer.makeArc(clip: clip, entity: entity)
        anchor.addChild(visual.root)
        activeRotationArcs[clip.id] = visual
    }

    // MARK: Hide

    func hideRotationArc(for clipID: UUID) {
        activeRotationArcs[clipID]?.root.removeFromParent()
        activeRotationArcs.removeValue(forKey: clipID)
    }

    func hideAllRotationArcs() {
        activeRotationArcs.values.forEach { $0.root.removeFromParent() }
        activeRotationArcs.removeAll()
    }
}
