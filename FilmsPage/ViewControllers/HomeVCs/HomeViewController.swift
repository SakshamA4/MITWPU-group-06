//
//  HomeViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 28/11/25.
//
import UIKit

class HomeViewController: UIViewController, UICollectionViewDelegate {

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var searchButton: UIBarButtonItem!

    // MARK: - Tutorial Target Views

    /// The "+" nav bar button spotlighted in Step 1 of the onboarding.
    /// Exposed as internal so TutorialManager can read its frame.
    var createSceneButton: UIView? {
        guard let items = navigationItem.rightBarButtonItems else { return nil }
        if let plusItem = items.first(where: { $0 != searchButton }) {
            return plusItem.value(forKey: "view") as? UIView
        }
        return nil
    }

    /// Returns the first visible cell in the Recent Scenes section (section 1).
    var firstRecentSceneView: UIView? {
        collectionView.cellForItem(at: IndexPath(item: 0, section: 1))
    }

    // Local Data Source (Mirrors the Store)
    private var templates: [ScenesModel] = []
    private var recentScenes: [ScenesModel] = []

    // MARK: - Search State
    private var filteredTemplates: [ScenesModel] = []
    private var filteredRecentScenes: [ScenesModel] = []
    private var currentSearchText: String = ""
    private var savedRightBarButtonItems: [UIBarButtonItem]?

    // Computed properties for search
    private var isSearching: Bool { !currentSearchText.isEmpty }
    private var currentTemplates: [ScenesModel] { isSearching ? filteredTemplates : templates }
    private var currentRecentScenes: [ScenesModel] { isSearching ? filteredRecentScenes : recentScenes }

    // Search controller
    private let searchController = UISearchController(searchResultsController: nil)

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        setupObservers()
        setupSearchController()

        // Save the right bar button items and ensure they are visible initially
        savedRightBarButtonItems = navigationItem.rightBarButtonItems

        refreshData() // Initial load
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // 📍 THE FIX: Refresh data from the store to show updated notes/scenes
        refreshData()

        // Always hide search bar and show search button when view appears
        navigationItem.searchController = nil
        if let savedItems = savedRightBarButtonItems {
            navigationItem.rightBarButtonItems = savedItems
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showTutorialSpotlightIfNeeded()
    }

