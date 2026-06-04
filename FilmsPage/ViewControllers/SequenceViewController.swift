//
//  SequenceViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 28/11/25.
//

import UIKit

class SequenceViewController: UIViewController {

    private let sceneService = SceneService.shared
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var sequenceTitle: UILabel!
    @IBOutlet weak var serachButton: UIBarButtonItem!

    var scene: [Scene] = []
    var sceneCellId = "scene_cell"
    var sequence: Sequence?
    var filmName: String?
    private var activeCoordinator: SequenceExportCoordinator?
    private var exportCanvas: CanvasViewController?
    private var progressOverlay: ExportProgressOverlay?

    // MARK: - Tutorial Target View

    /// The placeholder (+) cell spotlighted in Step 5 of the onboarding.
    var tutorialTargetView: UIView? {
        collectionView.cellForItem(at: IndexPath(item: 0, section: 0))
    }

    // MARK: - Search State
    private var filteredScenes: [Scene] = []
    private var currentSearchText: String = ""
    private var savedSearchButton: UIBarButtonItem?
    private var savedExportButton: UIBarButtonItem?

    // Computed properties for search
    private var isSearching: Bool { !currentSearchText.isEmpty }
    private var currentScenes: [Scene] { isSearching ? filteredScenes : scene }

    // Search controller
    private let searchController = UISearchController(searchResultsController: nil)

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        refreshData()

        updateTitle()
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 30
        layout.minimumInteritemSpacing = 8
        collectionView.setCollectionViewLayout(layout, animated: false)
        collectionView.dataSource = self
        collectionView.delegate = self
        registerCells()
        setupObservers()
        setupSearchController()

        // Save the search button and ensure it's visible initially
        savedSearchButton = serachButton

