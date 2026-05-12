//
//  CameraRelativeRotationSolver.swift
//  3DCanvas
//
//  Camera-relative rotation interaction solver for the rotation gizmo.
//
//  Architecture (standard DCC approach — Blender / Maya / Unity / Unreal):
//  ────────────────────────────────────────────────────────────────────────
//  1. User taps a rotation ring → the ring's rotation AXIS is FROZEN in
//     world space for the duration of the drag.
//  2. An interaction PLANE is created perpendicular to the frozen axis,
//     passing through the entity's pivot point.
//  3. On each drag frame:
//     a. Cast a ray from the camera through the touch point.
//     b. Intersect the ray with the interaction plane.
//     c. Compute the angle from the pivot to the intersection point.
//     d. Delta angle = currentAngle − previousAngle.
//     e. Apply as a quaternion increment around the frozen axis.
//
//  This approach is **camera-independent** — the same gesture always
//  produces the same rotation regardless of camera orbit angle. No
//  screen-space heuristics, no dx/dy, no axis flipping.
//

import Foundation
import RealityKit
import simd

final class CameraRelativeRotationSolver {

    // ── Frozen state (set at drag start, constant until drag end) ────────
    private var frozenAxis: SIMD3<Float> = .zero
    private var pivotWorld: SIMD3<Float> = .zero
    private var previousAngle: Float = 0
    private var isActive = false

    /// Reference direction on the interaction plane — used to measure
    /// angles consistently. Computed once at drag start.
    private var referenceDir: SIMD3<Float> = .zero

    // ── Sensitivity ─────────────────────────────────────────────────────
    //
    // 1:1 mapping feels natural for medium-distance orbits. At extreme
    // zoom levels the raw radians can feel too fast (close-up) or too slow
    // (far away). A gentle sensitivity curve compensates:
    //   • Base multiplier: 1.0 (true 1:1)
    //   • Small deadzone (~0.001 rad) to filter sub-pixel jitter
    //   • Clamp delta to ±π/2 per frame to prevent flip-through
    private let deadzone: Float = 0.001
    private let maxDeltaPerFrame: Float = Float.pi * 0.5

    // MARK: - Public API

    /// Call once on `.began` — freezes the rotation axis and sets up the
    /// interaction plane.
    ///
    /// - Parameters:
    ///   - axis: The rotation axis in **world space** (must be normalized).
    ///   - pivot: The entity's pivot point in world space.
    ///   - touchPoint: The screen-space touch location (UIKit coordinates).
    ///   - arView: The live ARView for ray casting.
    /// - Returns: `true` if the initial projection succeeded (drag is valid).
    @discardableResult
    func beginRotation(
        axis: SIMD3<Float>,
        pivot: SIMD3<Float>,
        touchPoint: CGPoint,
        arView: ARView
    ) -> Bool {
        frozenAxis = simd_normalize(axis)
        pivotWorld = pivot
        isActive = true

        // Build an orthonormal reference direction on the interaction plane.
        // Pick a world vector that isn't parallel to the axis, cross it with
        // the axis to get a direction lying on the plane.
        let candidate: SIMD3<Float> = abs(simd_dot(frozenAxis, SIMD3<Float>(0, 1, 0))) < 0.99
            ? SIMD3<Float>(0, 1, 0)
            : SIMD3<Float>(1, 0, 0)
        referenceDir = simd_normalize(simd_cross(frozenAxis, candidate))

        // Project the initial touch onto the interaction plane to get the
        // starting angle.
        guard let angle = projectTouchToAngle(touchPoint, arView: arView) else {
            // Grazing angle or behind camera — fall back to screen-space
            // angular tracking (still camera-relative via projected centre).
            isActive = false
            return false
        }
        previousAngle = angle
        return true
    }

    /// Call on `.changed` — returns the incremental rotation quaternion to
    /// apply to the entity (in world space).
    ///
    /// Returns `nil` if the projection fails (finger moved to a grazing
    /// angle) — caller should skip this frame.
    func updateRotation(
        touchPoint: CGPoint,
        arView: ARView
    ) -> simd_quatf? {
        guard isActive else { return nil }

        guard let currentAngle = projectTouchToAngle(touchPoint, arView: arView) else {
            return nil  // Grazing angle — skip frame
        }

        // Wrap delta to (−π, π]
        var delta = currentAngle - previousAngle
        if delta >  Float.pi { delta -= 2 * Float.pi }
        if delta < -Float.pi { delta += 2 * Float.pi }

        // Deadzone — filter sub-pixel jitter
        guard abs(delta) > deadzone else { return nil }

        // Clamp to prevent flip-through on fast swipes
        delta = max(-maxDeltaPerFrame, min(maxDeltaPerFrame, delta))

        previousAngle = currentAngle

        // Build and return the incremental quaternion
        return simd_quatf(angle: delta, axis: frozenAxis)
    }

    /// Call on `.ended` / `.cancelled` — resets internal state.
    func endRotation() {
        isActive = false
        frozenAxis = .zero
        pivotWorld = .zero
        previousAngle = 0
        referenceDir = .zero
    }

    /// Whether the solver is currently tracking a drag.
    var tracking: Bool { isActive }

    // MARK: - Projection

    /// Casts a ray from the camera through `screenPoint`, intersects the
    /// interaction plane (normal = frozenAxis, point = pivotWorld), and
    /// returns the signed angle (in radians) of the intersection point
    /// around the pivot, measured from `referenceDir`.
    private func projectTouchToAngle(
        _ screenPoint: CGPoint,
        arView: ARView
    ) -> Float? {
        guard let ray = arView.ray(through: screenPoint) else { return nil }

        // Ray-plane intersection
        let denom = simd_dot(frozenAxis, ray.direction)

        // Grazing angle guard — if the ray is nearly parallel to the
        // interaction plane, the intersection is unreliable. Fall back.
        guard abs(denom) > 0.0001 else { return nil }

        let t = simd_dot(pivotWorld - ray.origin, frozenAxis) / denom
        guard t > 0 else { return nil }  // Intersection is behind the camera

        let hitWorld = ray.origin + ray.direction * t

        // Vector from pivot to hit point, projected onto the plane
        let toHit = hitWorld - pivotWorld
        let onPlane = toHit - frozenAxis * simd_dot(toHit, frozenAxis)
        let onPlaneLen = simd_length(onPlane)

        // Too close to the pivot — angle is degenerate
        guard onPlaneLen > 0.0001 else { return nil }

        let dir = onPlane / onPlaneLen

        // Signed angle from referenceDir using atan2(cross, dot)
        let cross = simd_cross(referenceDir, dir)
        let sinA = simd_dot(cross, frozenAxis)  // Sign comes from axis alignment
        let cosA = simd_dot(referenceDir, dir)

        return atan2(sinA, cosA)
    }
}