    @IBAction func searchAction(_ sender: Any) {
        // Show search controller in navigation bar
        navigationItem.searchController = searchController

        // Hide the search button by removing it from nav bar
        navigationItem.rightBarButtonItems = nil

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
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.collectionView?.collectionViewLayout.invalidateLayout()
        }, completion: nil)
    }
    // MARK: - Setup
    private func setupCollectionView() {
        // Ensure you register your NIBs/Classes here if not done in Storyboard
        collectionView.register(UINib(nibName: "RecentScenesCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "recentscenes_cell")
        collectionView.register(UINib(nibName: "TemplatesCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "templates_cell")
        collectionView.register(UINib(nibName: "HomeHeaderView", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "home_header_view")

        collectionView.collectionViewLayout = createCompositionalLayout()
        collectionView.delegate = self
        collectionView.dataSource = self
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScenesUpdated),
            name: ScenesDataStore.scenesUpdatedNotification,
            object: nil
        )
        // Tutorial step changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTutorialStepChanged(_:)),
            name: NSNotification.Name(NotificationNames.tutorialStepChanged),
            object: nil
        )
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

    @objc private func handleScenesUpdated() {
        refreshData()
    }

    private func refreshData() {
        // 1. Fetch latest data from the Single Source of Truth
        templates = ScenesDataStore.shared.currentTemplates
        recentScenes = ScenesDataStore.shared.currentRecentScenes

        // Clear search state when data refreshes
        currentSearchText = ""
        filteredTemplates = []
        filteredRecentScenes = []
        searchController.isActive = false

        // 2. Reload UI
        collectionView.reloadData()

        // Re-evaluate spotlight in case a scene was just added (Step 6 / 7)
        if !recentScenes.isEmpty {
            showTutorialSpotlightIfNeeded()
        }
    }

    // MARK: - Tutorial Helpers

    private func showTutorialSpotlightIfNeeded() {
        let tm = TutorialManager.shared
        switch tm.currentStep {
        case .homeCreateScene:
            if let target = createSceneButton {
                tm.showSpotlightIfNeeded(targeting: target, for: .homeCreateScene)
            }
        case .returnToHomeHighlight:
            if let cell = firstRecentSceneView {
                tm.showSpotlightIfNeeded(targeting: cell, for: .returnToHomeHighlight)
            }
        case .enterScene:
            if let cell = firstRecentSceneView {
                tm.showSpotlightIfNeeded(targeting: cell, for: .enterScene)
            }
        default:
            break
        }
    }

    @objc private func handleTutorialStepChanged(_ notification: Notification) {
        guard let raw   = notification.userInfo?["step"] as? Int,
              let step  = TutorialStep(rawValue: raw) else { return }

        switch step {
        case .homeCreateScene:
            if let target = createSceneButton {
                TutorialManager.shared.showSpotlightIfNeeded(targeting: target, for: step)
            }
        case .returnToHomeHighlight, .enterScene:
            // Wait a tick for the collection view to reload after scene creation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self, let cell = self.firstRecentSceneView else { return }
                TutorialManager.shared.showSpotlightIfNeeded(targeting: cell, for: step)
            }
        default:
            break
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Notify tutorial manager when the "+" popover opens during onboarding.
        if TutorialManager.shared.currentStep == .homeCreateScene {
            TutorialManager.shared.handlePlusButtonTapped()
        }
    }

    // MARK: - Filter Logic

    private func filterScenes(for query: String) {
        currentSearchText = query.trimmingCharacters(in: .whitespaces)
        if currentSearchText.isEmpty {
            filteredTemplates = []
            filteredRecentScenes = []
        } else {
            filteredTemplates = templates.filter {
                $0.name.localizedCaseInsensitiveContains(currentSearchText)
            }
            filteredRecentScenes = recentScenes.filter {
                $0.name.localizedCaseInsensitiveContains(currentSearchText)
            }
        }
        collectionView.reloadData()
    }
}

// MARK: - CollectionView DataSource
extension HomeViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return section == 0 ? currentTemplates.count : currentRecentScenes.count
    }

      func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
          if indexPath.section == 0 {
              guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "templates_cell", for: indexPath) as? TemplatesCollectionViewCell else {
                  return UICollectionViewCell()
              }
              let item = currentTemplates[indexPath.row]
              cell.templateLabel.text = item.name
              cell.templatesImageView.setFilmImage(named: item.image ?? "Image")
              return cell
          } else {
              guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "recentscenes_cell", for: indexPath) as? RecentScenesCollectionViewCell else {
                  return UICollectionViewCell()
              }
              let item = currentRecentScenes[indexPath.row]
              cell.configure(with: item)
              return cell
          }
      }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader else { return UICollectionReusableView() }

        guard let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "home_header_view", for: indexPath) as? HomeHeaderView else {
            return UICollectionReusableView()
        }
        header.titleLabel.text = indexPath.section == 0 ? "Templates" : "Recent Scenes"
        return header
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // --- Recent Scenes (section 1) — open directly, unchanged ---
        if indexPath.section == 1 {
            let isTutorialActive = (TutorialManager.shared.currentStep == .enterScene)
            // Notify tutorial manager before opening the canvas (Step 7)
            TutorialManager.shared.handleSceneTappedOnHome()

            let selectedModel = currentRecentScenes[indexPath.row]
            let vc = CanvasViewController()
            vc.currentSceneID = selectedModel.id
            vc.sceneName = selectedModel.name
            vc.sceneNotes = selectedModel.notes ?? ""
            vc.sceneImageName = selectedModel.image
            vc.isOnboardingEntry = isTutorialActive
            let navController = UINavigationController(rootViewController: vc)
            navController.modalPresentationStyle = .fullScreen
            self.present(navController, animated: true)
            return
        }

        // --- Templates (section 0) ---
        let selectedModel = currentTemplates[indexPath.row]
        let templateDef = ScenesDataStore.shared.bundledTemplate(for: selectedModel.id)

        // If the template has no bundled scene, open exactly as today.
        guard let jsonName = templateDef?.bundledJSONName,
              let thumbName = templateDef?.bundledThumbName else {
            let vc = CanvasViewController()
            vc.currentSceneID = selectedModel.id
            vc.sceneName = selectedModel.name
            vc.sceneNotes = selectedModel.notes ?? ""
            vc.sceneImageName = selectedModel.image
            let navController = UINavigationController(rootViewController: vc)
            navController.modalPresentationStyle = .fullScreen
            self.present(navController, animated: true)
            return
        }

        // IMPORTANT: Never write to, modify, or delete bundle template files.
        // indoor_scene.json and indoor_scene.jpg in BundledTemplates are read-only.
        // Always copy to Documents with a new UUID before any modification.

        let newSceneID = UUID()
        let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        )[0]

        // --- Copy bundled JSON to Documents ---
        // Try subdirectory first (Xcode folder reference), fall back to flat bundle lookup.
        let jsonURL = Bundle.main.url(
            forResource: jsonName,
            withExtension: "json",
            subdirectory: "Templates"
        ) ?? Bundle.main.url(
            forResource: jsonName,
            withExtension: "json"
        )

        guard let bundleURL = jsonURL else {
            showTemplateErrorAlert()
            return
        }

        let destURL = documentsDirectory
            .appendingPathComponent("scene_\(newSceneID.uuidString).json")

        // Remove stale file if it exists from a previous failed attempt
        if FileManager.default.fileExists(atPath: destURL.path) {
            try? FileManager.default.removeItem(at: destURL)
        }

        do {
            try FileManager.default.copyItem(at: bundleURL, to: destURL)
        } catch {
            showTemplateErrorAlert()
            return
        }

        // Patch the sceneID inside the copied JSON so it matches the new UUID.
        // Decode → mutate → re-encode to preserve the full CanvasSceneDocument structure.
        do {
            let rawData = try Data(contentsOf: destURL)
            if var jsonObject = try JSONSerialization.jsonObject(with: rawData) as? [String: Any] {
                jsonObject["sceneID"] = newSceneID.uuidString
                let patchedData = try JSONSerialization.data(withJSONObject: jsonObject)
                try patchedData.write(to: destURL, options: .atomic)
            }
        } catch {
            // Non-fatal: the scene will still load from the filename-based lookup,
            // and the next save will overwrite with the correct sceneID.
        }

        // --- Copy bundled thumbnail to Documents ---
        let thumbFilename = "thumb_\(newSceneID.uuidString).jpg"

        let thumbURL = Bundle.main.url(
            forResource: thumbName,
            withExtension: "jpg",
            subdirectory: "Templates"
        ) ?? Bundle.main.url(
            forResource: thumbName,
            withExtension: "jpg"
        )

        guard let thumbBundleURL = thumbURL else {
            showTemplateErrorAlert()
            return
        }

        let thumbDestURL = documentsDirectory
            .appendingPathComponent(thumbFilename)

        // Remove stale file if it exists from a previous failed attempt
        if FileManager.default.fileExists(atPath: thumbDestURL.path) {
            try? FileManager.default.removeItem(at: thumbDestURL)
        }

        do {
            try FileManager.default.copyItem(at: thumbBundleURL, to: thumbDestURL)
        } catch {
            showTemplateErrorAlert()
            return
        }

        // --- Open CanvasViewController with the new scene ---
        // Do NOT add to recentScenes here — the entry is created in commitExit()
        // only if the user saves. This avoids stale Recents entries when the user
        // exits without saving.
        let vc = CanvasViewController()
        vc.currentSceneID = newSceneID
        vc.sceneName = selectedModel.name
        vc.sceneNotes = ""
        vc.sceneImageName = thumbFilename
        vc.isTemplateCopy = true
        let navController = UINavigationController(rootViewController: vc)
        navController.modalPresentationStyle = .fullScreen
        self.present(navController, animated: true)
    }

    /// Presents a generic error alert when a bundled template cannot be opened.
    private func showTemplateErrorAlert() {
        let alert = UIAlertController(
            title: "Error",
            message: "Could not open template. Please try again.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension HomeViewController {
    func createCompositionalLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { _, _ in

            // 1. Item (The internal cell setup)
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .fractionalHeight(1.0)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .absolute(240),
                heightDimension: .absolute(240)
            )
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: groupSize,
                subitems: [item]
            )

            // 3. Section Configuration
            let section = NSCollectionLayoutSection(group: group)

            // This enables the Horizontal Scrolling seen in the image
            section.orthogonalScrollingBehavior = .continuous

            // The gap between "Outdoor Scene" and "Home"
            section.interGroupSpacing = 24

            section.contentInsets = NSDirectionalEdgeInsets(
                top: 30,
                leading: 50,
                bottom: 40,
                trailing: 20
            )
            section.supplementaryContentInsetsReference = .none

            let headerSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(60)
            )
            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: headerSize,
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top
            )

            section.boundarySupplementaryItems = [header]

            return section
        }
    }
}

