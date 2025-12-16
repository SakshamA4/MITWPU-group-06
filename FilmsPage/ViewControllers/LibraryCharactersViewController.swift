//
//  LibraryCharactersViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 11/12/25.
//

import UIKit

class LibraryCharactersViewController: UIViewController {

    @IBOutlet weak var charactersCollectionView: UICollectionView!

        private var characters = CharactersDataStore.characters   //[CharacterItem]

        override func viewDidLoad() {
            super.viewDidLoad()
            charactersCollectionView.dataSource = self
            charactersCollectionView.delegate = self
            charactersCollectionView.backgroundColor = .clear

            charactersCollectionView.register(
                UINib(nibName: "LibraryCharactersCollectionViewCell", bundle: nil),
                forCellWithReuseIdentifier: "LibraryCharactersCollectionViewCell" )
                

        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            configureLayout()
        }
    private func configureLayout() {
        guard let layout = charactersCollectionView.collectionViewLayout as? UICollectionViewFlowLayout else {
            let newLayout = UICollectionViewFlowLayout()
            charactersCollectionView.setCollectionViewLayout(newLayout, animated: false)
            configureLayout()
            return
        }

        // 🔴 IMPORTANT: disable self-sizing
        layout.estimatedItemSize = .zero

        let columns: CGFloat = 3
        let spacing: CGFloat = 35
        let sideInset: CGFloat = 46
//        let verticalInset: CGFloat = 40

        let width = charactersCollectionView.bounds.width
        guard width > 0 else { return }

        let totalSpacing = spacing * (columns - 1) + sideInset * 2
        let itemWidth = floor((width - totalSpacing) / columns)
        let itemHeight = itemWidth * 0.67

        layout.itemSize = CGSize(width: itemWidth, height: itemHeight)
        layout.minimumInteritemSpacing = spacing
        layout.minimumLineSpacing = spacing
        layout.sectionInset = UIEdgeInsets(top: 0,
                                           left: sideInset,
                                           bottom: 0,
                                           right: sideInset)
        layout.scrollDirection = .vertical
    }

//        private func configureLayout() {
//            guard let layout = charactersCollectionView.collectionViewLayout as? UICollectionViewFlowLayout else {
//                let newLayout = UICollectionViewFlowLayout()
//                charactersCollectionView.setCollectionViewLayout(newLayout, animated: false)
//                configureLayout()
//                return
//            }
//
//            let columns: CGFloat = 3        // visually your characters have 3 per row on iPad
//            let spacing: CGFloat = 32
//            let sideInset: CGFloat = 64
//            let verticalInset: CGFloat = 40
//
//            let width = charactersCollectionView.bounds.width
//            guard width > 0 else { return }
//
//            let totalSpacing = spacing * (columns - 1) + sideInset * 2
//            let itemWidth = floor((width - totalSpacing) / columns)
//            let itemHeight = itemWidth * 0.75   // wider rectangle (thumbnail + label)
//
//            layout.itemSize = CGSize(width: itemWidth, height: itemHeight)
//            layout.minimumInteritemSpacing = spacing
//            layout.minimumLineSpacing = spacing
//            layout.sectionInset = UIEdgeInsets(top: verticalInset,
//                                               left: sideInset,
//                                               bottom: verticalInset,
//                                               right: sideInset)
//            layout.scrollDirection = .vertical
//        }
    
    }

    extension LibraryCharactersViewController: UICollectionViewDataSource {

        func collectionView(_ collectionView: UICollectionView,
                            numberOfItemsInSection section: Int) -> Int {
            characters.count
        }

        func collectionView(_ collectionView: UICollectionView,
                            cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "LibraryCharactersCollectionViewCell",
                for: indexPath
            ) as! LibraryCharactersCollectionViewCell

            cell.configure(with: characters[indexPath.item])
            return cell
        }
    }



    extension LibraryCharactersViewController: UICollectionViewDelegate {}
