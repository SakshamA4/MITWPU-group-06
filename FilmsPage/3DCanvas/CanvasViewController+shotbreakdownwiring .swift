//
//  CanvasViewController+ShotBreakdownWiring.swift
//  3DCanvas
//

import UIKit
import RealityKit

extension CanvasViewController {

    // MARK: - Camera POV Capture  (used by Shot Breakdown & Shot Player)
    //
    // FIX: Uses the offscreen clone approach (same as snapshotPreviewCamera in
    // CanvasViewController_Camera.swift) instead of switching cameras on the live
    // arView. Switching camera entities on a .nonAR ARView does not change what
    // snapshot() renders. The offscreen clone guarantees the correct POV.

    func captureFrameFromCamera(
        _ item: SceneCameraItem?,
        completion: @escaping (UIImage?) -> Void
    ) {
        // No scene camera → snapshot editor view directly
        guard let item = item else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.033) { [weak self] in
                self?.arView.snapshot(saveToHDR: false, completion: completion)
            }
            return
        }

        let offscreen = previewARView

        // 1. Clone the live scene into the offscreen view
        offscreen.scene.anchors.removeAll()
        guard let mainAnchor = arView.scene.findEntity(named: "MainAnchor") as? AnchorEntity else {
            completion(nil)
            return
        }
        let clonedAnchor = mainAnchor.clone(recursive: true)
        offscreen.scene.addAnchor(clonedAnchor)

        // 2. Disable ALL cameras in the clone, then enable only the target camera
        // forEachDescendant is defined in CameraPreviewCell.swift on Entity
        clonedAnchor.forEachDescendant { entity in
            if let cam = entity as? PerspectiveCamera { cam.isEnabled = false }
        }

        if let targetCam = clonedAnchor.findEntity(named: item.camera.name) as? PerspectiveCamera {
            targetCam.isEnabled = true
        } else {
            // Fallback: camera not found by name — place one at cameraRoot's transform
            let fallback = PerspectiveCamera()
            fallback.transform = item.cameraRoot.transform
            fallback.isEnabled = true
            clonedAnchor.addChild(fallback)
        }

        // 3. Snapshot the offscreen view — main arView completely untouched
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            offscreen.snapshot(saveToHDR: false) { image in
                DispatchQueue.main.async { completion(image) }
            }
        }
    }

    // MARK: - Shot Breakdown Entry Point

    @objc func shotBreakdownTapped() {
        let vc = ShotBreakdownViewController()
        vc.sceneName   = self.sceneName
        vc.timeline    = self.timeline
        vc.cameraNames = self.sceneCameraItems.map { $0.cameraRoot.name }
        vc.arView      = self.arView
        vc.cameraItems = self.sceneCameraItems

        vc.evaluateTimeline = { [weak self] t in
            self?.evaluateTimeline(at: t)
        }

        vc.captureFrameAsync = { [weak self] item, completion in
            guard let self = self else { completion(nil); return }
            self.captureFrameFromCamera(item, completion: completion)
        }

        navigationController?.pushViewController(vc, animated: true)
    }
}
