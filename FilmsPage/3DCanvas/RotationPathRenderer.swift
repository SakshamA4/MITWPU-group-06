import Foundation
import RealityKit
import UIKit

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - RotationArcComponent
//
// Attached to every tappable handle sphere.
// Mirrors MotionPathHandleComponent exactly — same tap/drag pipeline.
// ─────────────────────────────────────────────────────────────────────────────

struct RotationArcComponent: Component {
    enum Role { case start, end }
    let clipID: UUID
    let role:   Role
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - RotationArcVisual
// ─────────────────────────────────────────────────────────────────────────────

struct RotationArcVisual {
    let root:        Entity
    let startHandle: ModelEntity   // orange sphere — RotationArcComponent(.start)
    let endHandle:   ModelEntity   // blue   sphere — RotationArcComponent(.end)
    var arcCurve:    Entity
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - RotationPathRenderer
// ─────────────────────────────────────────────────────────────────────────────

enum RotationPathRenderer {

    static let arcRadius: Float  = 0.55
    private static let lineWidth: Float  = 0.008
    private static let tipRadius: Float  = 0.06    // big enough to tap reliably
    private static let arcSteps:  Int    = 40

    // ── Public API ────────────────────────────────────────────────────────────

    static func makeArc(clip: AnimationClip, entity: Entity) -> RotationArcVisual {
        let centre = entity.position(relativeTo: nil)

        let root = Entity()
        root.name     = "RotationArc_\(clip.id)"
        root.position = centre

        let fromAngle = clip.fromValue.y
        let toAngle   = clip.toValue.y

        let (startLine, startTip) = makeLine(angle: fromAngle, color: .systemOrange,
                                             clipID: clip.id, role: .start)
        root.addChild(startLine)

        let (endLine, endTip) = makeLine(angle: toAngle, color: .systemBlue,
                                         clipID: clip.id, role: .end)
        root.addChild(endLine)

        let arc = makeArcCurve(from: fromAngle, to: toAngle)
        arc.name = "arcCurve"
        root.addChild(arc)

        return RotationArcVisual(root: root, startHandle: startTip, endHandle: endTip, arcCurve: arc)
    }

    /// Full update — repositions root, rotates both arms, rebuilds arc curve.
    /// Call this when an arc is shown fresh or when angles change from outside dragging
    /// (e.g. the angles editor).
    static func update(visual: RotationArcVisual, clip: AnimationClip, entity: Entity) {
        let fromAngle = clip.fromValue.y
        let toAngle   = clip.toValue.y

        // Keep root centred on the entity
        visual.root.position = entity.position(relativeTo: nil)

        // Rotate arms to match stored angles
        for child in visual.root.children {
            switch child.name {
            case "startLine": child.orientation = simd_quatf(angle: fromAngle, axis: [0, 1, 0])
            case "endLine":   child.orientation = simd_quatf(angle: toAngle,   axis: [0, 1, 0])
            default: break
            }
        }

        // Rebuild arc curve — remove old by name so stale references don't matter
        visual.root.findEntity(named: "arcCurve")?.removeFromParent()
        let newArc = makeArcCurve(from: fromAngle, to: toAngle)
        newArc.name = "arcCurve"
        visual.root.addChild(newArc)
    }

    /// Lightweight update during live drag — ONLY rebuilds the arc curve.
    /// Arms are already rotated by the drag handler directly; don't re-rotate them.
    static func updateArcCurveOnly(visual: RotationArcVisual, fromAngle: Float, toAngle: Float) {
        visual.root.findEntity(named: "arcCurve")?.removeFromParent()
        let newArc = makeArcCurve(from: fromAngle, to: toAngle)
        newArc.name = "arcCurve"
        visual.root.addChild(newArc)
    }

    // ── Private geometry ──────────────────────────────────────────────────────

