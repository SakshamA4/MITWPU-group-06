//
//  CharacterViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 08/12/25.
//
import UIKit

class AddCharacterViewController: UIViewController {

    // MARK: - Services
    private let characterService = CharacterService.shared

    // MARK: - Inputs
    var film: Film!

    // MARK: - UI
    @IBOutlet weak var collectionView: UICollectionView!

    // MARK: - Data
    private var characters: [CharacterItem] = []

    private let characterCellId = "character_cell"

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        loadCharacters()
        setupCollectionView()
    }

    private func loadCharacters() {
        characters = characterService.getCharacters()
    }

    private func setupCollectionView() {
        collectionView.register(
            UINib(nibName: "CharactersCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: characterCellId
        )

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 20
        layout.minimumInteritemSpacing = 8
        collectionView.setCollectionViewLayout(layout, animated: false)

        collectionView.dataSource = self
        collectionView.delegate = self
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.collectionView?.collectionViewLayout.invalidateLayout()
        }, completion: nil)
    }

}

extension AddCharacterViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        characters.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: characterCellId,
            for: indexPath
        ) as? CharactersCollectionViewCell else {
            return UICollectionViewCell()
        }

        let characterItem = characters[indexPath.item]
        cell.configureForLibrary(character: characterItem)

        return cell
    }
}

extension AddCharacterViewController: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {

        let characterItem = characters[indexPath.item]
        performSegue(withIdentifier: "characterDetailSegue", sender: characterItem)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard segue.identifier == "characterDetailSegue",
              let vc = segue.destination as? CharacterDetailsViewController,
              let character = sender as? CharacterItem else { return }

        // FIX: Assign to characterTemplate
        vc.characterTemplate = character
        vc.film = film
    }

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
        UIEdgeInsets(top: 16, left: 52, bottom: 16, right: 52)
    }
}
