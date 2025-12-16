//
//  BackgroundViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 08/12/25.
//

import UIKit

class BackgroundViewController: UIViewController {
    
    // MARK: - Outlets
    @IBOutlet weak var backgroundCollectionView: UICollectionView!
    
    // MARK: - Data
    private var items: [BackgroundItem] = BackgroundData.allBackgrounds
    
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
private extension BackgroundViewController {
    
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
        let nib = UINib(nibName: "BackgroundCollectionViewCell", bundle: nil)
        backgroundCollectionView.register(nib,
                                          forCellWithReuseIdentifier: BackgroundCollectionViewCell.reuseIdentifier)
        
        backgroundCollectionView.dataSource = self
        backgroundCollectionView.delegate = self
        backgroundCollectionView.backgroundColor = .clear
        backgroundCollectionView.showsVerticalScrollIndicator = false
    }
    
    func configureFlowLayout() {
        // Make sure we are working with a flow layout
        guard let layout = backgroundCollectionView.collectionViewLayout as? UICollectionViewFlowLayout else {
            let layout = UICollectionViewFlowLayout()
            backgroundCollectionView.setCollectionViewLayout(layout, animated: false)
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
        
        let width = backgroundCollectionView.bounds.width
        let totalSpacing = (2 * sectionInset) + ((itemsPerRow - 1) * interItemSpacing)
        let itemWidth = floor((width - totalSpacing) / itemsPerRow)
        
        layout.itemSize = CGSize(width: itemWidth, height: itemWidth)
        layout.invalidateLayout()
    }

}

// MARK: - Data Source
extension BackgroundViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }
    
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        items.count
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: BackgroundCollectionViewCell.reuseIdentifier,
            for: indexPath
        ) as? BackgroundCollectionViewCell else {
            return UICollectionViewCell()
        }
        cell.configure(with: items[indexPath.item])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        print("Selected background:", items[indexPath.item].title)
    }
}

// MARK: - Add Background


private extension BackgroundViewController {
    
    @objc func addBackgroundTapped() {
        let alert = UIAlertController(title: "New Background",
                                      message: "Enter a name for the new background",
                                      preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Background name" }
        
        let addAction = UIAlertAction(title: "Add", style: .default) { [weak self] _ in
            guard let self = self else { return }
            _ = alert.textFields?.first?.text?.isEmpty == false
                ? alert.textFields?.first?.text!
                : "New Background"
            
            let newItem = BackgroundItem(title: "name", imageName: "bg_placeholder")
            BackgroundData.addBackground(newItem)
            self.items = BackgroundData.allBackgrounds
            
            let newIndexPath = IndexPath(item: self.items.count - 1, section: 0)
            self.backgroundCollectionView.insertItems(at: [newIndexPath])
        }
        
        alert.addAction(addAction)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}
