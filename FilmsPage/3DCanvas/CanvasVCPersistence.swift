//
//  CanvasViewController+Persistence.swift
//  3DCanvas
//

import UIKit
import RealityKit

extension CanvasViewController {

    // MARK: - Load on open

    func loadSceneIfSaved() {
        guard let id = currentSceneID else { return }
        guard ScenePersistenceService.shared.hasSave(for: id) else { return }

        // FIX: Only load the scene once. When returning from navigation (e.g., shot breakdown),
        // viewDidAppear is called again but we should not reload the saved version,
        // as that would clear any unsaved entities and animations.
        guard !hasSceneBeenLoaded else { return }
        hasSceneBeenLoaded = true

        // BUG 7 FIX: Auto-save whenever the app is backgrounded so that changes
        // are never lost if iOS kills the process before the user taps "Save & Exit".
        // The observer is removed in commitExit() so it doesn't fire after the VC is gone.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(autoSaveOnBackground),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        // Show a loading overlay so the user sees feedback while the scene deserialises.
        // The overlay is removed by the load completion path in ScenePersistence.swift,
        // but we also remove it here as a safety net after a short delay.
        let overlay = UIView()
        overlay.tag = 7771
        overlay.backgroundColor = UIColor(white: 0, alpha: 0.55)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlay)
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: overlay.centerYAnchor)
        ])
        spinner.startAnimating()

        Task { @MainActor in
            await ScenePersistenceService.shared.load(into: self, sceneID: id)
            // Remove the loading overlay once the scene is fully loaded.
            view.viewWithTag(7771)?.removeFromSuperview()
        }
    }

    // MARK: - Auto-save (BUG 7 FIX)

    /// Silently saves the scene when the app moves to the background.
    /// Runs the full save pipeline so nothing is lost if iOS kills the process.
    /// No UI overlay is shown — the save runs invisibly in the background.
    ///
    /// FIX: Now waits for pendingBackgroundTasks == 0 before writing JSON,
    /// using the same polling approach as the user-initiated saveAndExit() path.
    /// This prevents in-flight TextureResource uploads from being missed.
    @objc private func autoSaveOnBackground() {
        guard let id = currentSceneID else { return }
        // Capture thumbnail only if the view is still on screen.
        if viewIfLoaded?.window != nil {
            arView.snapshot(saveToHDR: false) { [weak self] thumbnailImage in
                guard let self = self else { return }
                let filename = ScenePersistenceService.shared.saveThumbnail(thumbnailImage, sceneID: id)
                if let filename = filename { self.sceneImageName = filename }
                self.waitForBackgroundsAndAutoSave(sceneID: id)
            }
        } else {
            // View not visible (e.g. shot breakdown is on top) — save without thumbnail.
            waitForBackgroundsAndAutoSave(sceneID: id)
        }
    }

    /// Polls every 50ms until all background texture uploads complete,
    /// then writes the scene JSON. Identical to the user-initiated
    /// waitForBackgroundsAndSave() but without spinner or commitExit().
    private func waitForBackgroundsAndAutoSave(sceneID: UUID) {
        guard pendingBackgroundTasks == 0 else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.waitForBackgroundsAndAutoSave(sceneID: sceneID)
            }
            return
        }
        ScenePersistenceService.shared.save(canvas: self, sceneID: sceneID) { success in
            print(success ? "✅ Auto-saved on background" : "❌ Auto-save failed")
        }
    }

    // MARK: - Save prompt on back

    func promptSaveAndExit() {
        let alert = UIAlertController(
            title: "Save Scene?",
            message: "Do you want to save your changes before leaving?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Save & Exit", style: .default) { [weak self] _ in self?.saveAndExit() })
        alert.addAction(UIAlertAction(title: "Exit Without Saving", style: .destructive) { [weak self] _ in self?.commitExit()  })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func saveAndExit() {
        userDidSave = true
        guard let id = currentSceneID else {
            commitExit()
            return
        }

        // Show a spinner while saving
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        spinner.startAnimating()

        // 1. Capture a thumbnail from the live arView BEFORE saving.
        //    snapshot() is async; on completion we kick off the JSON/image save.
        arView.snapshot(saveToHDR: false) { [weak self] thumbnailImage in
            guard let self = self else { return }

            // 2. Persist the thumbnail JPEG to the Documents directory so that
            //    RecentScenesCollectionViewCell can load it back via setFilmImage(named:).
            let thumbnailFilename = ScenePersistenceService.shared
                .saveThumbnail(thumbnailImage, sceneID: id)

            // Remember the filename so commitExit() can write it into ScenesModel.image.
            if let filename = thumbnailFilename {
                self.sceneImageName = filename
            }

            // 3. FIX E: Wait for any in-flight background texture Tasks to finish
            //    before writing the JSON.  applyBackgroundImage() runs TextureResource
            //    asynchronously; if the user saves immediately after adding a background
            //    the Task may not have set cachedImage yet, causing the texture to be
            //    silently omitted from the save.  We poll on a 50 ms timer and only
            //    proceed once pendingBackgroundTasks reaches zero.
            self.waitForBackgroundsAndSave(sceneID: id, spinner: spinner)
        }
    }

    // FIX E: Helper — retries every 50 ms until all background texture uploads complete,
    // then calls the actual save.  Avoids blocking the main run-loop.
    private func waitForBackgroundsAndSave(sceneID: UUID, spinner: UIActivityIndicatorView) {
        guard pendingBackgroundTasks == 0 else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.waitForBackgroundsAndSave(sceneID: sceneID, spinner: spinner)
            }
            return
        }

        // 4. Save the canvas scene JSON + background images.
        ScenePersistenceService.shared.save(canvas: self, sceneID: sceneID) { [weak self] _ in
            spinner.stopAnimating()
            spinner.removeFromSuperview()
            self?.commitExit()
        }
    }

    // MARK: - Commit exit

     /// Updates metadata and dismisses. No RealityKit access — safe to call any time.
     func commitExit() {
         let currentID = currentSceneID ?? currentSceneObject?.id ?? UUID()

         // Template-copy cleanup: if the user exits without saving a scene that
         // was created by copying a bundled template, remove the copied files
         // from Documents and skip adding to recents entirely.
         if isTemplateCopy && !userDidSave {
             if let id = currentSceneID {
                 ScenePersistenceService.shared.deleteSave(for: id)
                 let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                 try? FileManager.default.removeItem(
                     at: docs.appendingPathComponent("thumb_\(id.uuidString).jpg")
                 )
                 ScenePersistenceService.shared.evictScene(id)
             }
             hasSceneBeenLoaded = false
             NotificationCenter.default.removeObserver(
                 self,
                 name: UIApplication.willResignActiveNotification,
                 object: nil
             )
             dismiss(animated: true)
             return
         }

         let isTemplate = ScenesDataStore.shared.currentTemplates.contains { $0.id == currentID }

         if isTemplate {
             ScenesDataStore.shared.saveTemplateNote(id: currentID, notes: sceneNotes)
         } else {
             let updatedRecent = ScenesModel(
                 id: currentID,
                 name: sceneName,
                 image: sceneImageName ?? "Image",
                 notes: sceneNotes
             )
             ScenesDataStore.shared.addToRecent(scene: updatedRecent)
         }

         // FIX: Reset the scene load flag so that if this scene is reopened later,
         // it will load properly. Without this, reopening a scene would skip loading
         // because hasSceneBeenLoaded would still be true.
         hasSceneBeenLoaded = false

         // BUG 7 FIX: Remove the auto-save observer now that we are leaving the scene.
         // Without this, the observer would remain registered on a dismissed VC and
         // could fire against a torn-down scene graph.
         NotificationCenter.default.removeObserver(
             self,
             name: UIApplication.willResignActiveNotification,
             object: nil
         )

         // FIX: Mark the scene as exited instead of immediately evicting.
         // The cache retains the last N scenes so reopening is instant.
         // Eviction happens automatically when the retained count exceeds
         // maxRetainedExitedScenes or on memory warning.
         if let sceneID = currentSceneID {
             ScenePersistenceService.shared.markSceneExited(sceneID)
             print("📦 Scene \(sceneID.uuidString.prefix(8))... marked exited (cache retained)")
         }

         dismiss(animated: true)
     }
}
