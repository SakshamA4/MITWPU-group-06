//
//  BackgroundViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 08/12/25.
//

import UIKit

class SceneViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet weak var SceneCollectionView: UICollectionView!
    

    private let sceneStore = ScenesDataStore.shared
    private var allScenes: [ScenesModel] = []


    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor(hex: "#060714")
        setupCollectionView()
        loadData()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScenesUpdate),
            name: ScenesDataStore.scenesUpdatedNotification,
            object: nil
        )
    }
    
    private func loadData() {
        let recent = sceneStore.currentRecentScenes
        let templates = sceneStore.currentTemplates

        // Remove templates that already exist in recent
        let recentIds = Set(recent.map { $0.id })
        let filteredTemplates = templates.filter { !recentIds.contains($0.id) }

        // Merge: recent first, templates next
        allScenes = recent + filteredTemplates

        SceneCollectionView.reloadData()
    }

    @objc private func handleScenesUpdate() {
        loadData()
    }

    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        configureFlowLayout()
    }
}

private func deleteScene(_ model: ScenesModel) {
    ScenesDataStore.shared.deleteScene(by: model.id)
}

// MARK: - Setup
private extension SceneViewController {
    
    
    func setupCollectionView() {
        //  Register the cell (required if using a XIB)
        let nib = UINib(nibName: "LibrarySceneCollectionViewCell", bundle: nil)
        SceneCollectionView.register(nib,
                                          forCellWithReuseIdentifier: LibrarySceneCollectionViewCell.reuseIdentifier)
        
        SceneCollectionView.dataSource = self
        SceneCollectionView.delegate = self
        SceneCollectionView.backgroundColor = .clear
        SceneCollectionView.showsVerticalScrollIndicator = false
    }
    private func deleteScene(_ model: ScenesModel) {
        ScenesDataStore.shared.deleteScene(by: model.id)
        // loadData() is called automatically via NotificationCenter observer
    }
    
    
    func configureFlowLayout() {
            // Make sure we are working with a flow layout
            guard let layout = SceneCollectionView.collectionViewLayout as? UICollectionViewFlowLayout else {
                let layout = UICollectionViewFlowLayout()
                SceneCollectionView.setCollectionViewLayout(layout, animated: false)
                configureFlowLayout()
                return
            }
            
            layout.scrollDirection = .vertical
            layout.estimatedItemSize = .zero    //  important: use our itemSize, not auto-layout sizing
            
            let itemsPerRow: CGFloat = 4
            let sectionInset: CGFloat = 80
            let interItemSpacing: CGFloat = 35
            let lineSpacing: CGFloat = 35
            
            layout.sectionInset = UIEdgeInsets(
                top: 0,
                left: sectionInset,
                bottom: 0,
                right: sectionInset
            )
            layout.minimumInteritemSpacing = interItemSpacing
            layout.minimumLineSpacing = lineSpacing
            
            let width = SceneCollectionView.bounds.width
            let totalSpacing = (2 * sectionInset) + ((itemsPerRow - 1) * interItemSpacing)
            let itemWidth = floor((width - totalSpacing) / itemsPerRow)
            
            layout.itemSize = CGSize(width: itemWidth, height: itemWidth)
            layout.invalidateLayout()
        }
}

// MARK: - Data Source
extension SceneViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }
    
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        allScenes.count
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: LibrarySceneCollectionViewCell.reuseIdentifier,
            for: indexPath
        ) as? LibrarySceneCollectionViewCell else {
            return UICollectionViewCell()
        }
        cell.configure(with: allScenes[indexPath.item])
        return cell
    }
    
//    func collectionView(_ collectionView: UICollectionView,
//                        didSelectItemAt indexPath: IndexPath) {
//        let vc = CanvasViewController()
//       // navigationController?.pushViewController(vc, animated: true)
//        let navController = UINavigationController(rootViewController: vc)
//        navController.modalPresentationStyle = .fullScreen
//        self.present(navController, animated: true)
//    }
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        //let selectedSceneModel = allScenes[indexPath.item]
        let selectedModel = allScenes[indexPath.item]
        let vc = CanvasViewController()
        vc.currentSceneID = selectedModel.id   // FIX: was missing — caused saves to never load from Library
        vc.sceneName = selectedModel.name
        vc.sceneNotes = selectedModel.notes ?? ""
        vc.sceneImageName = selectedModel.image  
        let navController = UINavigationController(rootViewController: vc)
        navController.modalPresentationStyle = .fullScreen
        self.present(navController, animated: true)
    }
}

extension SceneViewController {
    func collectionView(
        _ collectionView: UICollectionView,
        contextMenuConfigurationForItemAt indexPath: IndexPath,
        point: CGPoint
    ) -> UIContextMenuConfiguration? {

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let model = self.allScenes[indexPath.item]

            let renameAction = UIAction(
                title: "Edit Name",
                image: UIImage(systemName: "pencil")
            ) { [weak self] _ in
                self?.presentRenameAlert(for: model, at: indexPath)
            }

            let deleteAction = UIAction(
                title: "Delete",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { [weak self] _ in
                self?.deleteScene(model)
            }

            return UIMenu(title: model.name, children: [renameAction, deleteAction])
        }
    }



    private func presentRenameAlert(for model: ScenesModel, at indexPath: IndexPath) {
        let alert = UIAlertController(title: "Edit Name", message: nil, preferredStyle: .alert)

        alert.addTextField { tf in
            tf.text = model.name
            tf.placeholder = "Scene Name"
            tf.autocapitalizationType = .words
        }

        let saveAction = UIAlertAction(title: "Save", style: .default) { _ in
            guard let newName = alert.textFields?.first?.text, !newName.isEmpty else { return }
            var updated = model
            updated.name = newName
            ScenesDataStore.shared.updateScene(updated)
        }

        alert.addAction(saveAction)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}

