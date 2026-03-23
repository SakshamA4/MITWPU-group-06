//
//  CanvasViewController+ShotBreakdownWiring.swift
//  3DCanvas
//

import Combine
import UIKit
import RealityKit

extension CanvasViewController {

    // MARK: - Camera POV Capture

    func captureFrameFromCamera(
        _ item: SceneCameraItem?,
        completion: @escaping (UIImage?) -> Void
    ) {
        // No scene camera — snapshot editor view directly
        guard let item = item else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.033) { [weak self] in
                self?.arView.snapshot(saveToHDR: false, completion: completion)
            }
            return
        }

        let targetCameraName = item.camera.name
        let previousCamera   = activeCamera

        // Temporarily enable only the target camera
        for cam in sceneCameras { cam.isEnabled = (cam.name == targetCameraName) }
        editorCamera.isEnabled = false

        // Wait one render frame then snapshot the main arView
        var token: AnyCancellable?
        token = arView.scene.publisher(for: SceneEvents.Update.self)
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                token = nil
                guard let self = self else { completion(nil); return }

                self.arView.snapshot(saveToHDR: false) { [weak self] image in
                    guard let self = self else { completion(image); return }
                    // Restore previous camera
                    for cam in self.sceneCameras {
                        cam.isEnabled = (cam === previousCamera)
                    }
                    self.editorCamera.isEnabled = (previousCamera === self.editorCamera)
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
