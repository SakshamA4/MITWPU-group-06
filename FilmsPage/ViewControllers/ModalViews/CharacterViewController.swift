//
//  CharacterViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 10/12/25.
//

import UIKit

class CharacterViewController: UIViewController {

    @IBOutlet weak var nameTextField: UITextField!      // Input for character name
    @IBOutlet weak var characterTitle: UILabel!         // Display entered name
    @IBOutlet weak var collectionView: UICollectionView!

    var film: Film?
    // use the shared datastore
    var dataStore: DataStore = DataStore.shared

    // store characters for the current film
    var characters: [Character] = []

    // currently selected/created character whose poses we display
    var character: Character?

    private let posesCellId = "poses_cell"

    override func viewDidLoad() {
        super.viewDidLoad()

        registerCells()
        collectionView.delegate = self
        collectionView.dataSource = self

        // load datastore (if you rely on loadData to populate defaults)
        dataStore.loadData()

        // load characters for the current film (if film is nil, load all characters)
        if let film = film {
            characters = dataStore.getCharactersByFilmId(filmId: film.id)
        } else {
            characters = dataStore.getCharacters()
        }

        // If there is at least one character for the film, show the first one's poses by default
        if let first = characters.first {
            character = first
        }

        updateTitle()
        collectionView.reloadData()
    }

    private func updateTitle() {
        characterTitle.text = character?.name ?? "Character"
    }

    func registerCells() {
        collectionView.register(UINib(nibName: "CharacterPosesCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: posesCellId)
    }

    @IBAction func nameTextChanged(_ sender: UITextField) {
        characterTitle.text = sender.text
    }

    @IBAction func addButtonTapped(_ sender: UIButton) {
        guard let name = nameTextField.text, !name.isEmpty,
              let film = film else {
            // show an alert if film is missing or name empty (optional)
            let alert = UIAlertController(title: "Error", message: "Please enter a name and make sure a film is selected.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        // Get fixed poses from datastore
        let fixedPoses = dataStore.getFixedPoses()

        // Create new character
        let newCharacter = Character(
            id: UUID(),
            name: name,
            image: "Image",          // default image
            filmId: film.id,
            pose: fixedPoses
        )

        // Add character to datastore (use the public API)
        dataStore.addCharacter(newCharacter)

        // Add to local array and set as currently selected
        characters.append(newCharacter)
        self.character = newCharacter

        // Reload collection view to show poses
        collectionView.reloadData()

        // Clear input
        nameTextField.text = ""
        characterTitle.text = "Character"
    }
}

// MARK: - CollectionView DataSource
extension CharacterViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return character?.pose.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: posesCellId, for: indexPath) as! CharacterPosesCollectionViewCell
        if let pose = character?.pose[indexPath.item] {
            cell.configure(with: pose)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Optional: if you want selecting a character pose to do something
    }
}
