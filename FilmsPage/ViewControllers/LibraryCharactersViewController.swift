//
//  LibraryCharactersViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 11/12/25.
//

import UIKit

class LibraryCharactersViewController: UIViewController {

    @IBOutlet weak var charactersCollectionView: UICollectionView!

    private let characterService = CharacterService.shared
    private var characters: [CharacterItem] = []
    
        override func viewDidLoad() {
            super.viewDidLoad()
            charactersCollectionView.dataSource = self
            charactersCollectionView.delegate = self
            charactersCollectionView.backgroundColor = .clear

            charactersCollectionView.register(
                UINib(nibName: "LibraryCharactersCollectionViewCell", bundle: nil),
                forCellWithReuseIdentifier: "LibraryCharactersCollectionViewCell" )
            
            characters = characterService.getCharacters()
                

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

        // IMPORTANT: disable self-sizing
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



extension LibraryCharactersViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {

        let selectedCharacter = characters[indexPath.item]

        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let vc = storyboard.instantiateViewController(
            withIdentifier: "CharacterDetailsViewController"
        ) as? CharacterDetailsViewController else {
            return
        }
        
        vc.character = selectedCharacter


        navigationController?.pushViewController(vc, animated: true)
    }
}
