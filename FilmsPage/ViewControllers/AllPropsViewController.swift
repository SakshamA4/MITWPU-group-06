//
//  PropsViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 08/12/25.
//

import UIKit

class AllPropsViewController: UIViewController, UICollectionViewDataSource {

    private var selectedProp: PropItem?
    var film: Film?

    @IBOutlet weak var collectionView: UICollectionView!
    
    private let propCellId = "prop_cell"
    var prop: [PropItem] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()


        
        collectionView.register(UINib(nibName: "PropsCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "prop_cell")
        

        collectionView.dataSource = self
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 8
        collectionView.setCollectionViewLayout(layout, animated: false)
        collectionView.dataSource = self
        collectionView.delegate = self
        
//        let longPressGesture = UILongPressGestureRecognizer(
//            target: self,
//            action: #selector(handleLongPress(_:))
//        )
//        collectionView.addGestureRecognizer(longPressGesture)
//        // Do any additional setup after loading the view.
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.collectionView?.collectionViewLayout.invalidateLayout()
        })
    }

    
//    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
//        guard gesture.state == .began else { return }
//
//        let point = gesture.location(in: collectionView)
//
//        guard let indexPath = collectionView.indexPathForItem(at: point) else {
//            return
//        }
//
//        let selectedProp = prop[indexPath.item]
//        showPropActionSheet(for: selectedProp, at: indexPath)
//    }
//
//    private func showPropActionSheet(for propItem: PropItem, at indexPath: IndexPath) {
//        let alert = UIAlertController(
//            title: propItem.name,
//            message: "What would you like to do?",
//            preferredStyle: .actionSheet
//        )
//
//        alert.addAction(UIAlertAction(title: "Edit", style: .default) { _ in
//            self.editProp(propItem, at: indexPath)
//        })
//
//        alert.addAction(UIAlertAction(title: "Remove", style: .destructive) { _ in
//            self.removeProp(at: indexPath)
//        })
//
//        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
//
//        present(alert, animated: true)
//    }
//
//    private func removeProp(at indexPath: IndexPath) {
//        prop.remove(at: indexPath.item)
//        collectionView.deleteItems(at: [indexPath])
//    }

    private func editProp(_ propItem: PropItem, at indexPath: IndexPath) {
        selectedProp = propItem
        performSegue(withIdentifier: "editPropSegue", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "editPropSegue" {
            guard
                let destination = segue.destination as? PropDetailViewController,
                let prop = selectedProp
            else { return }

            destination.prop = prop
        }
    }


    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return prop.count 
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "prop_cell",
            for: indexPath
        ) as? PropsCollectionViewCell else {
            return UICollectionViewCell()
        }

        cell.configureCell(prop: prop[indexPath.row])
        return cell
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

extension AllPropsViewController: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let inset: CGFloat = 40
        let interItem: CGFloat = 40
        let columns: CGFloat = 4
        let totalSpacing = inset * 2 + interItem * (columns - 1)
        let width = (collectionView.bounds.width - totalSpacing) / columns
        return CGSize(width: width, height: width)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 16, left: 52, bottom: 16, right: 52)
    }
}


extension AllPropsViewController {
    
    // MARK: - Context Menu
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggestedActions in
            
            let propItem = self.prop[indexPath.item]
            
            // 1. Edit Action
            let editAction = UIAction(title: "Edit", image: UIImage(systemName: "pencil")) { [weak self] _ in
                self?.selectedProp = propItem
                self?.performSegue(withIdentifier: "editPropSegue", sender: self)
            }
            
            // 2. Delete Action
            let deleteAction = UIAction(title: "Remove", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.deleteProp(propItem)
            }
            
            return UIMenu(title: propItem.name, children: [editAction, deleteAction])
        }
    }
    
    private func deleteProp(_ item: PropItem) {
        // We need the film ID to remove the prop association
        guard let film = self.film, let propId = item.id else {
            print("Error: Missing Film or Prop ID")
            return
        }
        
        PropService.shared.removeProp(propId, fromFilmId: film.id)
        
        // Manual Reload if you don't have an observer set up:
        // self.prop.removeAll { $0.id == item.id }
        // self.collectionView.reloadData()
        
        // BETTER: Add Observer in viewDidLoad like other screens:
        // NotificationCenter.default.post(name: NSNotification.Name(NotificationNames.propsUpdated), object: nil)
    }
}
