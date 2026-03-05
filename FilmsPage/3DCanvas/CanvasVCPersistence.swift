//
//  CanvasViewController+Persistence.swift
//  3DCanvas
//

import UIKit
import RealityKit

extension CanvasViewController {

    // MARK: - Load on open (call at end of viewDidLoad)

    func loadSceneIfSaved() {
        guard let id = currentSceneID else { return }
        guard ScenePersistenceService.shared.hasSave(for: id) else { return }
        Task { @MainActor in
            await ScenePersistenceService.shared.load(into: self, sceneID: id)
        }
    }

    // MARK: - Save prompt on back (replaces backButtonTapped body)

    func promptSaveAndExit() {
        let alert = UIAlertController(
            title: "Save Scene?",
            message: "Do you want to save your changes before leaving?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Save & Exit", style: .default) { [weak self] _ in
            self?.saveAndExit()
        })
        alert.addAction(UIAlertAction(title: "Exit Without Saving", style: .destructive) { [weak self] _ in
            self?.commitExit()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        present(alert, animated: true)
    }

    private func saveAndExit() {
        guard let id = currentSceneID else {
            commitExit()
            return
        }

        // Show spinner while saving
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        spinner.startAnimating()

        // save() reads the scene on main thread, writes JSON on background thread,
        // then calls completion back on the main thread — no SIGABRT risk.
        ScenePersistenceService.shared.save(canvas: self, sceneID: id) { [weak self] _ in
            spinner.stopAnimating()
            spinner.removeFromSuperview()
            self?.commitExit()
        }
    }

    /// Updates metadata and dismisses. No RealityKit access — safe to call anytime.
    func commitExit() {
        let currentID = currentSceneID ?? currentSceneObject?.id ?? UUID()

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

        dismiss(animated: true)
    }
}
