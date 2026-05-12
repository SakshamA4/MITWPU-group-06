//
//  BackgroundViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 08/12/25.
//

import UIKit
import PhotosUI

class BackgroundViewController: UIViewController {
    
    private var pendingName: String?
    
    @IBOutlet weak var backgroundCollectionView: UICollectionView!
    
    // MARK: - Data
    private var items: [BackgroundItem] {
            return BackgroundStore.shared.items
        }
    
    @IBAction func plusButtonTapped(_ sender: UIButton) {
        presentImagePicker()
    }
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
    
    override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            backgroundCollectionView.reloadData()
        }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.backgroundCollectionView?.collectionViewLayout.invalidateLayout()
        })
    }

}

// MARK: - Setup
private extension BackgroundViewController {
    
    
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
            top: 0,
            left: sectionInset,
            bottom: 0,
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
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: BackgroundCollectionViewCell.reuseIdentifier, for: indexPath) as? BackgroundCollectionViewCell else {
            return UICollectionViewCell()
        }
        cell.configure(with: items[indexPath.item])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedItem = items[indexPath.item]
        print("Selected background:", selectedItem.title)
        
        // CHANGE 2: Trigger the Global Spawn Action
        BackgroundStore.shared.selectBackground(selectedItem)
        
        // Optional: Dismiss if this is a modal
        // dismiss(animated: true)
    }
}

// MARK: - Add Background Logic & Picker Delegate
extension BackgroundViewController: PHPickerViewControllerDelegate {
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else { return }
        
        provider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
            guard let self = self, let uiImage = image as? UIImage else { return }
            DispatchQueue.main.async {
                self.presentNameAlert(for: uiImage)
            }
        }
    }
}

private extension BackgroundViewController {
    
    func presentImagePicker() {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    func presentNameAlert(for image: UIImage) {
        let alert = UIAlertController(title: "Name your Background", message: "Enter a name for this image", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Background Name" }
        
        let saveAction = UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self = self else { return }
            let name = alert.textFields?.first?.text ?? "New Background"
            self.saveNewBackground(name: name, image: image)
        }
        
        alert.addAction(saveAction)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    func saveNewBackground(name: String, image: UIImage) {
        let newItem = BackgroundItem(title: name, imageName: nil, customImage: image)
        
        // CHANGE 3: Update Global Store
        BackgroundStore.shared.addBackground(newItem)
        
        // Insert into Collection View
        let newIndexPath = IndexPath(item: 0, section: 0)
        self.backgroundCollectionView.insertItems(at: [newIndexPath])
        self.backgroundCollectionView.scrollToItem(at: newIndexPath, at: .top, animated: true)
    }
}
