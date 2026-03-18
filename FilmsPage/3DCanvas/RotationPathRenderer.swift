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
    var planeAxes: (u: SIMD3<Float>, v: SIMD3<Float>) {
        switch self {
        case .x: return (u: [0, 1, 0], v: [0, 0, 1])   // YZ plane
        case .y: return (u: [1, 0, 0], v: [0, 0, 1])   // XZ plane
        case .z: return (u: [1, 0, 0], v: [0, 1, 0])   // XY plane
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

    static let startShaftColor:  UIColor = UIColor(red: 0.0, green: 0.85, blue: 0.85, alpha: 1)
    static let endShaftColor:    UIColor = UIColor(red: 1.0, green: 0.55, blue: 0.0,  alpha: 1)
    static let startHandleColor: UIColor = UIColor(red: 0.0, green: 0.9,  blue: 0.9,  alpha: 1)
    static let endHandleColor:   UIColor = UIColor(red: 1.0, green: 0.6,  blue: 0.0,  alpha: 1)

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

    static func makeArc(clip: AnimationClip, entity: Entity) -> RotationArcVisual {
        let centre = entity.position(relativeTo: nil)
        let axis   = axisOf(clip)
        let total  = totalRadiansOf(clip)

        let root = Entity()
        root.name     = "RotationArc_\(clip.id)"
        root.position = centre

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

    static func update(visual: RotationArcVisual, clip: AnimationClip, entity: Entity) {
        visual.root.position = entity.position(relativeTo: nil)
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
        simd_quatf(angle: angle, axis: axis.simdAxis)
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
        let mat    = SimpleMaterial(color: color, roughness: 0.2, isMetallic: true)
        let entity = ModelEntity(mesh: mesh, materials: [mat])
        entity.name     = name
        entity.position = circlePoint(angle: angle, axis: axis)

        entity.components.set(CollisionComponent(shapes: [.generateSphere(radius: hitR)]))
        entity.components.set(InputTargetComponent())
        entity.components.set(RotationArcComponent(clipID: clipID, role: role))
        return entity
    }

    private static func makeArcCurve(totalRadians: Float, axis: RotationAxis) -> Entity {
        let container  = Entity()
        container.name = "arcCurve"

        guard abs(totalRadians) > 0.001 else { return container }

        var mat = UnlitMaterial()
        mat.color = .init(tint: UIColor(white: 0.9, alpha: 0.55), texture: nil)

        // Scale step count with total angle so multi-turn arcs are smooth
        let turns = abs(totalRadians) / (2 * .pi)
        let steps = max(baseSteps, Int(turns * Float(baseSteps)))

        var prev: Float = 0
        for i in 1...steps {
            let t     = Float(i) / Float(steps)
            let angle = totalRadians * t
            let p0    = circlePoint(angle: prev,  axis: axis)
            let p1    = circlePoint(angle: angle, axis: axis)
            let len   = simd_length(p1 - p0)
            guard len > 0.0001 else { prev = angle; continue }

            let seg = ModelEntity(
                mesh: .generateCylinder(height: len, radius: arcTube),
                materials: [mat]
            )
            seg.position = (p0 + p1) * 0.5
            seg.look(at: p1, from: seg.position, relativeTo: nil)
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
        let visual = RotationPathRenderer.makeArc(clip: clip, entity: entity)
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

        alert.addAction(UIAlertAction(title: "Edit Timing", style: .default) { [weak self] _ in
            guard let self else { return }
            self.selectedArcClipID = clipID
            if let pos = self.arView.project(arcRoot.position(relativeTo: nil)) {
                self.showRotationTimingToolbar(clipID: clipID, at: pos)
            }
        })

        alert.addAction(UIAlertAction(title: "Edit Rotation", style: .default) { [weak self] _ in
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

    // ── Timing toolbar ────────────────────────────────────────────────────────

    func showRotationTimingToolbar(clipID: UUID, at screenPoint: CGPoint) {
        pathEditToolbar?.removeFromSuperview()
        guard let clipIdx = timeline.clips.firstIndex(where: { $0.id == clipID }) else { return }
        let clip = timeline.clips[clipIdx]

        let container = UIView()
        container.backgroundColor     = UIColor.systemBackground.withAlphaComponent(0.95)
        container.layer.cornerRadius  = 14
        container.layer.shadowColor   = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.25
        container.layer.shadowRadius  = 8
        container.translatesAutoresizingMaskIntoConstraints = false

        func field(_ ph: String, _ v: Float) -> UITextField {
            let f = UITextField()
            f.borderStyle = .roundedRect; f.keyboardType = .decimalPad
            f.placeholder = ph; f.text = String(format: "%.2f", v); return f
        }

        let startF = field("Start Time", clip.startTime)
        let durF   = field("Duration",   clip.duration)
        let applyB = UIButton(type: .system)
        applyB.setTitle("Apply", for: .normal)
        applyB.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)

        let stack = UIStackView(arrangedSubviews: [startF, durF, applyB])
        stack.axis = .vertical; stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack); view.addSubview(container)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            container.centerXAnchor.constraint(equalTo: view.leadingAnchor, constant: screenPoint.x),
            container.bottomAnchor.constraint(equalTo: view.topAnchor, constant: screenPoint.y - 20),
            container.widthAnchor.constraint(equalToConstant: 220),
        ])

        applyB.addAction(UIAction { [weak self] _ in
            guard let self,
                  let ns = Float(startF.text ?? ""),
                  let nd = Float(durF.text ?? ""), nd > 0 else { return }
            let old = self.timeline.clips[clipIdx]
            let upd = AnimationClip(preservingID: old, startTime: ns, duration: nd)
            self.timeline.clips[clipIdx] = upd
            if let vis = self.activeRotationArcs.removeValue(forKey: old.id) {
                vis.startHandle.components.set(RotationArcComponent(clipID: upd.id, role: .start))
                vis.endHandle.components.set(RotationArcComponent(clipID: upd.id, role: .end))
                self.activeRotationArcs[upd.id] = vis
            }
            if self.selectedArcClipID == old.id { self.selectedArcClipID = upd.id }
            self.pathEditToolbar?.removeFromSuperview()
        }, for: .touchUpInside)

        pathEditToolbar = container
    }

    // ── Rotation editor: axis picker + unbounded degrees ─────────────────────

    func presentRotationAnglesEditor(clipID: UUID) {
        guard let clipIdx = timeline.clips.firstIndex(where: { $0.id == clipID }) else { return }
        let clip     = timeline.clips[clipIdx]
        let axis     = RotationPathRenderer.axisOf(clip)
        let totalDeg = RotationPathRenderer.totalRadiansOf(clip) * 180 / .pi

        let alert = UIAlertController(
            title:   "Edit Rotation",
            message: "Positive = counter-clockwise, negative = clockwise.\nValues beyond ±180° supported (e.g. 540 = 1.5 turns).",
            preferredStyle: .alert
        )
        alert.addTextField { f in
            f.placeholder  = "Degrees (e.g. 270, -360, 540)"
            f.keyboardType = .numbersAndPunctuation
            f.text         = String(format: "%.0f", totalDeg)
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Choose Axis →", style: .default) { [weak self] _ in
            guard let self,
                  let text = alert.textFields?.first?.text,
                  let deg  = Float(text) else { return }
            self.presentAxisPicker(clipID: clipID, clipIdx: clipIdx,
                                   totalRadians: deg * (.pi / 180), currentAxis: axis)
        })
        present(alert, animated: true)
    }

    private func presentAxisPicker(clipID: UUID, clipIdx: Int,
                                    totalRadians: Float, currentAxis: RotationAxis) {
        let picker = UIAlertController(title: "Rotation Axis",
                                       message: "Which axis should the entity rotate around?",
                                       preferredStyle: .actionSheet)
        for opt in RotationAxis.allCases {
            let check = opt == currentAxis ? " ✓" : ""
            picker.addAction(UIAlertAction(title: "\(opt.rawValue)-axis\(check)", style: .default) { [weak self] _ in
                self?.applyRotationEdit(clipIdx: clipIdx, clipID: clipID,
                                        axis: opt, totalRadians: totalRadians)
            })
        }
        picker.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(picker, animated: true)
    }

    func applyRotationEdit(clipIdx: Int, clipID: UUID,
                           axis: RotationAxis, totalRadians: Float) {
        let old = timeline.clips[clipIdx]
        let upd = AnimationClip(
            preservingID: old,
            fromValue: axis.simdAxis,
            toValue:   SIMD3<Float>(totalRadians, 0, 0)
        )
        timeline.clips[clipIdx] = upd

        // Rebuild arc visual for new axis/total
        if let ent = arView.scene.findEntity(named: upd.entityName) {
            activeRotationArcs[clipID]?.root.removeFromParent()
            activeRotationArcs.removeValue(forKey: clipID)
            showRotationArc(for: upd, on: ent)
        }
    }
}
