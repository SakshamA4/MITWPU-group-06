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
    
    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
//        print("Selected Scene:", allScenes[indexPath.item].title)
    }
}

// MARK: - Add Background


private extension SceneViewController {
    
//    @objc func addSceneTapped() {
//        let alert = UIAlertController(title: "New Scene",
//                                      message: "Enter a name for the new Scene",
//                                      preferredStyle: .alert)
//        alert.addTextField { $0.placeholder = "Scene name" }
//        
//        let addAction = UIAlertAction(title: "Add", style: .default) { [weak self] _ in
//            guard let self = self else { return }
//            _ = alert.textFields?.first?.text?.isEmpty == false
//                ? alert.textFields?.first?.text!
//                : "New Scene"
//            
//            let newItem = SceneItem(title: "name", imageName: "Scene_placeholder")
//            SceneData.addScene(newItem)
//            self.items = SceneData.allScenes
//            
//            let newIndexPath = IndexPath(item: self.items.count - 1, section: 0)
//            self.SceneCollectionView.insertItems(at: [newIndexPath])
//        }
//        
//        alert.addAction(addAction)
//        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
//        present(alert, animated: true)
//    }
}

