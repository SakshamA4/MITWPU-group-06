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
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
        ])
        spinner.startAnimating()

        Task { @MainActor in
            await ScenePersistenceService.shared.load(into: self, sceneID: id)
            // Remove the loading overlay once the scene is fully loaded.
            view.viewWithTag(7771)?.removeFromSuperview()
        }
    }

    // MARK: - Save prompt on back

    func promptSaveAndExit() {
        let alert = UIAlertController(
            title:          "Save Scene?",
            message:        "Do you want to save your changes before leaving?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Save & Exit",         style: .default)     { [weak self] _ in self?.saveAndExit() })
        alert.addAction(UIAlertAction(title: "Exit Without Saving", style: .destructive) { [weak self] _ in self?.commitExit()  })
        alert.addAction(UIAlertAction(title: "Cancel",              style: .cancel))
        present(alert, animated: true)
    }

    private func saveAndExit() {
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

        let isTemplate = ScenesDataStore.shared.currentTemplates.contains { $0.id == currentID }

        if isTemplate {
            ScenesDataStore.shared.saveTemplateNote(id: currentID, notes: sceneNotes)
        } else {
            let updatedRecent = ScenesModel(
                id:    currentID,
                name:  sceneName,
                image: sceneImageName ?? "Image",
                notes: sceneNotes
            )
            ScenesDataStore.shared.addToRecent(scene: updatedRecent)
        }

        dismiss(animated: true)
    }
}