extension HomeViewController {

    // MARK: - Context Menu (Long Press)
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {

        // FIX 1: Change section == 0 to section == 1
        // In your DataSource, Section 0 is Templates, Section 1 is Recent Scenes.
        guard indexPath.section == 1 else { return nil }

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in

            // Get the model used in the view
            let sceneModel = self.currentRecentScenes[indexPath.item]

            // ACTION 1: Rename
            let renameAction = UIAction(title: "Rename", image: UIImage(systemName: "pencil")) { [weak self] _ in
                self?.presentRenameAlert(for: sceneModel)
            }

            // ACTION 2: Delete
            let deleteAction = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                // We capture self here to call the local helper function
                self?.deleteRecentScene(sceneModel)
            }

            return UIMenu(title: sceneModel.name, children: [renameAction, deleteAction])
        }
    }

    // MARK: - Helper Functions

    private func deleteRecentScene(_ sceneModel: ScenesModel) {
        ScenesDataStore.shared.deleteScene(by: sceneModel.id)
    }

    private func presentRenameAlert(for sceneModel: ScenesModel) {
        let alert = UIAlertController(title: "Rename Scene", message: nil, preferredStyle: .alert)

        alert.addTextField { tf in
            tf.text = sceneModel.name
            tf.placeholder = "Scene Name"
            tf.autocapitalizationType = .words
        }

        let saveAction = UIAlertAction(title: "Save", style: .default) { _ in
            guard let newName = alert.textFields?.first?.text, !newName.isEmpty else { return }
            var updatedScene = sceneModel
            updatedScene.name = newName
            ScenesDataStore.shared.updateScene(updatedScene)

        }

        alert.addAction(saveAction)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

         present(alert, animated: true)
     }
}

// MARK: - UISearchResultsUpdating

extension HomeViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let searchText = searchController.searchBar.text ?? ""
        filterScenes(for: searchText)
    }
}

// MARK: - UISearchBarDelegate

extension HomeViewController: UISearchBarDelegate {
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        currentSearchText = ""
        filteredTemplates = []
        filteredRecentScenes = []
        collectionView.reloadData()

        // Hide the search controller and remove from nav bar
        searchController.isActive = false
        navigationItem.searchController = nil

        // Restore the search button to nav bar
        if let savedItems = savedRightBarButtonItems {
            navigationItem.rightBarButtonItems = savedItems
        }
    }
}

// MARK: - UISearchControllerDelegate

extension HomeViewController: UISearchControllerDelegate {
    func willDismissSearchController(_ searchController: UISearchController) {
        // Clear search state before dismissing
        currentSearchText = ""
        filteredTemplates = []
        filteredRecentScenes = []
        collectionView.reloadData()
    }

    func didDismissSearchController(_ searchController: UISearchController) {
        // Restore the search button when search controller is dismissed
        navigationItem.searchController = nil
        if let savedItems = savedRightBarButtonItems {
            navigationItem.rightBarButtonItems = savedItems
        }
    }
}
