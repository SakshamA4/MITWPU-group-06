import Foundation
import RealityKit
import UIKit
import simd

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Data Model
//
//  fromValue  = SIMD3(axisX, axisY, axisZ)   — normalised rotation axis
//  toValue.x  = totalRadians                  — unbounded signed float
//                                               positive = CCW around axis
//                                               negative = CW  around axis
//                                               can exceed ±2π (multi-turn)
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - RotationArcComponent
// ─────────────────────────────────────────────────────────────────────────────

struct RotationArcComponent: Component {
    enum Role { case start, end }
    let clipID: UUID
    let role:   Role
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - RotationAxis
// ─────────────────────────────────────────────────────────────────────────────

enum RotationAxis: String, CaseIterable {
    case x = "X"
    case y = "Y"
    case z = "Z"

    var simdAxis: SIMD3<Float> {
        switch self {
        case .x: return [1, 0, 0]
        case .y: return [0, 1, 0]
        case .z: return [0, 0, 1]
        }
    }

    /// Two vectors spanning the plane perpendicular to this axis.
    /// The sign of u determines the positive drag direction on the disc.
    /// v determines where angle=0 sits — pointing v upward makes the start arm
    /// "stand" vertically, which is more intuitive than lying flat.
    var planeAxes: (u: SIMD3<Float>, v: SIMD3<Float>) {
        switch self {
        case .x: return (u: [0,  0,  1], v: [0,  1,  0])  // YZ plane — v=+Y stands up, u=+Z matches arc direction
        case .y: return (u: [1,  0,  0], v: [0,  0,  1])  // XZ plane
        case .z: return (u: [-1, 0,  0], v: [0,  1,  0])  // XY plane — v=+Y so start arm stands up
        }
    }

    var planeNormal: SIMD3<Float> { simdAxis }