        // Add export button to the left of the search button
        let exportButton = UIBarButtonItem(
            image: UIImage(systemName: "film.stack"),
            style: .plain,
            target: self,
            action: #selector(exportSequenceTapped)
        )
        exportButton.tintColor = .systemRed
        savedExportButton = exportButton
        navigationItem.rightBarButtonItems = [serachButton, exportButton]
    }

    // MARK: - Sequence Export

    @objc private func exportSequenceTapped() {
        guard let sequence = sequence else { return }
        guard !scene.isEmpty else {
            let alert = UIAlertController(
                title: "No Scenes",
                message: "Add scenes to this sequence before exporting.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        // Convert Film Scene models to ScenesModel for the export sheet
        // SequenceExportSheet expects [ScenesModel], but we have [Scene].
        // Build lightweight ScenesModel wrappers.
        let scenesForExport: [ScenesModel] = scene.map {
            ScenesModel(id: $0.id, name: $0.name, image: $0.image ?? "Image")
        }

        let sheet = SequenceExportSheet(
            sequenceName: sequence.name,
            scenes: scenesForExport
        )
        sheet.onExport = { [weak self] settings in
            self?.startSequenceExport(settings: settings)
        }
        present(sheet, animated: true)
    }

    private func startSequenceExport(settings: ExportSettings) {
        guard let sequence = sequence else { return }

        // Create a dedicated CanvasViewController for export rendering.
        // isExportMode MUST be set before .view is accessed (which triggers viewDidLoad).
        // This skips all interactive UI setup — only the ARView and scene graph are created.
        let exportCanvas = CanvasViewController()
        exportCanvas.isExportMode = true
        addChild(exportCanvas)
        exportCanvas.view.frame = view.bounds
        exportCanvas.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(exportCanvas.view, at: 0) // Behind everything
        exportCanvas.didMove(toParent: self)
        self.exportCanvas = exportCanvas

        // Wait for the ARView + RealityKit to fully initialise before starting.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            self.launchCoordinator(canvas: exportCanvas, settings: settings, sequence: sequence)
        }
    }

    private func launchCoordinator(canvas: CanvasViewController, settings: ExportSettings, sequence: Sequence) {
        let entries = scene.map {
            SequenceExportCoordinator.SequenceSceneEntry(sceneID: $0.id, sceneName: $0.name)
        }

        // Progress overlay
        let overlay = ExportProgressOverlay()
        overlay.show(in: view)
        self.progressOverlay = overlay

        let coordinator = SequenceExportCoordinator(
            scenes: entries,
            settings: settings,
            canvas: canvas,
            onProgress: { [weak overlay] progress in
                overlay?.update(with: progress)
            },
            onCompletion: { [weak self] result in
                guard let self = self else { return }
                self.activeCoordinator = nil
                self.progressOverlay?.dismiss {
                    self.teardownExportCanvas()

                    switch result {
                    case .success(let url):
                        self.previewAndShare(videoURL: url, sequenceName: sequence.name)
                    case .failure(let error):
                        // Cancelled exports don't show an alert
                        guard (error as NSError).code != -3 else { return }
                        let alert = UIAlertController(
                            title: "Export Failed",
                            message: error.localizedDescription,
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(alert, animated: true)
                    }
                }
            }
        )
        self.activeCoordinator = coordinator

        overlay.onCancel = { [weak coordinator] in
            coordinator?.cancel()
        }

        coordinator.start()
    }

    private func teardownExportCanvas() {
        exportCanvas?.willMove(toParent: nil)
        exportCanvas?.view.removeFromSuperview()
        exportCanvas?.removeFromParent()
        exportCanvas = nil
    }

    private func previewAndShare(videoURL: URL, sequenceName: String) {
        let previewVC = SequencePreviewViewController(
            videoURL: videoURL,
            sequenceName: sequenceName
        )
        previewVC.modalPresentationStyle = .fullScreen
        present(previewVC, animated: true)
    }

    @IBAction func searchAction(_ sender: Any) {
        // Show search controller in navigation bar
        navigationItem.searchController = searchController

        // Hide the search button by removing it from nav bar
        navigationItem.rightBarButtonItem = nil

        // Animate the search bar appearance
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }

        // Activate and focus the search bar
        searchController.isActive = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.searchController.searchBar.becomeFirstResponder()
        }
    }

    private func setupSearchController() {
        searchController.searchResultsUpdater = self
        searchController.searchBar.delegate = self
        searchController.delegate = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search Scenes"
        // Don't set navigationItem.searchController initially (search bar hidden)
        definesPresentationContext = true
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshData),
            name: NSNotification.Name(NotificationNames.scenesUpdated),
            object: nil
        )
        // Tutorial: step changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTutorialStepChanged(_:)),
            name: NSNotification.Name(NotificationNames.tutorialStepChanged),
            object: nil
        )
    }

    @objc private func handleTutorialStepChanged(_ notification: Notification) {
        guard let raw  = notification.userInfo?["step"] as? Int,
              let step = TutorialStep(rawValue: raw),
              step == .createSceneInSequence else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self, let target = self.tutorialTargetView else { return }
            TutorialManager.shared.showSpotlightIfNeeded(targeting: target, for: .createSceneInSequence)
        }
    }

    @objc private func refreshData() {
        if let sequence = sequence {
            scene = sceneService.getScenes(forSequenceId: sequence.id)
        }
        // Clear search state when data refreshes
        currentSearchText = ""
        filteredScenes = []
        searchController.isActive = false
        collectionView?.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshData()
        updateTitle()
        // Always hide search bar and show search button when view appears
        navigationItem.searchController = nil
        restoreBarButtons()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if TutorialManager.shared.currentStep == .createSceneInSequence,
           let target = tutorialTargetView {
            TutorialManager.shared.showSpotlightIfNeeded(targeting: target, for: .createSceneInSequence)
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.collectionView?.collectionViewLayout.invalidateLayout()
        }, completion: nil)
    }

    func registerCells() {
        collectionView.register(
            UINib(nibName: "SceneCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "scene_cell"
        )
        collectionView.register(
            UINib(nibName: "PlaceholderCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "placeholder_cell"
        )
    }

    private func updateTitle() {
        sequenceTitle.text = sequence?.name ?? "Sequence"
    }

    // MARK: - Filter Logic

    private func filterScenes(for query: String) {
        currentSearchText = query.trimmingCharacters(in: .whitespaces)
        if currentSearchText.isEmpty {
            filteredScenes = []
        } else {
            filteredScenes = scene.filter {
                $0.name.localizedCaseInsensitiveContains(currentSearchText)
            }
        }
        collectionView.reloadData()
    }

    private func restoreBarButtons() {
        var items: [UIBarButtonItem] = []
        if let search = savedSearchButton { items.append(search) } else { items.append(serachButton) }
        if let export = savedExportButton { items.append(export) }
        navigationItem.rightBarButtonItems = items
    }

}

extension SequenceViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        // Placeholder cell only shown when not searching
        if !isSearching && indexPath.item == 0 {
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "placeholder_cell",
                for: indexPath
            ) as? PlaceholderCollectionViewCell else { return UICollectionViewCell() }

            cell.addNew.text = "New Scene"
            cell.onPlusButtonTapped = { [weak self] in
                self?.performSegue(withIdentifier: "addSceneSegue", sender: nil)
            }
            return cell
        }

        // Scene cells
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: sceneCellId,
            for: indexPath
        ) as? SceneCollectionViewCell else { return UICollectionViewCell() }

        // Adjust index based on whether search is active
        let itemIndex = isSearching ? indexPath.item : indexPath.item - 1
        let sceneToDisplay = currentScenes[itemIndex]
        cell.configureCell(scene: sceneToDisplay)
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        // When searching, no placeholder cell
        if isSearching {
            return currentScenes.count
        }
        // When not searching, include placeholder at index 0
        return currentScenes.count + 1
    }
}

