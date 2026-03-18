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
    
    var scene: [Scene] = []
    var sceneCellId = "scene_cell"
    var sequence: Sequence?
    var filmName: String?   
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        refreshData()

        updateTitle()
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 8
        collectionView.setCollectionViewLayout(layout, animated: false)
        collectionView.dataSource = self
        collectionView.delegate = self
        registerCells()
        setupObservers()
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshData),
            name: NSNotification.Name(NotificationNames.scenesUpdated),
            object: nil
        )
    }
    
    @objc private func refreshData() {
        if let sequence = sequence {
            scene = sceneService.getScenes(forSequenceId: sequence.id)
        }
        collectionView?.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshData()
        updateTitle()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.collectionView?.collectionViewLayout.invalidateLayout()
        })
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

}

extension SequenceViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        // Index 0 → placeholder cell
        if indexPath.item == 0 {
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "placeholder_cell",
                for: indexPath
            ) as? PlaceholderCollectionViewCell else { return UICollectionViewCell() }
            
            cell.onPlusButtonTapped = { [weak self] in
                self?.performSegue(withIdentifier: "addSceneSegue", sender: nil)
            }
            return cell
        }
        
        // Index 1+ → scene cells
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: sceneCellId,
            for: indexPath
        ) as? SceneCollectionViewCell else { return UICollectionViewCell() }
        
        cell.configureCell(scene: scene[indexPath.item - 1])  // -1 to offset placeholder
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        return scene.count + 1
    }
}

extension SequenceViewController: UICollectionViewDelegate,
    UICollectionViewDelegateFlowLayout
{
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "addSceneSegue" {
            let vc = segue.destination as! AddSceneViewController
            vc.sequence = sequence
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
        guard indexPath.item != 0 else { return }  // ignore placeholder tap
        
        let selectedScene = scene[indexPath.item - 1]  // -1 offset
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
        guard indexPath.item != 0 else { return nil }
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggestedActions in
            
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
        let sceneToDelete = scene[indexPath.item - 1]  // -1 to offset placeholder at index 0
        sceneService.deleteScene(by: sceneToDelete.id)
    }
    
    private func presentEditAlert(at indexPath: IndexPath) {
            let currentScene = scene[indexPath.item - 1]
            
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
                
                self.scene[indexPath.item - 1] = updatedScene
                
                self.collectionView.reloadItems(at: [indexPath])
            }
            
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
            
            alert.addAction(saveAction)
            alert.addAction(cancelAction)
            
            present(alert, animated: true)
        }
}
