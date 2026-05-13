//
//  CanvasViewController+CameraViewGestures.swift
//  3DCanvas
//
//  In-camera gesture handlers for manipulating the scene camera
//  directly from the camera-through view.
//
//  Gesture mapping (matches PreVis Pro standard):
//  ─────────────────────────────────────────────────
//  1-finger drag   → Point CAM (rotate yaw/pitch)
//  2-finger drag   → Move X-Y (dolly along local right + up)
//  Pinch           → Truck Z (move along look direction)
//  2-finger twist  → Roll camera (Dutch angle)
//

import UIKit
import RealityKit

extension CanvasViewController {

    // MARK: - Gesture Setup

    /// Call from `setActiveCamera()` to enable camera-view gestures.
    /// Call from `activateEditorCamera()` to disable them.
    func enableCameraViewGestures(_ enable: Bool) {
        if enable {
            addCameraViewGestures()
        } else {
            removeCameraViewGestures()
        }
    }

    /// Tags used to identify camera-view gesture recognizers.
    private enum CamGestureTag {
        static let point:  Int = 7701
        static let moveXY: Int = 7702
        static let truck:  Int = 7703
        static let roll:   Int = 7704
    }

    private func addCameraViewGestures() {
        guard arView != nil else { return }
        // Avoid double-adding
        removeCameraViewGestures()

        // 1-finger: Point Camera (rotate)
        let pointPan = UIPanGestureRecognizer(target: self, action: #selector(handleCameraViewPoint(_:)))
        pointPan.minimumNumberOfTouches = 1
        pointPan.maximumNumberOfTouches = 1
        pointPan.accessibilityHint = "CamViewPoint"
        tagGesture(pointPan, tag: CamGestureTag.point)
        arView.addGestureRecognizer(pointPan)

        // 2-finger: Move X-Y (dolly)
        let movePan = UIPanGestureRecognizer(target: self, action: #selector(handleCameraViewMoveXY(_:)))
        movePan.minimumNumberOfTouches = 2
        movePan.maximumNumberOfTouches = 2
        movePan.accessibilityHint = "CamViewMoveXY"
        tagGesture(movePan, tag: CamGestureTag.moveXY)
        arView.addGestureRecognizer(movePan)

        // Pinch: Truck Z (forward/back)
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handleCameraViewTruck(_:)))
        pinch.accessibilityHint = "CamViewTruck"
        tagGesture(pinch, tag: CamGestureTag.truck)
        arView.addGestureRecognizer(pinch)

        // 2-finger twist: Roll
        let twist = UIRotationGestureRecognizer(target: self, action: #selector(handleCameraViewRoll(_:)))
        twist.accessibilityHint = "CamViewRoll"
        tagGesture(twist, tag: CamGestureTag.roll)
        arView.addGestureRecognizer(twist)
    }

    private func removeCameraViewGestures() {
        guard let gestures = arView?.gestureRecognizers else { return }
        let tags = Set([CamGestureTag.point, CamGestureTag.moveXY, CamGestureTag.truck, CamGestureTag.roll])
        for g in gestures {
            if let hint = g.accessibilityHint, hint.hasPrefix("CamView") {
                arView.removeGestureRecognizer(g)
            }
        }
    }

    private func tagGesture(_ gesture: UIGestureRecognizer, tag: Int) {
        // We use accessibilityHint as a lightweight tag since UIGestureRecognizer has no .tag
        // The hint is already set above; tag value is unused but kept for documentation
    }

    // MARK: - Active Camera Root Helper

    private var activeCameraRoot: Entity? {
        guard activeCamera !== editorCamera else { return nil }
        return cameraToVisualMap[activeCamera]
    }

    // MARK: - 1-Finger: Point Camera (Rotate Yaw / Pitch)

    @objc private func handleCameraViewPoint(_ gesture: UIPanGestureRecognizer) {
        guard activeCamera !== editorCamera,
              let cameraRoot = activeCameraRoot else { return }

        if gesture.state == .changed {
            let t = gesture.translation(in: arView)

            // Sensitivity proportional to FOV — narrower lens = slower rotation
            let fov = activeCamera.camera.fieldOfViewInDegrees
            let sensitivity: Float = fov / 60.0 * 0.005

            let yawDelta   = -Float(t.x) * sensitivity
            let pitchDelta =  Float(t.y) * sensitivity

            // Apply yaw around world Y, pitch around camera's local X
            let yawQuat   = simd_quatf(angle: yawDelta,   axis: [0, 1, 0])
            let currentOri = cameraRoot.orientation(relativeTo: nil)

            // Camera's local right axis for pitch
            let localRight = currentOri.act(SIMD3<Float>(1, 0, 0))
            let pitchQuat  = simd_quatf(angle: pitchDelta, axis: localRight)

            let newOri = simd_normalize(pitchQuat * yawQuat * currentOri)
            cameraRoot.setOrientation(newOri, relativeTo: nil)

            gesture.setTranslation(.zero, in: arView)
        }
    }

    // MARK: - 2-Finger: Move X-Y (Dolly)

    @objc private func handleCameraViewMoveXY(_ gesture: UIPanGestureRecognizer) {
        guard activeCamera !== editorCamera,
              let cameraRoot = activeCameraRoot else { return }

        if gesture.state == .changed {
            let t = gesture.translation(in: arView)

            // Camera's local right and up axes
            let ori = cameraRoot.orientation(relativeTo: nil)
            let right = ori.act(SIMD3<Float>(1, 0, 0))
            let up    = ori.act(SIMD3<Float>(0, 1, 0))

            let scale: Float = 0.002
            let delta = right * Float(t.x) * scale - up * Float(t.y) * scale

            cameraRoot.setPosition(cameraRoot.position(relativeTo: nil) + delta, relativeTo: nil)

            gesture.setTranslation(.zero, in: arView)
        }
    }

    // MARK: - Pinch: Truck Z (Forward / Back)

    @objc private func handleCameraViewTruck(_ gesture: UIPinchGestureRecognizer) {
        guard activeCamera !== editorCamera,
              let cameraRoot = activeCameraRoot else { return }

        if gesture.state == .changed {
            let scaleFactor = Float(gesture.scale)

            // Camera's local forward (-Z in RealityKit convention)
            let ori = cameraRoot.orientation(relativeTo: nil)
            let forward = ori.act(SIMD3<Float>(0, 0, -1))

            // Pinch out (scale > 1) = move forward; pinch in (scale < 1) = move back
            let speed: Float = 0.5
            let delta = forward * (scaleFactor - 1.0) * speed

            cameraRoot.setPosition(cameraRoot.position(relativeTo: nil) + delta, relativeTo: nil)

            gesture.scale = 1.0
        }
    }

    // MARK: - 2-Finger Twist: Roll (Dutch Angle)

    @objc private func handleCameraViewRoll(_ gesture: UIRotationGestureRecognizer) {
        guard activeCamera !== editorCamera,
              let cameraRoot = activeCameraRoot else { return }

        if gesture.state == .changed {
            let angle = Float(gesture.rotation)

            // Camera's local forward axis for roll
            let ori = cameraRoot.orientation(relativeTo: nil)
            let forward = ori.act(SIMD3<Float>(0, 0, -1))

            let rollQuat = simd_quatf(angle: angle, axis: forward)
            let newOri = simd_normalize(rollQuat * ori)
            cameraRoot.setOrientation(newOri, relativeTo: nil)

            gesture.rotation = 0
        }
    }
}
