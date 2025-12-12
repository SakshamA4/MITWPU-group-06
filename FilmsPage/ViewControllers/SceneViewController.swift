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
    
    // MARK: - Data
    private var items: [SceneItem] = SceneData.allScenes
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor(hex: "#060714")
//        setupNavigationBar()
        setupCollectionView()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        configureFlowLayout()
    }
}

// MARK: - Setup
private extension SceneViewController {
    
//    func setupNavigationBar() {
//
//        navigationController?.navigationBar.prefersLargeTitles = false
//        navigationController?.navigationBar.tintColor = .white
//
//        let addButton = UIBarButtonItem(barButtonSystemItem: .add,
//                                        target: self,
//                                        action: #selector(addBackgroundTapped))
//        navigationItem.rightBarButtonItem = addButton
//    }
    
    func setupCollectionView() {
        //  Register the cell (required if using a XIB)
        let nib = UINib(nibName: "SceneCollectionViewCell", bundle: nil)
        SceneCollectionView.register(nib,
                                          forCellWithReuseIdentifier: SceneCollectionViewCell.reuseIdentifier)
        
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
            top: 32,
            left: sectionInset,
            bottom: 32,
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
        items.count
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: SceneCollectionViewCell.reuseIdentifier,
            for: indexPath
        ) as? SceneCollectionViewCell else {
            return UICollectionViewCell()
        }
        cell.configure(with: items[indexPath.item])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        print("Selected Scene:", items[indexPath.item].title)
    }
}

// MARK: - Add Background


private extension SceneViewController {
    
    @objc func addSceneTapped() {
        let alert = UIAlertController(title: "New Scene",
                                      message: "Enter a name for the new Scene",
                                      preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Scene name" }
        
        let addAction = UIAlertAction(title: "Add", style: .default) { [weak self] _ in
            guard let self = self else { return }
            _ = alert.textFields?.first?.text?.isEmpty == false
                ? alert.textFields?.first?.text!
                : "New Scene"
            
            let newItem = SceneItem(title: "name", imageName: "Scene_placeholder")
            SceneData.addScene(newItem)
            self.items = SceneData.allScenes
            
            let newIndexPath = IndexPath(item: self.items.count - 1, section: 0)
            self.SceneCollectionView.insertItems(at: [newIndexPath])
        }
        
        alert.addAction(addAction)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}

