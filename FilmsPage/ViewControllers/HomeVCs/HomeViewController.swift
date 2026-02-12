//
//  HomeViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 28/11/25.
//
import UIKit

class HomeViewController: UIViewController, UICollectionViewDelegate {

    @IBOutlet weak var collectionView: UICollectionView!
    
    // Local Data Source (Mirrors the Store)
    private var templates: [ScenesModel] = []
    private var recentScenes: [ScenesModel] = []
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        setupObservers()
        refreshData() // Initial load
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // 📍 THE FIX: Refresh data from the store to show updated notes/scenes
        refreshData()
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
    }
    
    @objc private func handleScenesUpdated() {
        refreshData()
    }
    
    private func refreshData() {
        // 1. Fetch latest data from the Single Source of Truth
        templates = ScenesDataStore.shared.currentTemplates
        recentScenes = ScenesDataStore.shared.currentRecentScenes
        
        // 2. Reload UI
        collectionView.reloadData()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // No delegate setup needed - using NotificationCenter
    }
}

// MARK: - CollectionView DataSource
extension HomeViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return section == 0 ? templates.count : recentScenes.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "templates_cell", for: indexPath) as! TemplatesCollectionViewCell
            let item = templates[indexPath.row]
            cell.templateLabel.text = item.name
            cell.templatesImageView.image = UIImage(named: item.image ?? "Image")
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "recentscenes_cell", for: indexPath) as! RecentScenesCollectionViewCell
            let item = recentScenes[indexPath.row]
            cell.recentLabel.text = item.name
            cell.recentImageView.image = UIImage(named: item.image ?? "Image")
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader else { return UICollectionReusableView() }
        
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "home_header_view", for: indexPath) as! HomeHeaderView
        header.titleLabel.text = indexPath.section == 0 ? "Templates" : "Recent Scenes"
        return header
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedModel = (indexPath.section == 0) ? templates[indexPath.row] : recentScenes[indexPath.row]
        let vc = CanvasViewController()
        
        // Ensure the Canvas tracks the ID from the Home page
        vc.currentSceneID = selectedModel.id
        vc.sceneName = selectedModel.name
        vc.sceneNotes = selectedModel.notes ?? ""
        vc.sceneImageName = selectedModel.image
        
        let navController = UINavigationController(rootViewController: vc)
        navController.modalPresentationStyle = .fullScreen
        self.present(navController, animated: true)
    }
}



extension HomeViewController {
    func createCompositionalLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { sectionIndex, _ in
            
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
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggestedActions in
            
            // Get the model used in the view
            let sceneModel = self.recentScenes[indexPath.item]
            
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
        SceneService.shared.deleteScene(by: sceneModel.id)
        // No need to reload manually; the NotificationCenter observer in viewDidLoad handles it.
    }
    
    private func presentRenameAlert(for sceneModel: ScenesModel) {
        let alert = UIAlertController(title: "Rename Scene", message: nil, preferredStyle: .alert)
        
        alert.addTextField { tf in
            tf.text = sceneModel.name
            tf.placeholder = "Scene Name"
            tf.autocapitalizationType = .words
        }
        
        // FIX 2: Removed [weak self]
        // You are using SceneService.shared (Singleton), so you don't need 'self' here.
        // This fixes the "Variable 'self' was written to, but never read" error.
        let saveAction = UIAlertAction(title: "Save", style: .default) { _ in
            guard let newName = alert.textFields?.first?.text, !newName.isEmpty else { return }
            
            // Fetch and Update using the Service directly
            if let originalScene = SceneService.shared.getScene(by: sceneModel.id) {
                var updatedScene = sceneModel
                updatedScene.name = newName
                
                ScenesDataStore.shared.updateScene(updatedScene)
            }
        }
        
        alert.addAction(saveAction)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
}
