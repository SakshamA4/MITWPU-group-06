//
//  PropsViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 08/12/25.
//

import UIKit

class AllPropsViewController: UIViewController, UICollectionViewDataSource {

    private var selectedProp: PropItem?

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
        
        let longPressGesture = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleLongPress(_:))
        )
        collectionView.addGestureRecognizer(longPressGesture)
        // Do any additional setup after loading the view.
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }

        let point = gesture.location(in: collectionView)

        guard let indexPath = collectionView.indexPathForItem(at: point) else {
            return
        }

        let selectedProp = prop[indexPath.item]
        showPropActionSheet(for: selectedProp, at: indexPath)
    }

    private func showPropActionSheet(for propItem: PropItem, at indexPath: IndexPath) {
        let alert = UIAlertController(
            title: propItem.name,
            message: "What would you like to do?",
            preferredStyle: .actionSheet
        )

        alert.addAction(UIAlertAction(title: "Edit", style: .default) { _ in
            self.editProp(propItem, at: indexPath)
        })

        alert.addAction(UIAlertAction(title: "Remove", style: .destructive) { _ in
            self.removeProp(at: indexPath)
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        present(alert, animated: true)
    }

    private func removeProp(at indexPath: IndexPath) {
        prop.remove(at: indexPath.item)
        collectionView.deleteItems(at: [indexPath])
    }

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
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "prop_cell",
            for: indexPath
        ) as! PropsCollectionViewCell

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
