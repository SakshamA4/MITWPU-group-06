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
    
    // Film passed from previous screen
    var film: Film?
    
    // Shared DataStore
    var dataStore: DataStore = DataStore.shared
    
    // Characters for this film
    var characters: [Character] = []
    
    // The currently selected character
    var character: Character?
    
    private let posesCellId = "poses_cell"
    private let infoCellId = "info_cell"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        registerCells()
        
        // Load data
        dataStore.loadData()
        
        // Load characters belonging to the film
        if let film = film {
            characters = dataStore.getCharactersByFilmId(filmId: film.id)
        } else {
            characters = dataStore.getCharacters()
        }
        
        // Use first character by default
        if let first = characters.first {
            character = first
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
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .fractionalHeight(0.45)
                    ),
                    subitems: [item]
                )
                
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = .init(top: 10, leading: 10, bottom: 10, trailing: 10)
                return section
            }
            
            // Section 1 → Horizontal pose cells
            let item = NSCollectionLayoutItem(
                layoutSize: .init(
                    widthDimension: .absolute(100),
                    heightDimension: .absolute(100)
                )
            )
            
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: .init(
                    widthDimension: .estimated(100),
                    heightDimension: .absolute(100)
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


// MARK: - Data Source
extension CharacterViewController: UICollectionViewDataSource {
    
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
                cell.configureCell(character: character)
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
}


// MARK: - Delegate (optional)
extension CharacterViewController: UICollectionViewDelegate {}
