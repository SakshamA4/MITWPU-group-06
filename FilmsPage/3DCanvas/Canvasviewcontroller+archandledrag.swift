//
//  Canvasviewcontroller+archandledrag.swift
//  FilmsPage
//
//  Created by SDC-USER on 17/03/26.
//

import UIKit
import RealityKit

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - CanvasViewController+ArcHandleDrag
//
// Implements DIRECT radial dragging of rotation arc handles.
//
// HOW IT WORKS:
//   • The user touches directly on a start (teal) or end (orange) sphere.
//   • No gizmo involved — we track the finger in screen space, un-project it
//     onto the horizontal plane at the arc root's Y, and use atan2 to compute
//     the new angle.  The handle snaps onto the circle; the shaft wrapper
//     rotates to match.
//
// INTEGRATION STEPS (in CanvasViewController_Gestures.swift):
//
//   1. In handleTap — the existing RotationArcComponent tap block already sets
//      selectedArcClipID.  REMOVE the lines that call showGizmo / hideGizmo for
//      arc handles — direct drag does not use the gizmo at all:
//
//        // REMOVE THESE four lines when an arc handle is tapped:
//        activeHandleEntity = hit
//        hideGizmo()
//        showGizmo(at: hit)
//
//      Replace with just:
//        selectedArcClipID = arcComp.clipID
//        return
//
//   2. In handlePan .began — add this BEFORE the existing gizmo hit test so arc
//      handles are captured first:
//
//        if let hit = arView.entity(at: location),
//           let arcComp = hit.components[RotationArcComponent.self] {
//            beginArcHandleDrag(handle: hit, arcComp: arcComp)
//            return
//        }
//
//   3. In handlePan .changed — add this BEFORE the existing gizmo logic:
//
//        if draggingArcHandle != nil {
//            continueArcHandleDrag(gesture: gesture)
//            return
//        }
//
//   4. In handlePan .ended / .cancelled — add:
//
//        endArcHandleDrag()
//
// ─────────────────────────────────────────────────────────────────────────────

extension CanvasViewController {

    // ── Begin drag ────────────────────────────────────────────────────────────

    func beginArcHandleDrag(handle: Entity, arcComp: RotationArcComponent) {
        draggingArcHandle = handle
        draggingArcClipID = arcComp.clipID
        draggingArcRole   = arcComp.role

        // Record the arc root's world Y so we can keep the drag on the same plane
        if let visual = activeRotationArcs[arcComp.clipID] {
            arcDragCentre = visual.root.position(relativeTo: arView.scene.findEntity(named: "MainAnchor"))
        }

        // Compute the initial angle so we can detect direction-of-drag correctly
        if let clipIdx = timeline.clips.firstIndex(where: { $0.id == arcComp.clipID }) {
            let clip = timeline.clips[clipIdx]
            arcDragLastAngle = arcComp.role == .start ? clip.fromValue.y : clip.toValue.y
        }
    }

    // ── Continue drag ─────────────────────────────────────────────────────────
    //
    // On each .changed event:
    //   1. Unproject finger → horizontal plane at arcRoot.y
    //   2. atan2(dx, dz) gives the new angle in radians
    //   3. Snap handle back onto the circle at that angle
    //   4. Rotate the shaft wrapper to point at that angle
    //   5. Rebuild the arc curve between the two current angles
    //   6. Write the new angle into the timeline clip

    func continueArcHandleDrag(gesture: UIPanGestureRecognizer) {
        guard
            let handle  = draggingArcHandle,
            let clipID  = draggingArcClipID,
            let role    = draggingArcRole,
            let centre  = arcDragCentre,
            let visual  = activeRotationArcs[clipID],
            let clipIdx = timeline.clips.firstIndex(where: { $0.id == clipID }),
            let anchor  = arView.scene.findEntity(named: "MainAnchor")
        else { return }

        let location = gesture.location(in: arView)

        // ── 1. Un-project finger onto the Y-plane at arcRoot height ──────────
        //   We cast a ray from the camera through the touch point and intersect
        //   it with a horizontal plane at y = centre.y (world space).
        guard let worldPos = unprojectToHorizontalPlane(
            screenPoint: location,
            planeY: visual.root.position(relativeTo: nil).y
        ) else { return }

        // ── 2. Compute angle relative to arc root centre ──────────────────────
        let arcWorldCentre = visual.root.position(relativeTo: nil)
        let dx = worldPos.x - arcWorldCentre.x
        let dz = worldPos.z - arcWorldCentre.z
        guard sqrt(dx*dx + dz*dz) > 0.001 else { return }
        let newAngle = atan2(dx, dz)   // matches circlePoint's sin/cos convention

        // ── 3. Snap handle onto circle ────────────────────────────────────────
        let snapped = arcWorldCentre + RotationPathRenderer.circlePoint(angle: newAngle)
        handle.setPosition(snapped, relativeTo: nil)

        // ── 4. Rotate shaft to clock-hand angle ───────────────────────────────
        RotationPathRenderer.setHandleAngle(newAngle, role: role, visual: visual)

        // ── 5. Write angle into the clip ──────────────────────────────────────
        let old  = timeline.clips[clipIdx]
        let from = role == .start ? SIMD3<Float>(0, newAngle, 0) : old.fromValue
        let to   = role == .end   ? SIMD3<Float>(0, newAngle, 0) : old.toValue

        timeline.clips[clipIdx] = AnimationClip(
            entityName: old.entityName,
            entityID: old.entityID,
            type: old.type,
            track: old.track,
            easing: old.easing,
            startTime: old.startTime,
            duration: old.duration,
            fromValue: from,
            toValue: to,
            motionPath: old.motionPath
        )

        // ── 6. Rebuild arc curve between updated angles ───────────────────────
        let updated = timeline.clips[clipIdx]
        RotationPathRenderer.updateArcCurveOnly(
            visual: visual,
            fromAngle: updated.fromValue.y,
            toAngle: updated.toValue.y
        )

        arcDragLastAngle = newAngle
    }

