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
    //
    // BUG FIX: In RealityKit, arView.scene and previewARView.scene can share
    // underlying resources. Calling removeAll() on the offscreen scene would
    // silently also remove anchors from the live scene. Now we use a dedicated
    // named anchor (__ShotPreviewClone__) that we can safely remove in isolation.

     func captureFrameFromCamera(
         _ item: SceneCameraItem?,
         completion: @escaping (UIImage?) -> Void
     ) {
         guard let item = item else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) { [weak self] in
                 self?.arView.snapshot(saveToHDR: false, completion: completion)
             }
             return
         }

         captureCameraPreviewImage(for: item, completion: completion)
     }

     func captureFrameAtTime(
         _ time: Float,
         cameraItem: SceneCameraItem?,
         completion: @escaping (UIImage?) -> Void
     ) {
         evaluateTimeline(at: time)
         DispatchQueue.main.asyncAfter(deadline: .now() + 0.033) { [weak self] in
             self?.captureFrameFromCamera(cameraItem, completion: completion)
         }
     }

     // MARK: - Shot Breakdown Entry Point

      @objc func shotBreakdownTapped() {
          let vc = ShotBreakdownViewController()
          vc.sceneName   = self.sceneName
          vc.timeline    = self.timeline
          vc.arView      = self.arView
          vc.cameraItems = self.sceneCameraItems

         vc.evaluateTimeline = { [weak self] t in
             self?.evaluateTimeline(at: t)
         }

          vc.captureFrameAsync = { [weak self] item, completion in
              guard let self = self else { completion(nil); return }
              self.captureFrameFromCamera(item, completion: completion)
          }

          vc.captureAtTime = { [weak self] time, item, completion in
              guard let self = self else { completion(nil); return }
              self.captureFrameAtTime(time, cameraItem: item, completion: completion)
          }
         
         // ISSUE 2: Set prepareForCapture closure to hide gizmos, paths, and camera lens before capture
         vc.prepareForCapture = { [weak self] item in
             guard let self = self else { return }
             if let item = item {
                 self.setActiveCamera(item.camera)
             } else {
                 self.activateEditorCamera()
             }
         }

         navigationController?.pushViewController(vc, animated: true)
     }
}
