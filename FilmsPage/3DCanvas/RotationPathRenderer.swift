import Foundation
import RealityKit
import UIKit

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - RotationArcComponent
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
    let root:        Entity       // "RotationArc_<uuid>", parented to MainAnchor
    let startHandle: ModelEntity  // handle at fromAngle
    let endHandle:   ModelEntity  // handle at toAngle
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - RotationPathRenderer
//
// Visual layout (matches reference screenshot):
//
//   arcRoot  (at entity world centre, child of MainAnchor)
//     ├── "startLine"   — teal/cyan shaft from centre → start handle
//     ├── "endLine"     — orange/yellow shaft from centre → end handle
//     ├── startHandle   — teal  sphere at (sin(fromAngle)*r, 0, cos(fromAngle)*r)
//     ├── endHandle     — orange sphere at (sin(toAngle)*r,   0, cos(toAngle)*r)
//     └── "arcCurve"    — semi-transparent tube arc between the two angles
//
// Handles are DIRECT children of arcRoot (same pattern as MotionPathVisual).
// Dragging is radial-only: the pan handler projects the finger position onto
// the XZ plane at arcRoot.y, computes atan2 to get a new angle, snaps the
// handle back onto the circle, and rotates the shaft wrapper to match.
// ─────────────────────────────────────────────────────────────────────────────

enum RotationPathRenderer {

    // ── Geometry constants ────────────────────────────────────────────────────
    static  let arcRadius:         Float = 0.6
    private static let shaftWidth: Float = 0.012
    private static let handleR:    Float = 0.055   // visual sphere radius
    private static let hitR:       Float = 0.15    // collision sphere radius (fat, easy to tap)
    private static let arcTube:    Float = 0.008
    private static let arcSteps:   Int   = 64

    // Shaft colours — clearly distinct so the user can tell start from end
    static let startShaftColor: UIColor = UIColor(red: 0.0,  green: 0.85, blue: 0.85, alpha: 1)  // teal / cyan
    static let endShaftColor:   UIColor = UIColor(red: 1.0,  green: 0.55, blue: 0.0,  alpha: 1)  // orange

    // Handle colours — match their shaft
    static let startHandleColor: UIColor = UIColor(red: 0.0,  green: 0.9,  blue: 0.9,  alpha: 1)  // bright teal
    static let endHandleColor:   UIColor = UIColor(red: 1.0,  green: 0.6,  blue: 0.0,  alpha: 1)  // orange

    // ── Public: build ─────────────────────────────────────────────────────────

    static func makeArc(clip: AnimationClip, entity: Entity) -> RotationArcVisual {
        let centre = entity.position(relativeTo: nil)

        let root = Entity()
        root.name     = "RotationArc_\(clip.id)"
        root.position = centre

        let fromAngle = clip.fromValue.y
        let toAngle   = clip.toValue.y

        // Shaft lines
        root.addChild(makeShaft(name: "startLine", angle: fromAngle, color: startShaftColor))
        root.addChild(makeShaft(name: "endLine",   angle: toAngle,   color: endShaftColor))

        // Arc curve between the two angles
        root.addChild(makeArcCurve(from: fromAngle, to: toAngle))

        // Draggable handles — direct children of root
        let startHandle = makeHandle(
            name:   "arcHandle.start",
            angle:  fromAngle,
            color:  startHandleColor,
            clipID: clip.id,
            role:   .start
        )
        let endHandle = makeHandle(
            name:   "arcHandle.end",
            angle:  toAngle,
            color:  endHandleColor,
            clipID: clip.id,
            role:   .end
        )
        root.addChild(startHandle)
        root.addChild(endHandle)

        return RotationArcVisual(root: root, startHandle: startHandle, endHandle: endHandle)
    }

    // ── Public: full redraw after programmatic angle change ───────────────────

    static func update(visual: RotationArcVisual, clip: AnimationClip, entity: Entity) {
        visual.root.position = entity.position(relativeTo: nil)
        applyAngles(visual: visual, fromAngle: clip.fromValue.y, toAngle: clip.toValue.y)
    }

    // ── Public: live drag — only rebuilds the arc curve ───────────────────────

    static func updateArcCurveOnly(visual: RotationArcVisual,
                                   fromAngle: Float, toAngle: Float) {
        visual.root.findEntity(named: "arcCurve")?.removeFromParent()
        visual.root.addChild(makeArcCurve(from: fromAngle, to: toAngle))
    }

    // ── Public: reposition one handle + its shaft to a new angle ─────────────
    //  Called every frame during a drag.

