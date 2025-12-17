//
//  CharacterViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 08/12/25.
//

import UIKit

protocol AddCharacterDelegate {
    func addCharacter(character: CharacterItem)
}

class AddCharacterViewController: UIViewController {

    private let characterService = CharacterService.shared
    var film: Film?   // The film we are adding characters to

    @IBOutlet weak var collectionView: UICollectionView!
    
    var addCharacterDelegate: AddCharacterDelegate?
    

    var characters: [CharacterItem] = []
    let characterCellId = "character_cell"

    override func viewDidLoad() {
        super.viewDidLoad()

        characters = characterService.getCharacters()



        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 20
        layout.minimumInteritemSpacing = 8
        collectionView.setCollectionViewLayout(layout, animated: false)

        collectionView.dataSource = self
        collectionView.delegate = self

        registerCells()
        collectionView.reloadData()
    }
    
    func registerCells() {

            collectionView.register(UINib(nibName: "CharactersCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "character_cell")
        
    }

}



extension AddCharacterViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: characterCellId,
            for: indexPath
        ) as? CharactersCollectionViewCell else {
            return UICollectionViewCell()
        }

        let characterItem = characters[indexPath.item]
        cell.configureCell(character: characterItem)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return characters.count
    }
}

extension AddCharacterViewController: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {

        let characterItem = characters[indexPath.item]
        performSegue(withIdentifier: "characterDetailSegue", sender: characterItem)
    }
    

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "characterDetailSegue" {
            let vc = segue.destination as! CharacterDetailsViewController
            vc.character = sender as? CharacterItem
            vc.film = film
            vc.delegate = addCharacterDelegate
        } }
    

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {

        let inset: CGFloat = 40
        let interItem: CGFloat = 30
        let columns: CGFloat = 3
        let spacing = inset * 2 + interItem * (columns - 1)

        let width = (collectionView.bounds.width - spacing) / columns

        return CGSize(width: width, height: width - 40)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 16, left: 52, bottom: 16, right: 52)
    }
    
}
