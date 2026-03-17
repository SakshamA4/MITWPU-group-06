//
//  CanvasViewController+ShotBreakdownWiring.swift
//  3DCanvas
//
//  Delete or comment out the @objc private func shotBreakdownTapped() in
//  CanvasViewController_UI.swift — this file replaces it.
//

import UIKit
import RealityKit

extension CanvasViewController {

    // MARK: - Async Camera POV Capture
    //
    // 1. setActiveCamera — switches RealityKit to the camera's POV
    // 2. asyncAfter(50ms) — one render tick for the new frame to appear
    // 3. arView.snapshot() — captures it
    // 4. activateEditorCamera() — restore
    // 5. completion(image)

    func captureFrameFromCamera(
        _ item: SceneCameraItem?,
        completion: @escaping (UIImage?) -> Void
    ) {
        guard let item = item else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.033) { [weak self] in
                self?.arView.snapshot(saveToHDR: false, completion: completion)
            }
            return
        }

        setActiveCamera(item.camera)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { completion(nil); return }
            self.arView.snapshot(saveToHDR: false) { [weak self] image in
                DispatchQueue.main.async {
                    self?.activateEditorCamera()
                    completion(image)
                }
            }
        }
    }

    // MARK: - Shot Breakdown Entry Point
    //
    // IMPORTANT: In CanvasViewController_UI.swift, change:
    //   @objc private func shotBreakdownTapped()
    // to:
    //   @objc func shotBreakdownTapped_OLD()   ← rename so this one wins

    @objc func shotBreakdownTapped() {
        let vc = ShotBreakdownViewController()
        vc.sceneName    = self.sceneName
        vc.timeline     = self.timeline
        vc.cameraNames  = self.sceneCameraItems.map { $0.cameraRoot.name }
        vc.arView       = self.arView
        vc.cameraItems  = self.sceneCameraItems

        vc.evaluateTimeline = { [weak self] t in
            self?.evaluateTimeline(at: t)   // now defined in TimelinePlayback file
        }

        vc.captureFrameAsync = { [weak self] item, completion in
            guard let self = self else { completion(nil); return }
            self.captureFrameFromCamera(item, completion: completion)
        }

        navigationController?.pushViewController(vc, animated: true)
    }
}
