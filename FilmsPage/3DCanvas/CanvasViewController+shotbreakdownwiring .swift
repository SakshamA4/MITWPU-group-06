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

    private static let ShotPreviewCloneName = "__ShotPreviewClone__"

     func captureFrameFromCamera(
         _ item: SceneCameraItem?,
         completion: @escaping (UIImage?) -> Void
     ) {
         // No scene camera → snapshot editor view directly
         guard let item = item else {
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) { [weak self] in
                 self?.arView.snapshot(saveToHDR: false, completion: completion)
             }
             return
         }

         let offscreen = previewARView

         // 1. Remove any previous preview clone (safe, by name) to prevent memory buildup
         if let existing = offscreen.scene.findEntity(named: Self.ShotPreviewCloneName) {
             existing.removeFromParent()
         }

         // 2. Clone the live scene into the offscreen view
         guard let mainAnchor = arView.scene.findEntity(named: "MainAnchor") as? AnchorEntity else {
             completion(nil)
             return
         }
         
         // Clone with smaller resolution hint for faster rendering
         let clonedAnchor = mainAnchor.clone(recursive: true)
         clonedAnchor.name = Self.ShotPreviewCloneName  // Tag for safe removal later
         offscreen.scene.addAnchor(clonedAnchor)

          // 3. Disable ALL cameras in the clone, then enable only the target camera
          // forEachDescendant is defined on Entity extension in CanvasViewController.swift
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

         // 4. Snapshot the offscreen view — main arView completely untouched
         // Reduced delay from 50ms to 33ms (one frame at 30fps) to speed up capture
         DispatchQueue.main.asyncAfter(deadline: .now() + 0.033) { [weak self] in
             offscreen.snapshot(saveToHDR: false) { [weak self] image in
                 // Clean up the clone after snapshot to prevent memory buildup
                 if let existing = offscreen.scene.findEntity(named: Self.ShotPreviewCloneName) {
                     existing.removeFromParent()
                 }
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
