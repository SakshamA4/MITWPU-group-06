//
//  CanvasViewController+ShotBreakdownWiring.swift
//  3DCanvas
//
//  Drop this file in. It provides:
//  1. captureFromCamera — activates a scene camera, snapshots, restores.
//     This is what gives the shot cards their actual camera POV thumbnails.
//  2. shotBreakdownTapped — opens the Shot Breakdown screen correctly wired.
//

import UIKit
import RealityKit

extension CanvasViewController {

    // MARK: - Camera POV Capture
    //
    // Temporarily activates the given camera, takes a snapshot of what it sees,
    // then restores the previously active camera. Safe to call on main thread.

    func captureSnapshotFromCamera(_ item: SceneCameraItem?) -> UIImage? {
        // If no specific camera, snapshot the current editor view
        guard let item = item else {
            var result: UIImage?
            let sema = DispatchSemaphore(value: 0)
            arView.snapshot(saveToHDR: false) { img in
                result = img; sema.signal()
            }
            // Wait max 0.5s for snapshot — avoids blocking forever
            _ = sema.wait(timeout: .now() + 0.5)
            return result
        }

        // 1. Remember who's active
        let wasActive = activeCamera
        let wasEditorActive = editorCamera.isEnabled

        // 2. Activate the scene camera
        setActiveCamera(item.camera)

        // 3. Snapshot — synchronous wait (called from already-deferred context)
        var result: UIImage?
        let sema = DispatchSemaphore(value: 0)
        arView.snapshot(saveToHDR: false) { img in
            result = img; sema.signal()
        }
        _ = sema.wait(timeout: .now() + 0.5)

        // 4. Restore
        if wasEditorActive {
            activateEditorCamera()
        } else if let cam = wasActive as? PerspectiveCamera,
                  cam !== editorCamera {
            setActiveCamera(cam)
        } else {
            activateEditorCamera()
        }

        return result
    }

    // MARK: - shotBreakdownTapped
    //
    // Replace the existing @objc private func shotBreakdownTapped() in
    // CanvasViewController+UI.swift with this version.

    @objc func shotBreakdownTapped() {
        let vc = ShotBreakdownViewController()
        vc.sceneName        = self.sceneName
        vc.timeline         = self.timeline
        vc.cameraNames      = self.sceneCameraItems.map { $0.cameraRoot.name }
        vc.arView           = self.arView
        vc.cameraItems      = self.sceneCameraItems

        // Pass evaluateTimeline — scrubs entity positions to a given time
        vc.evaluateTimeline = { [weak self] t in
            self?.evaluateTimeline(at: t)
        }

        // Pass captureFromCamera — gives actual camera POV image
        vc.captureFromCamera = { [weak self] item in
            guard let self = self else { return nil }
            // Must run on main thread — already guaranteed by caller
            return self.captureSnapshotFromCamera(item)
        }

        navigationController?.pushViewController(vc, animated: true)
    }
}