    /// Initialise from a stored axis vector (tolerant of non-unit vectors)
    static func from(simd axis: SIMD3<Float>) -> RotationAxis {
        if abs(axis.x) > 0.5 { return .x }
        if abs(axis.z) > 0.5 { return .z }
        return .y
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - RotationArcVisual
// ─────────────────────────────────────────────────────────────────────────────

struct RotationArcVisual {
    let root:        Entity
    let startHandle: ModelEntity
    let endHandle:   ModelEntity
    let axis:        RotationAxis
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - RotationPathRenderer
// ─────────────────────────────────────────────────────────────────────────────

enum RotationPathRenderer {

    static  let arcRadius:         Float = 0.6
    private static let shaftWidth: Float = 0.012
    private static let handleR:    Float = 0.055
    private static let hitR:       Float = 0.15
    private static let arcTube:    Float = 0.008
    private static let baseSteps:  Int   = 64

    // Start = black/dark (fixed reference, not draggable)
    // End   = orange     (draggable)
    static let startShaftColor:  UIColor = UIColor(white: 0.25, alpha: 1)
    static let endShaftColor:    UIColor = UIColor(red: 1.0, green: 0.55, blue: 0.0, alpha: 1)
    static let startHandleColor: UIColor = UIColor(white: 0.20, alpha: 1)
    static let endHandleColor:   UIColor = UIColor(red: 1.0, green: 0.6,  blue: 0.0, alpha: 1)

    // ── Clip helpers ──────────────────────────────────────────────────────────

    static func axisOf(_ clip: AnimationClip) -> RotationAxis {
        // New format: fromValue stores the axis vector
        let a = clip.fromValue
        let len = simd_length(a)
        if len > 0.1 {
            return RotationAxis.from(simd: a)
        }
        // Legacy format: fromValue was (0, fromAngle, 0), toValue was (0, toAngle, 0)
        return .y
    }

    static func totalRadiansOf(_ clip: AnimationClip) -> Float {
        let a = clip.fromValue
        let len = simd_length(a)
        if len > 0.1 {
            // New format: toValue.x holds total radians
            return clip.toValue.x
        }
        // Legacy format: return the difference between to and from angles
        return clip.toValue.y - clip.fromValue.y
    }

    // ── Build ─────────────────────────────────────────────────────────────────

    static func makeArc(clip: AnimationClip, entity: Entity, anchor: Entity) -> RotationArcVisual {
        // Position the arc root at the entity's position expressed in anchor-local space.
        // We must NOT use entity.position(relativeTo: nil) (world) and assign it to a
        // child of anchor, because if anchor is not at world-origin the arc will be wrong.
        let centreLocal = entity.position(relativeTo: anchor)
        let axis        = axisOf(clip)
        let total       = totalRadiansOf(clip)

        let root = Entity()
        root.name     = "RotationArc_\(clip.id)"
        root.position = centreLocal   // anchor-local

        root.addChild(makeShaft(name: "startLine", angle: 0,     axis: axis, color: startShaftColor))
        root.addChild(makeShaft(name: "endLine",   angle: total, axis: axis, color: endShaftColor))
        root.addChild(makeArcCurve(totalRadians: total, axis: axis))

        let sh = makeHandle(name: "arcHandle.start", angle: 0,
                            axis: axis, color: startHandleColor, clipID: clip.id, role: .start)
        let eh = makeHandle(name: "arcHandle.end",   angle: total,
                            axis: axis, color: endHandleColor,   clipID: clip.id, role: .end)
        root.addChild(sh)
        root.addChild(eh)

        return RotationArcVisual(root: root, startHandle: sh, endHandle: eh, axis: axis)
    }

    // ── Full redraw after programmatic change ─────────────────────────────────

    static func update(visual: RotationArcVisual, clip: AnimationClip,
                       entity: Entity, anchor: Entity) {
        visual.root.position = entity.position(relativeTo: anchor)
        let total = totalRadiansOf(clip)
        applyTotal(visual: visual, totalRadians: total)
    }

    // ── Live drag: move end handle + shaft + rebuild arc ─────────────────────

    static func updateEndAngle(visual: RotationArcVisual, totalRadians: Float) {
        // Move end shaft
        if let shaft = visual.root.findEntity(named: "endLine") {
            shaft.orientation = shaftOrientation(angle: totalRadians, axis: visual.axis)
        }
        // Move end handle sphere
        if let handle = visual.root.findEntity(named: "arcHandle.end") {
            handle.position = circlePoint(angle: totalRadians, axis: visual.axis)
        }
        // Rebuild arc
        visual.root.findEntity(named: "arcCurve")?.removeFromParent()
        visual.root.addChild(makeArcCurve(totalRadians: totalRadians, axis: visual.axis))
    }

    // ── Deprecated legacy entry point (kept for any callers outside drag) ─────
    static func updateArcCurveOnly(visual: RotationArcVisual,
                                   fromAngle: Float, toAngle: Float) {
        updateEndAngle(visual: visual, totalRadians: toAngle - fromAngle)
    }

    // ── Point on circle ───────────────────────────────────────────────────────

    static func circlePoint(angle: Float, axis: RotationAxis) -> SIMD3<Float> {
        let (u, v) = axis.planeAxes
        return (u * sin(angle) + v * cos(angle)) * arcRadius
    }

    /// Project a world point onto the gizmo disc, return its angle
    static func angleOnDisc(worldPoint: SIMD3<Float>,
                             arcCentre: SIMD3<Float>,
                             axis: RotationAxis) -> Float {
        let (u, v) = axis.planeAxes
        let local  = worldPoint - arcCentre
        let pu     = simd_dot(local, u)
        let pv     = simd_dot(local, v)
        return atan2(pu, pv)
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private static func applyTotal(visual: RotationArcVisual, totalRadians: Float) {
        visual.root.findEntity(named: "startLine")?.orientation =
            shaftOrientation(angle: 0, axis: visual.axis)
        visual.root.findEntity(named: "endLine")?.orientation =
            shaftOrientation(angle: totalRadians, axis: visual.axis)

        visual.root.findEntity(named: "arcHandle.start")?.position =
            circlePoint(angle: 0,            axis: visual.axis)
        visual.root.findEntity(named: "arcHandle.end")?.position =
            circlePoint(angle: totalRadians, axis: visual.axis)

        visual.root.findEntity(named: "arcCurve")?.removeFromParent()
        visual.root.addChild(makeArcCurve(totalRadians: totalRadians, axis: visual.axis))
    }

    private static func shaftOrientation(angle: Float, axis: RotationAxis) -> simd_quatf {
        // The shaft box geometry lies along local +Z (box centred at (0,0,r/2)).
        // We need to rotate +Z to point toward circlePoint(angle, axis).
        // circlePoint = u*sin(angle) + v*cos(angle)  where (u,v) are the plane axes.
        // At angle=0 the point is along +v.  At angle=π/2 it's along +u.
        //
        // Strategy: build the rotation that takes +Z to the target direction.
        let target = simd_normalize(circlePoint(angle: angle, axis: axis))
        let from   = SIMD3<Float>(0, 0, 1)   // +Z
        // If target ≈ +Z already, return identity
        let dot = simd_dot(from, target)
        if dot > 0.9999 { return simd_quatf(ix: 0, iy: 0, iz: 0, r: 1) }
        // If target ≈ −Z, rotate 180° around any perpendicular axis
        if dot < -0.9999 { return simd_quatf(angle: .pi, axis: [0, 1, 0]) }
        return simd_quatf(from: from, to: target)
    }

    private static func makeShaft(name: String, angle: Float,
                                   axis: RotationAxis, color: UIColor) -> Entity {
        let mat  = UnlitMaterial(color: color)
        let mesh = MeshResource.generateBox(size: SIMD3<Float>(shaftWidth, shaftWidth, arcRadius))
        let box  = ModelEntity(mesh: mesh, materials: [mat])
        box.position = SIMD3<Float>(0, 0, arcRadius * 0.5)

        let wrapper         = Entity()
        wrapper.name        = name
        wrapper.orientation = shaftOrientation(angle: angle, axis: axis)
        wrapper.addChild(box)
        return wrapper
    }

    private static func makeHandle(name: String, angle: Float,
                                    axis: RotationAxis, color: UIColor,
                                    clipID: UUID, role: RotationArcComponent.Role) -> ModelEntity {
        let mesh   = MeshResource.generateSphere(radius: handleR)
        // Start handle uses a flat/matte material to reinforce "not interactive"
        let isStart = role == .start
        let mat: Material = isStart
            ? UnlitMaterial(color: color)
            : SimpleMaterial(color: color, roughness: 0.2, isMetallic: true)
        let entity = ModelEntity(mesh: mesh, materials: [mat])
        entity.name     = name
        entity.position = circlePoint(angle: angle, axis: axis)

        // Only the end handle is draggable — start handle has no collision or input
        if !isStart {
            entity.components.set(CollisionComponent(shapes: [.generateSphere(radius: hitR)]))
            entity.components.set(InputTargetComponent())
            entity.components.set(RotationArcComponent(clipID: clipID, role: role))
        }
        return entity
    }

    private static func makeArcCurve(totalRadians: Float, axis: RotationAxis) -> Entity {
        let container  = Entity()
        container.name = "arcCurve"

        guard abs(totalRadians) > 0.001 else { return container }

        var mat = UnlitMaterial()
        mat.color = .init(tint: UIColor(white: 0.9, alpha: 0.55), texture: nil)

        let turns = abs(totalRadians) / (2 * .pi)
        let steps = max(baseSteps, Int(turns * Float(baseSteps)))

        var prev: Float = 0
        for i in 1...steps {
            let t     = Float(i) / Float(steps)
            let angle = totalRadians * t
            let p0    = circlePoint(angle: prev,  axis: axis)
            let p1    = circlePoint(angle: angle, axis: axis)
            let diff  = p1 - p0
            let len   = simd_length(diff)
            guard len > 0.0001 else { prev = angle; continue }

            let seg = ModelEntity(
                mesh: .generateCylinder(height: len, radius: arcTube),
                materials: [mat]
            )
            // Place at midpoint in parent-local space
            seg.position = (p0 + p1) * 0.5

            // Orient the cylinder (default along Y) to point from p0 to p1.
            // All positions are in arcRoot-local space so we compute the
            // quaternion purely from the direction vector — no world-space ambiguity.
            let dir = simd_normalize(diff)
            let up  = SIMD3<Float>(0, 1, 0)   // cylinder default axis
            let dot = simd_dot(up, dir)
            if dot > 0.9999 {
                seg.orientation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
            } else if dot < -0.9999 {
                seg.orientation = simd_quatf(angle: .pi, axis: [1, 0, 0])
            } else {
                seg.orientation = simd_quatf(from: up, to: dir)
            }

            container.addChild(seg)
            prev = angle
        }
        return container
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - CanvasViewController: show / hide / menus
// ─────────────────────────────────────────────────────────────────────────────

extension CanvasViewController {
    
    func showRotationArc(for clip: AnimationClip, on entity: Entity) {
        guard clip.track == .rotation else { return }
        activeRotationArcs[clip.id]?.root.removeFromParent()
        guard let anchor = arView.scene.findEntity(named: "MainAnchor") else { return }
        let visual = RotationPathRenderer.makeArc(clip: clip, entity: entity, anchor: anchor)
        anchor.addChild(visual.root)
        activeRotationArcs[clip.id] = visual
    }
    
    func hideRotationArc(for clipID: UUID) {
        activeRotationArcs[clipID]?.root.removeFromParent()
        activeRotationArcs.removeValue(forKey: clipID)
    }
    
    func hideAllRotationArcs() {
        for (_, visual) in activeRotationArcs { visual.root.isEnabled = false }
    }
    
    func showAllRotationArcs() {
        for (_, visual) in activeRotationArcs { visual.root.isEnabled = true }
    }
    
    // ── Context menu ──────────────────────────────────────────────────────────
    
    func showRotationArcContextMenu(clipID: UUID, arcRoot: Entity) {
        guard let clipIdx = timeline.clips.firstIndex(where: { $0.id == clipID }) else { return }
        let alert = UIAlertController(title: "Rotation Animation", message: nil,
                                      preferredStyle: .actionSheet)
        
        // Single "Edit Animation" entry opens the full card (timing + degrees + axis)
        alert.addAction(UIAlertAction(title: "Edit Animation", style: .default) { [weak self] _ in
            self?.presentRotationAnglesEditor(clipID: clipID)
        })
        
        let locked = arcRoot.components[LockComponent.self]?.isLocked ?? false
        alert.addAction(UIAlertAction(title: locked ? "Unlock" : "Lock", style: .default) { _ in
            var lc = arcRoot.components[LockComponent.self] ?? LockComponent(isLocked: false)
            lc.isLocked.toggle()
            arcRoot.components.set(lc)
        })
        
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self else { return }
            self.hideRotationArc(for: clipID)
            self.timeline.clips.remove(at: clipIdx)
            self.selectedArcClipID = nil
            self.refreshSidebarContent()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    // ── Full rotation editor: timing + degrees + axis in one card ─────────────
    
    func presentRotationAnglesEditor(clipID: UUID) {
        guard let clipIdx = timeline.clips.firstIndex(where: { $0.id == clipID }) else { return }
        let clip     = timeline.clips[clipIdx]
        let axis     = RotationPathRenderer.axisOf(clip)
        let totalDeg = RotationPathRenderer.totalRadiansOf(clip) * 180 / .pi
        
        let card = AnimationInputCard(mode: .editRotateFull(
            currentStart:    clip.startTime,
            currentDuration: clip.duration,
            currentDegrees:  totalDeg,
            currentAxis:     axis
        ))
        
        card.onConfirm = { [weak self] startTime, duration, degrees, chosenAxis in
            guard let self else { return }
            self.applyFullRotationEdit(
                clipIdx:      clipIdx,
                clipID:       clipID,
                startTime:    startTime,
                duration:     duration,
                axis:         chosenAxis,
                totalRadians: degrees * (.pi / 180)
            )
        }
        present(card, animated: false)
    }
    
    func applyFullRotationEdit(clipIdx: Int, clipID: UUID,
                               startTime: Float, duration: Float,
                               axis: RotationAxis, totalRadians: Float) {
        let old = timeline.clips[clipIdx]
        let upd = AnimationClip(
            preservingID: old,
            fromValue:  axis.simdAxis,
            toValue:    SIMD3<Float>(totalRadians, 0, 0),
            startTime:  startTime,
            duration:   duration
        )
        timeline.clips[clipIdx] = upd
        
        // Re-key arc visual handles if clip UUID changed (preservingID keeps it)
        // Rebuild arc to reflect any axis/angle change
        if let ent = arView.scene.findEntity(named: upd.entityName) {
            activeRotationArcs[clipID]?.root.removeFromParent()
            activeRotationArcs.removeValue(forKey: clipID)
            showRotationArc(for: upd, on: ent)
        }
    }
    
    func applyRotationEdit(clipIdx: Int, clipID: UUID,
                           axis: RotationAxis, totalRadians: Float) {
        applyFullRotationEdit(clipIdx: clipIdx, clipID: clipID,
                              startTime: timeline.clips[clipIdx].startTime,
                              duration:  timeline.clips[clipIdx].duration,
                              axis: axis, totalRadians: totalRadians)
    }
}
