//
//  CanvasViewController+ShotBreakdownWiring.swift
//  3DCanvas
//

import UIKit
import RealityKit

extension CanvasViewController {

    // MARK: - Camera POV Capture  (used by Shot Breakdown & Shot Player)
    //
    // IMPORTANT: RealityKit's ARView.snapshot() only works reliably when the ARView
    // is part of a live window/view hierarchy. The off-screen clone approach returns
    // black images because the GPU compositor has no surface to render into.
    //
    // The correct approach for thumbnails: briefly activate the target camera on the
    // live arView, evaluate entity positions, wait 2 render frames, snapshot, then
    // immediately restore the previous camera. The transition is ~100ms and invisible
    // to the user since the shot breakdown VC is on top.

     func captureFrameFromCamera(
         _ item: SceneCameraItem?,
         completion: @escaping (UIImage?) -> Void
     ) {
         // Remember who was active so we can restore after capture
         let previousCamera = activeCamera

         if let item = item {
             setActiveCamera(item.camera)
         } else {
             activateEditorCamera()
         }

         // Give RealityKit 2 render frames to composite the new camera view
         DispatchQueue.main.asyncAfter(deadline: .now() + 0.066) { [weak self] in
             guard let self = self else { completion(nil); return }
             self.arView.snapshot(saveToHDR: false) { [weak self] image in
                 // Restore original camera immediately after snapshot
                 DispatchQueue.main.async {
                     if let prev = self?.sceneCameras.first(where: { $0 === previousCamera }) {
                         self?.setActiveCamera(prev)
                     } else {
                         self?.activateEditorCamera()
                     }
                     completion(image)
                 }
             }
         }
     }

     func captureFrameAtTime(
         _ time: Float,
         cameraItem: SceneCameraItem?,
         completion: @escaping (UIImage?) -> Void
     ) {
         // Position all entities at the requested timeline time.
         evaluateTimeline(at: time)
         // Capture from the correct camera POV on the live arView.
         captureFrameFromCamera(cameraItem, completion: completion)
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

         vc.enterPlaybackMode = { [weak self] in
             self?.enterShotPlaybackMode()
         }

         vc.exitPlaybackMode = { [weak self] in
             self?.exitShotPlaybackMode()
         }

          vc.captureFrameAsync = { [weak self] item, completion in
              guard let self = self else { completion(nil); return }
              self.captureFrameFromCamera(item, completion: completion)
          }

       vc.captureAtTime = { [weak self] time, item, completion in
           guard let self = self else { completion(nil); return }
           self.captureFrameAtTime(time, cameraItem: item, completion: completion)
       }

       vc.fetchTimeline = { [weak self] in
           self?.timeline ?? Timeline()
       }

       vc.clipConflictCheck = { [weak self] edited, replacingID in
           self?.detectClipConflict(editedClip: edited, replacingID: replacingID)
       }

       vc.commitClipTimingChange = { [weak self] newClip, oldClipID, clipIndex in
           self?.commitClipTimingChange(newClip: newClip, oldClipID: oldClipID, clipIndex: clipIndex)
       }

       vc.shiftSubsequentClips = { [weak self] entityName, startingAfter, delta in
           self?.shiftSubsequentClips(entityName: entityName, startingAfter: startingAfter, delta: delta)
       }

       vc.mergeConflictingClip = { [weak self] conflicting, newStart, newDuration in
           self?.mergeConflictingClip(conflicting: conflicting, newStartTime: newStart, newDuration: newDuration)
       }

       vc.deleteTimelineClip = { [weak self] clipID in
           guard let self else { return }
           if let idx = self.timeline.clips.firstIndex(where: { $0.id == clipID }) {
               let clip = self.timeline.clips[idx]
               if let visual = self.activeMotionPaths[clipID] {
                   visual.startHandle?.removeFromParent()
                   visual.root.removeFromParent()
               }
               self.activeMotionPaths.removeValue(forKey: clipID)
               self.hideRotationArc(for: clipID)
               self.timeline.clips.remove(at: idx)
               self.refreshSidebarContent()
           }
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