    // ── End drag ──────────────────────────────────────────────────────────────

    func endArcHandleDrag() {
        draggingArcHandle = nil
        draggingArcClipID = nil
        draggingArcRole   = nil
        arcDragCentre     = nil
    }

    // ── Helper: unproject screen point onto a horizontal world plane ──────────
    //
    // Casts a ray from the camera through `screenPoint` and returns the world-
    // space intersection with the plane y = `planeY`.
    //
    // Returns nil if the ray is nearly parallel to the plane (camera looking
    // horizontally — extremely rare in a scene editor).

    private func unprojectToHorizontalPlane(
        screenPoint: CGPoint,
        planeY: Float
    ) -> SIMD3<Float>? {
        // Build a ray from the active camera through the screen pixel.
        let camTransform = arView.cameraTransform
        let camPos = camTransform.translation

        // Convert screen point to a normalised device coordinate, then to a
        // ray direction in world space using the camera's projection matrix.
        // ARView exposes `ray(through:)` for exactly this purpose.
        guard let ray = arView.ray(through: screenPoint) else { return nil }

        let rayOrigin    = ray.origin
        let rayDirection = ray.direction

        // Plane: y = planeY, normal = (0,1,0)
        let planeNormal: SIMD3<Float> = [0, 1, 0]
        let planePoint: SIMD3<Float> = [0, planeY, 0]

        let denom = simd_dot(planeNormal, rayDirection)
        guard abs(denom) > 0.0001 else { return nil }

        let t = simd_dot(planePoint - rayOrigin, planeNormal) / denom
        guard t > 0 else { return nil }

        return rayOrigin + rayDirection * t
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - handlePan integration patch
//
// The sections below show EXACTLY what to change in handlePan inside
// CanvasViewController.swift.  They are written as comments rather than
// compiled code so you can apply them surgically without breaking anything.
//
// ── In the .began block ───────────────────────────────────────────────────────
//
//  ADD at the very top of the .began block, BEFORE the gizmo hit-test:
//
//      // ── Arc handle direct drag (radial constraint, no gizmo) ──
//      if let hit = arView.entity(at: location),
//         let arcComp = hit.components[RotationArcComponent.self] {
//          beginArcHandleDrag(handle: hit, arcComp: arcComp)
//          return
//      }
//
// ── In the .changed block ─────────────────────────────────────────────────────
//
//  ADD at the very top of the .changed block (after the editorMode guard),
//  BEFORE the activeGizmoPart guard:
//
//      // ── Arc handle live drag ──
//      if draggingArcHandle != nil {
//          continueArcHandleDrag(gesture: gesture)
//          return
//      }
//
// ── In the .ended / .cancelled block ─────────────────────────────────────────
//
//  ADD at the end of .ended / .cancelled:
//
//      endArcHandleDrag()
//
// ── In handleTap — arc handle tap block ──────────────────────────────────────
//
//  REPLACE the existing arc handle tap handler:
//
//      if let hit = arView.entity(at: location),
//         let arcComp = hit.components[RotationArcComponent.self]
//      {
//          selectedArcClipID  = arcComp.clipID
//          setEntityTransparency(selectedEntity, alpha: 1.0)
//          selectedEntity     = nil
//          hideRotationGizmo()
//          // No gizmo — direct drag is used instead.
//          return
//      }
//
// ─────────────────────────────────────────────────────────────────────────────
