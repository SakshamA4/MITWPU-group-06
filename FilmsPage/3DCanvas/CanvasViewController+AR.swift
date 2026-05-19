import Combine
import PhotosUI
import RealityKit
import UIKit
import ARKit

// MARK: - AR Mode Implementation
extension CanvasViewController {

    func toggleARMode(isOn: Bool) {
        if isOn {
            // 1. Hide editor grid (real ModelEntity — debugOptions won't touch it)
            arView.scene.findEntity(named: "Grid")?.isEnabled = false

            // 2. Dismiss gizmos and floating menus so they don't hover over camera feed
            hideGizmo()
            hideRotationGizmo()
            currentActionMenu?.removeFromSuperview()
            currentActionMenu = nil
            setEntityTransparency(selectedEntity, alpha: 1.0)
            selectedEntity = nil

            // 3. Open real device camera as ARView background
            arView.environment.background = .cameraFeed()
            arView.isOpaque = false
            arView.backgroundColor = .clear

            // 4. Kill post-processing — eliminates motion blur / blurry-wave artefacts
            arView.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disableHDR]

            // 5. Clear debug overlays
            arView.debugOptions = []
            arView.environment.sceneUnderstanding.options = []

            // FIX B: Switch to AR camera mode BEFORE starting the session.
            // Running arView.session.run() while cameraMode == .nonAR produces
            // undefined behaviour and can permanently corrupt the ARView render state.
            arView.cameraMode = .ar

            // 6. Start AR world-tracking (no .removeExistingAnchors — that wipes scene entities)
            let config = ARWorldTrackingConfiguration()
            config.planeDetection = [.horizontal]
            arView.session.run(config, options: [.resetTracking])

        } else {
            // Return to editor mode
            arView.session.pause()

            // FIX B: Restore non-AR camera mode so the PerspectiveCamera nodes
            // (editorCamera / sceneCameras) drive rendering again.
            arView.cameraMode = .nonAR

            // Restore editor grid
            arView.scene.findEntity(named: "Grid")?.isEnabled = true

            arView.environment.background = .color(.white)
            arView.isOpaque = true
            arView.backgroundColor = .white

            // Keep blur/HDR off — editor looks better without them too
            arView.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disableHDR]

        }
    }

    // Called when user taps in AR mode — anchors the entire scene to that real-world floor point
    func placeSceneOnRealSurface(at screenPoint: CGPoint) {
        let results = arView.raycast(
            from: screenPoint,
            allowing: .estimatedPlane,
            alignment: .horizontal
        )
        guard let result = results.first else { return }

        guard let mainAnchor = arView.scene.anchors.first(where: { $0.name == "MainAnchor" })
        else { return }

        // Reposition MainAnchor to the tapped real-world location
        // Moving the anchor is safer than re-parenting individual entities
        mainAnchor.transform = Transform(matrix: result.worldTransform)
    }
}