extension SequenceViewController: UICollectionViewDelegate,
    UICollectionViewDelegateFlowLayout {
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
         if segue.identifier == "addSceneSegue" {
             if let vc = segue.destination as? AddSceneViewController {
                 vc.sequence = sequence
             }
         }
     }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let inset: CGFloat = 40
        let interItem: CGFloat = 40
        let columns: CGFloat = 4
        let totalSpacing = inset * 2 + interItem * (columns - 1)
        let width = (collectionView.bounds.width - totalSpacing) / columns
        return CGSize(width: width, height: width)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // When not searching, index 0 is placeholder (ignore it)
        // When searching, no placeholder, so all indices are valid
        guard !(!isSearching && indexPath.item == 0) else { return }

        let itemIndex = isSearching ? indexPath.item : indexPath.item - 1
        let selectedScene = currentScenes[itemIndex]

        let vc = CanvasViewController()
        vc.currentSceneObject = selectedScene
        vc.currentSceneID = selectedScene.id
        vc.sceneName = selectedScene.name
        vc.sequenceName = self.sequence?.name
        vc.filmName = self.filmName

        let navController = UINavigationController(rootViewController: vc)
        navController.modalPresentationStyle = .fullScreen
        self.present(navController, animated: true)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        insetForSectionAt section: Int
    ) -> UIEdgeInsets {
        return UIEdgeInsets(top: 16, left: 52, bottom: 16, right: 52)
    }
}

extension SequenceViewController {

    // MARK: - Context Menu (Long Press)
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        // When not searching, index 0 is placeholder (ignore it)
        guard !(!isSearching && indexPath.item == 0) else { return nil }

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in

            // 1. Define the "Edit" Action
            let editAction = UIAction(title: "Edit Name", image: UIImage(systemName: "pencil")) { [weak self] _ in
                self?.presentEditAlert(at: indexPath)
            }

            // 2. Define the "Delete" Action
            let deleteAction = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.deleteScene(at: indexPath)
            }

            // 3. Return the Menu
            return UIMenu(title: "", children: [editAction, deleteAction])
        }
    }

    // MARK: - Helper Functions

    private func deleteScene(at indexPath: IndexPath) {
        let itemIndex = isSearching ? indexPath.item : indexPath.item - 1
        let sceneToDelete = currentScenes[itemIndex]
        sceneService.deleteScene(by: sceneToDelete.id)
    }

    private func presentEditAlert(at indexPath: IndexPath) {
        let itemIndex = isSearching ? indexPath.item : indexPath.item - 1
        let currentScene = currentScenes[itemIndex]

        let alert = UIAlertController(title: "Edit Scene", message: "Enter a new name for this scene", preferredStyle: .alert)

        alert.addTextField { textField in
            textField.text = currentScene.name
            textField.placeholder = "Scene Name"
        }

        let saveAction = UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self = self,
                  let newName = alert.textFields?.first?.text,
                  !newName.isEmpty else { return }

            var updatedScene = currentScene
            updatedScene.name = newName

            self.sceneService.updateScene(updatedScene)

            // Update the scene in the full list
            if let originalIndex = self.scene.firstIndex(where: { $0.id == currentScene.id }) {
                self.scene[originalIndex] = updatedScene
            }

            self.collectionView.reloadItems(at: [indexPath])
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

        alert.addAction(saveAction)
        alert.addAction(cancelAction)

         present(alert, animated: true)
     }
}

// MARK: - UISearchResultsUpdating

extension SequenceViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text ?? ""
        filterScenes(for: searchText)
    }
}

// MARK: - UISearchBarDelegate

extension SequenceViewController: UISearchBarDelegate {
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        currentSearchText = ""
        filteredScenes = []
        collectionView.reloadData()

        // Hide the search controller and remove from nav bar
        searchController.isActive = false
        navigationItem.searchController = nil

        // Restore the buttons to nav bar
        restoreBarButtons()
    }
}

// MARK: - UISearchControllerDelegate

extension SequenceViewController: UISearchControllerDelegate {
    func willDismissSearchController(_ searchController: UISearchController) {
        // Clear search state before dismissing
        currentSearchText = ""
        filteredScenes = []
        collectionView.reloadData()
    }

    func didDismissSearchController(_ searchController: UISearchController) {
        // Restore the search button when search controller is dismissed
        navigationItem.searchController = nil
        restoreBarButtons()
    }
}
