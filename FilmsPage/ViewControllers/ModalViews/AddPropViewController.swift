//
//  PropViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 08/12/25.
//

import UIKit

class AddPropViewController: UIViewController {

    @IBOutlet weak var collectionView: UICollectionView!
    
    var prop: [Prop] = []
    var dataStore: DataStore?
    var film: Film?
    let propCellId = "prop_cell"
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dataStore?.loadData()
        prop = dataStore?.getProps() ?? []
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 20
        layout.minimumInteritemSpacing = 8
        collectionView.setCollectionViewLayout(layout, animated: false)
        registerCells()
        collectionView.dataSource = self
        collectionView.delegate = self
        
        collectionView.reloadData()

        // Do any additional setup after loading the view.
    }
    

    func registerCells() {

            collectionView.register(UINib(nibName: "PropsCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "prop_cell")
        
    }

}

extension AddPropViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: propCellId,
            for: indexPath
        ) as? PropsCollectionViewCell else {
            return UICollectionViewCell()
        }

        let prop = prop[indexPath.item]
        cell.configureCell(prop: prop)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return prop.count
    }
}

extension AddPropViewController: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {

        let inset: CGFloat = 40
        let interItem: CGFloat = 30
        let columns: CGFloat = 4
        let spacing = inset * 2 + interItem * (columns - 1)

        let width = (collectionView.bounds.width - spacing) / columns

        return CGSize(width: width, height: width)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
    }
}
