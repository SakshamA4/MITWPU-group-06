//
//  CharacterViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 10/12/25.
//
import UIKit

class CharacterViewController: UIViewController {
    
    @IBOutlet weak var characterTitle: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!
    
    //Inputs
    var characterNameInput: String = ""
    
    // Film passed from previous screen
    var film: Film?
    
    // Shared DataStore
    var dataStore: DataStore = DataStore.shared
    
    // Characters for this film
    var characters: [CharacterItem] = []
    
    // The currently selected character
    var character: CharacterItem?
    
    var delegate: AddCharacterDelegate?
    
    private let posesCellId = "poses_cell"
    private let infoCellId = "info_cell"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        registerCells()
        
        // Load data
     //   dataStore.loadData()
        
        // Load characters belonging to the film
        if let film = film {
            characters = dataStore.getCharactersByFilmId(filmId: film.id)
        } else {
            characters = dataStore.getCharacters()
        }
        
        updateTitle()
        
        // Apply compositional layout
        collectionView.collectionViewLayout = createLayout()
        
        collectionView.dataSource = self
        collectionView.delegate = self
        
        collectionView.reloadData()
    }
    
    private func updateTitle() {
        characterTitle.text = character?.name ?? "Character"
    }
    
    private func registerCells() {
        collectionView.register(UINib(nibName: "CharacterInfoCollectionViewCell", bundle: nil),
                                forCellWithReuseIdentifier: infoCellId)
        
        collectionView.register(UINib(nibName: "CharacterPosesCollectionViewCell", bundle: nil),
                                forCellWithReuseIdentifier: posesCellId)
    }
    
    
    // MARK: - Layout
    func createLayout() -> UICollectionViewCompositionalLayout {
        return UICollectionViewCompositionalLayout { section, _ in
            
            if section == 0 {
                // Large info cell section
                let item = NSCollectionLayoutItem(
                    layoutSize: .init(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .fractionalHeight(1)
                    )
                )
                
                let group = NSCollectionLayoutGroup.vertical(
                    layoutSize: .init(
                        widthDimension: .fractionalWidth(0.9),
                        heightDimension: .fractionalHeight(0.6)
                    ),
                    subitems: [item]
                )
                
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = .init(top: 10, leading: 10, bottom: 10, trailing: 10)
                return section
            }
            
            else {
                // Section 1 → Horizontal pose cells
                let item = NSCollectionLayoutItem(
                    layoutSize: .init(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .fractionalHeight(1)
                    )
                )
                
                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: .init(
                        widthDimension: .fractionalWidth(0.2),
                        heightDimension: .absolute(300)
                    ),
                    subitems: [item]
                )
                
                let section = NSCollectionLayoutSection(group: group)
                section.orthogonalScrollingBehavior = .continuous
                section.contentInsets = .init(top: 10, leading: 10, bottom: 10, trailing: 10)
                section.interGroupSpacing = 10
                
                return section
            }
        }
    }
    
    
    @IBAction func addButtonTapped(_ sender: Any) {
        
        guard let film = film,
              var selectedCharacter = character else {
            return
        }

        // 2. Create a NEW character instance for this film
        selectedCharacter.id = UUID()          // important: avoid overwriting template
        selectedCharacter.filmId = film.id     // attach character to this film
        if(characterNameInput != "" ){
            selectedCharacter.name = characterNameInput        }

        // 3. Notify parent (MyFilmViewController)
        delegate?.addCharacter(character: selectedCharacter)

        // 4. Navigate back (PUSH navigation, not modal)
//        navigationController?.popToRootViewController(animated: true)
        dismiss(animated: true)
    }
    
    
}


// MARK: - Data Source
extension CharacterViewController: UICollectionViewDataSource, UpdateCharacterInfoDelegate {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        2
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        
        if section == 0 {
            return 1
        }
        
        return character?.pose.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath)
    -> UICollectionViewCell {
        
        if indexPath.section == 0 {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: infoCellId,
                for: indexPath
            ) as! CharacterInfoCollectionViewCell
            
            if let character = character {
                cell.configureCell(character: character, delegate: self)
            }
            return cell
        }
        
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: posesCellId,
            for: indexPath
        ) as! CharacterPosesCollectionViewCell
        
        if let pose = character?.pose[indexPath.item] {
            cell.configure(with: pose)
        }
        
        return cell
    }
    
    func updateName(text: String) {
//        print("ext", text)
        characterNameInput = text
    }
}


// MARK: - Delegate (optional)
extension CharacterViewController: UICollectionViewDelegate {
 
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        guard indexPath.section == 1 else { return }

    }
    
    
}