    /// Returns (lineRoot, tipSphere).
    /// lineRoot is rotated to `angle` around Y so its local +Z points along the arm.
    /// tipSphere sits at local Z = arcRadius on lineRoot, carries RotationArcComponent.
    private static func makeLine(
        angle: Float, color: UIColor, clipID: UUID, role: RotationArcComponent.Role
    ) -> (lineRoot: Entity, tip: ModelEntity) {

        let mat      = UnlitMaterial(color: color)
        let lineName = role == .start ? "startLine" : "endLine"
        let tipName  = role == .start ? "arcHandle.start" : "arcHandle.end"

        let lineRoot = Entity()
        lineRoot.name        = lineName
        lineRoot.orientation = simd_quatf(angle: angle, axis: [0, 1, 0])

        // Shaft — thin box centred halfway along the arm
        let shaft = ModelEntity(
            mesh:      .generateBox(size: SIMD3<Float>(lineWidth, lineWidth, arcRadius)),
            materials: [mat]
        )
        shaft.position = SIMD3<Float>(0, 0, arcRadius * 0.5)
        lineRoot.addChild(shaft)

        // Tip sphere at the end of the arm — LARGE collision for easy tapping
        let tip = ModelEntity(
            mesh:      .generateSphere(radius: tipRadius),
            materials: [mat]
        )
        tip.name     = tipName
        tip.position = SIMD3<Float>(0, 0, arcRadius)
        // Large collision shape so hitTest reliably finds it
        tip.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.12)]))
        tip.components.set(InputTargetComponent())
        tip.components.set(RotationArcComponent(clipID: clipID, role: role))
        lineRoot.addChild(tip)

        return (lineRoot, tip)
    }

    private static func makeArcCurve(from startAngle: Float, to endAngle: Float) -> Entity {
        let container = Entity()
        let mat   = UnlitMaterial(color: UIColor.white.withAlphaComponent(0.5))
        let steps = max(arcSteps, 4)
        var prev  = startAngle

        for i in 1...steps {
            let t     = Float(i) / Float(steps)
            let angle = startAngle + (endAngle - startAngle) * t
            let p0    = SIMD3<Float>(sin(prev)  * arcRadius, 0, cos(prev)  * arcRadius)
            let p1    = SIMD3<Float>(sin(angle) * arcRadius, 0, cos(angle) * arcRadius)
            let len   = simd_length(p1 - p0)
            guard len > 0.0001 else { prev = angle; continue }
            let seg   = ModelEntity(mesh: .generateCylinder(height: len, radius: 0.005), materials: [mat])
            seg.position = (p0 + p1) * 0.5
            seg.look(at: p1, from: seg.position, relativeTo: nil)
            container.addChild(seg)
            prev = angle
        }
        return container
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - CanvasViewController: arc show / hide / menus
// ─────────────────────────────────────────────────────────────────────────────

extension CanvasViewController {

    // MARK: Show / Hide

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
        activeRotationArcs.values.forEach { $0.root.removeFromParent() }
        activeRotationArcs.removeAll()
    }

    // MARK: Long-press context menu  (mirrors showPathContextMenu)

    func showRotationArcContextMenu(clipID: UUID, arcRoot: Entity) {
        guard let clipIdx = timeline.clips.firstIndex(where: { $0.id == clipID }) else { return }

        let alert = UIAlertController(title: "Rotation Animation", message: nil, preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Edit Timing", style: .default) { [weak self] _ in
            guard let self else { return }
            self.selectedArcClipID = clipID
            if let screenPos = self.arView.project(arcRoot.position(relativeTo: nil)) {
                self.showRotationTimingToolbar(clipID: clipID, at: screenPos)
            }
        })

        alert.addAction(UIAlertAction(title: "Edit Angles", style: .default) { [weak self] _ in
            self?.presentRotationAnglesEditor(clipID: clipID)
        })

        let isLocked = arcRoot.components[LockComponent.self]?.isLocked ?? false
        alert.addAction(UIAlertAction(title: isLocked ? "Unlock" : "Lock", style: .default) { _ in
            var lock = arcRoot.components[LockComponent.self] ?? LockComponent(isLocked: false)
            lock.isLocked.toggle()
            arcRoot.components.set(lock)
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

    // MARK: Timing toolbar

    func showRotationTimingToolbar(clipID: UUID, at screenPoint: CGPoint) {
        pathEditToolbar?.removeFromSuperview()
        guard let clipIdx = timeline.clips.firstIndex(where: { $0.id == clipID }) else { return }
        let clip = timeline.clips[clipIdx]

        let container = UIView()
        container.backgroundColor         = UIColor.systemBackground.withAlphaComponent(0.95)
        container.layer.cornerRadius      = 14
        container.layer.shadowColor       = UIColor.black.cgColor
        container.layer.shadowOpacity     = 0.25
        container.layer.shadowRadius      = 8
        container.translatesAutoresizingMaskIntoConstraints = false

        func field(_ placeholder: String, _ value: Float) -> UITextField {
            let f = UITextField()
            f.borderStyle = .roundedRect; f.keyboardType = .decimalPad
            f.placeholder = placeholder; f.text = String(format: "%.2f", value)
            return f
        }
        let startField    = field("Start Time", clip.startTime)
        let durationField = field("Duration",   clip.duration)

        let applyBtn = UIButton(type: .system)
        applyBtn.setTitle("Apply", for: .normal)
        applyBtn.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)

        let stack = UIStackView(arrangedSubviews: [startField, durationField, applyBtn])
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

        applyBtn.addAction(UIAction { [weak self] _ in
            guard let self,
                  let newStart    = Float(startField.text ?? ""),
                  let newDuration = Float(durationField.text ?? ""),
                  newDuration > 0 else { return }

            let old = self.timeline.clips[clipIdx]
            let updated = AnimationClip(entityName: old.entityName, type: old.type, track: old.track,
                                        easing: old.easing, startTime: newStart, duration: newDuration,
                                        fromValue: old.fromValue, toValue: old.toValue, motionPath: old.motionPath)
            self.timeline.clips[clipIdx] = updated

            let newID = updated.id
            if let visual = self.activeRotationArcs.removeValue(forKey: old.id) {
                visual.startHandle.components.set(RotationArcComponent(clipID: newID, role: .start))
                visual.endHandle.components.set(RotationArcComponent(clipID: newID, role: .end))
                self.activeRotationArcs[newID] = visual
            }
            if self.selectedArcClipID == old.id { self.selectedArcClipID = newID }
            self.pathEditToolbar?.removeFromSuperview()
        }, for: .touchUpInside)

        pathEditToolbar = container
    }

    // MARK: Angles editor

    func presentRotationAnglesEditor(clipID: UUID) {
        guard let clipIdx = timeline.clips.firstIndex(where: { $0.id == clipID }) else { return }
        let clip = timeline.clips[clipIdx]
        let toDeg: (Float) -> String = { String(format: "%.0f", $0 * 180 / .pi) }

        let alert = UIAlertController(title: "Edit Rotation Angles", message: "Y-axis rotation in degrees", preferredStyle: .alert)
        alert.addTextField { f in f.placeholder = "Start angle (°)"; f.keyboardType = .numbersAndPunctuation; f.text = toDeg(clip.fromValue.y) }
        alert.addTextField { f in f.placeholder = "End angle (°)";   f.keyboardType = .numbersAndPunctuation; f.text = toDeg(clip.toValue.y)   }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Apply", style: .default) { [weak self] _ in
            guard let self,
                  let startDeg = Float(alert.textFields?[0].text ?? ""),
                  let endDeg   = Float(alert.textFields?[1].text ?? "") else { return }
            let toRad: Float = .pi / 180
            let old = self.timeline.clips[clipIdx]
            let updated = AnimationClip(entityName: old.entityName, type: old.type, track: old.track,
                                        easing: old.easing, startTime: old.startTime, duration: old.duration,
                                        fromValue: SIMD3<Float>(0, startDeg * toRad, 0),
                                        toValue:   SIMD3<Float>(0, endDeg   * toRad, 0),
                                        motionPath: old.motionPath)
            self.timeline.clips[clipIdx] = updated
            if let visual = self.activeRotationArcs[clipID],
               let entity = self.arView.scene.findEntity(named: updated.entityName) {
                RotationPathRenderer.update(visual: visual, clip: updated, entity: entity)
            }
        })
        present(alert, animated: true)
    }
}