    static func setHandleAngle(_ angle: Float,
                               role: RotationArcComponent.Role,
                               visual: RotationArcVisual) {
        let handleName = role == .start ? "arcHandle.start" : "arcHandle.end"
        let shaftName  = role == .start ? "startLine"       : "endLine"

        // Snap handle sphere to circle
        if let handle = visual.root.findEntity(named: handleName) {
            handle.position = circlePoint(angle: angle)
        }
        // Rotate the shaft wrapper so the box points toward the handle
        if let shaft = visual.root.findEntity(named: shaftName) {
            shaft.orientation = simd_quatf(angle: angle, axis: [0, 1, 0])
        }
    }

    // ── Public: world-space point on the circle ───────────────────────────────
    //  Used by the drag handler to snap the handle back onto the circle after
    //  the finger moves freely.

    static func circlePoint(angle: Float) -> SIMD3<Float> {
        SIMD3<Float>(sin(angle) * arcRadius, 0, cos(angle) * arcRadius)
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    private static func applyAngles(visual: RotationArcVisual,
                                    fromAngle: Float, toAngle: Float) {
        // Shaft orientations
        visual.root.findEntity(named: "startLine")?.orientation =
            simd_quatf(angle: fromAngle, axis: [0, 1, 0])
        visual.root.findEntity(named: "endLine")?.orientation =
            simd_quatf(angle: toAngle,   axis: [0, 1, 0])

        // Handle positions on circle
        visual.root.findEntity(named: "arcHandle.start")?.position = circlePoint(angle: fromAngle)
        visual.root.findEntity(named: "arcHandle.end")?.position   = circlePoint(angle: toAngle)

        // Rebuild arc between new angles
        visual.root.findEntity(named: "arcCurve")?.removeFromParent()
        visual.root.addChild(makeArcCurve(from: fromAngle, to: toAngle))
    }

    // ── Shaft: thin coloured box from centre → circle edge ───────────────────
    //
    //  The box's geometry is centred at origin, half-length = arcRadius/2, so
    //  the box spans [0 … arcRadius] along +Z before rotation.  We place it at
    //  (0, 0, arcRadius*0.5) in the wrapper's local space, then rotate the
    //  wrapper to aim toward `angle`.

    private static func makeShaft(name: String, angle: Float, color: UIColor) -> Entity {
        let mat  = UnlitMaterial(color: color)
        let mesh = MeshResource.generateBox(
            size: SIMD3<Float>(shaftWidth, shaftWidth, arcRadius)
        )
        let box       = ModelEntity(mesh: mesh, materials: [mat])
        box.position  = SIMD3<Float>(0, 0, arcRadius * 0.5)   // centre the box along +Z

        let wrapper       = Entity()
        wrapper.name      = name
        wrapper.orientation = simd_quatf(angle: angle, axis: [0, 1, 0])
        wrapper.addChild(box)
        return wrapper
    }

    // ── Handle: coloured sphere with collision, on the circle ─────────────────

    private static func makeHandle(
        name:   String,
        angle:  Float,
        color:  UIColor,
        clipID: UUID,
        role:   RotationArcComponent.Role
    ) -> ModelEntity {
        let mesh     = MeshResource.generateSphere(radius: handleR)
        let material = SimpleMaterial(color: color, roughness: 0.2, isMetallic: true)
        let entity   = ModelEntity(mesh: mesh, materials: [material])
        entity.name  = name
        entity.position = circlePoint(angle: angle)

        // Fat collision shape so it's easy to tap / drag
        entity.components.set(
            CollisionComponent(shapes: [.generateSphere(radius: hitR)])
        )
        entity.components.set(InputTargetComponent())
        entity.components.set(RotationArcComponent(clipID: clipID, role: role))

        return entity
    }

    // ── Arc curve: tube swept between fromAngle and toAngle ──────────────────

    private static func makeArcCurve(from startAngle: Float, to endAngle: Float) -> Entity {
        let container  = Entity()
        container.name = "arcCurve"

        // Semi-transparent fill to show the swept region
        var mat = UnlitMaterial()
        mat.color = .init(tint: UIColor(white: 0.9, alpha: 0.55), texture: nil)

        var prev = startAngle

        for i in 1...arcSteps {
            let t     = Float(i) / Float(arcSteps)
            let angle = startAngle + (endAngle - startAngle) * t
            let p0    = circlePoint(angle: prev)
            let p1    = circlePoint(angle: angle)
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
        // Remove any previous visual for this clip before creating a new one
        activeRotationArcs[clip.id]?.root.removeFromParent()
        guard let anchor = arView.scene.findEntity(named: "MainAnchor") else { return }
        let visual = RotationPathRenderer.makeArc(clip: clip, entity: entity)
        anchor.addChild(visual.root)
        activeRotationArcs[clip.id] = visual
    }

    /// Permanently removes a single arc (e.g. user deletes the clip).
    func hideRotationArc(for clipID: UUID) {
        activeRotationArcs[clipID]?.root.removeFromParent()
        activeRotationArcs.removeValue(forKey: clipID)
    }

    /// Temporarily hides all arcs during playback — they stay in the scene
    /// tree so showAllRotationArcs() can re-enable them without rebuilding.
    func hideAllRotationArcs() {
        for (_, visual) in activeRotationArcs {
            visual.root.isEnabled = false
        }
    }

    /// Re-shows arcs after playback ends.
    func showAllRotationArcs() {
        for (_, visual) in activeRotationArcs {
            visual.root.isEnabled = true
        }
    }

    // ── Context menu (long-press on arc root or handle) ───────────────────────

    func showRotationArcContextMenu(clipID: UUID, arcRoot: Entity) {
        guard let clipIdx = timeline.clips.firstIndex(where: { $0.id == clipID }) else { return }
        let alert = UIAlertController(
            title: "Rotation Animation",
            message: nil,
            preferredStyle: .actionSheet
        )

        alert.addAction(UIAlertAction(title: "Edit Timing", style: .default) { [weak self] _ in
            guard let self else { return }
            self.selectedArcClipID = clipID
            if let pos = self.arView.project(arcRoot.position(relativeTo: nil)) {
                self.showRotationTimingToolbar(clipID: clipID, at: pos)
            }
        })

        alert.addAction(UIAlertAction(title: "Edit Angles", style: .default) { [weak self] _ in
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
            f.borderStyle  = .roundedRect
            f.keyboardType = .decimalPad
            f.placeholder  = ph
            f.text         = String(format: "%.2f", v)
            return f
        }

        let startF = field("Start Time", clip.startTime)
        let durF   = field("Duration",   clip.duration)
        let applyB = UIButton(type: .system)
        applyB.setTitle("Apply", for: .normal)
        applyB.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)

        let stack = UIStackView(arrangedSubviews: [startF, durF, applyB])
        stack.axis    = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        view.addSubview(container)

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
                  let nd = Float(durF.text ?? ""),
                  nd > 0 else { return }
            let old = self.timeline.clips[clipIdx]
            let upd = AnimationClip(
                entityName: old.entityName, type: old.type,
                track:      old.track,      easing: old.easing,
                startTime:  ns,             duration: nd,
                fromValue:  old.fromValue,  toValue: old.toValue,
                motionPath: old.motionPath
            )
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

    // ── Angles editor (text input) ────────────────────────────────────────────

    func presentRotationAnglesEditor(clipID: UUID) {
        guard let clipIdx = timeline.clips.firstIndex(where: { $0.id == clipID }) else { return }
        let clip   = timeline.clips[clipIdx]
        let deg: (Float) -> String = { String(format: "%.0f", $0 * 180 / .pi) }

        let alert = UIAlertController(
            title:   "Edit Rotation Angles",
            message: "Y-axis rotation in degrees",
            preferredStyle: .alert
        )
        alert.addTextField {
            $0.placeholder  = "Start angle (°)"
            $0.keyboardType = .numbersAndPunctuation
            $0.text         = deg(clip.fromValue.y)
        }
        alert.addTextField {
            $0.placeholder  = "End angle (°)"
            $0.keyboardType = .numbersAndPunctuation
            $0.text         = deg(clip.toValue.y)
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Apply", style: .default) { [weak self] _ in
            guard let self,
                  let sd = Float(alert.textFields?[0].text ?? ""),
                  let ed = Float(alert.textFields?[1].text ?? "") else { return }
            let r: Float = .pi / 180
            let old = self.timeline.clips[clipIdx]
            let upd = AnimationClip(
                entityName: old.entityName, type: old.type,
                track:      old.track,      easing: old.easing,
                startTime:  old.startTime,  duration: old.duration,
                fromValue:  SIMD3<Float>(0, sd * r, 0),
                toValue:    SIMD3<Float>(0, ed * r, 0),
                motionPath: old.motionPath
            )
            self.timeline.clips[clipIdx] = upd
            if let vis = self.activeRotationArcs[clipID],
               let ent = self.arView.scene.findEntity(named: upd.entityName) {
                RotationPathRenderer.update(visual: vis, clip: upd, entity: ent)
            }
        })
        present(alert, animated: true)
    }
}
