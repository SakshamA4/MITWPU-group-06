import Combine
import PhotosUI
import RealityKit
import UIKit
import ARKit
import AVFoundation

// MARK: - AR Mode Implementation
extension CanvasViewController {

    func toggleARMode(isOn: Bool) {
        if isOn {
            // ── Check camera authorisation BEFORE touching ARKit ──
            let status = AVCaptureDevice.authorizationStatus(for: .video)

            switch status {
            case .notDetermined:
                // First launch — ask user, then re-enter
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        if granted {
                            self.activateAR()
                        } else {
                            // Roll back the toggle so button state stays consistent
                            self.isARModeActive = false
                            self.showCameraDeniedAlert()
                        }
                    }
                }
                return   // async — we'll activate later

            case .authorized:
                activateAR()

            case .denied, .restricted:
                isARModeActive = false
                showCameraDeniedAlert()
                return

            @unknown default:
                isARModeActive = false
                return
            }

        } else {
            deactivateAR()
        }
    }

    // MARK: - Private helpers

    private func activateAR() {
        // 1. Hide editor grid
        arView.scene.findEntity(named: "Grid")?.isEnabled = false

        // 2. Hide sky entities — irrelevant when real camera is the background
        if let anchor = mainAnchor {
            for child in anchor.children where child.name.hasPrefix("ProceduralSky") {
                child.isEnabled = false
            }
        }

        // 3. Dismiss gizmos and floating menus
        hideGizmo()
        hideRotationGizmo()
        currentActionMenu?.removeFromSuperview()
        currentActionMenu = nil
        setEntityTransparency(selectedEntity, alpha: 1.0)
        selectedEntity = nil

        // 4. Switch camera mode to AR BEFORE starting the session.
        //    Running arView.session.run() while cameraMode == .nonAR produces
        //    undefined behaviour and can permanently corrupt the ARView render state.
        arView.cameraMode = .ar

        // 5. Open real device camera as ARView background
        arView.environment.background = .cameraFeed()
        arView.isOpaque = false
        arView.backgroundColor = .clear

        // 6. Kill post-processing
        arView.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disableHDR]

        // 7. Clear debug overlays
        arView.debugOptions = []
        arView.environment.sceneUnderstanding.options = []

        // 8. Start AR world-tracking
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        arView.session.run(config, options: [.resetTracking])

        // 9. Update button appearance to "active"
        arModeButton?.tintColor = .white
        arModeButton?.backgroundColor = UIColor(red: 0/255, green: 100/255, blue: 220/255, alpha: 1)
    }

    private func deactivateAR() {
        // 1. Pause AR session
        arView.session.pause()

        // 2. Restore non-AR camera mode
        arView.cameraMode = .nonAR

        // 3. Restore editor grid
        arView.scene.findEntity(named: "Grid")?.isEnabled = true

        // 4. Re-show sky entities
        if let anchor = mainAnchor {
            for child in anchor.children where child.name.hasPrefix("ProceduralSky") {
                child.isEnabled = true
            }
        }

        // 5. Restore editor background
        arView.environment.background = .color(.white)
        arView.isOpaque = true
        arView.backgroundColor = .white

        // 6. Keep post-processing off for editor too
        arView.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disableHDR]

        // 7. Update button back to inactive appearance
        arModeButton?.tintColor = .systemGreen
        arModeButton?.backgroundColor = UIColor(red: 11/255, green: 11/255, blue: 22/255, alpha: 1)
    }

    private func showCameraDeniedAlert() {
        let alert = UIAlertController(
            title: "Camera Access Required",
            message: "AR mode needs camera access. Please enable it in Settings → Privacy → Camera.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - AR surface placement

    /// Called when user taps in AR mode — anchors the entire scene to that real-world floor point
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
        mainAnchor.transform = Transform(matrix: result.worldTransform)
    }
}
