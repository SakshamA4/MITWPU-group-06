//
//  CharacterDetailsViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 10/12/25.
//
import UIKit

class CharacterDetailsViewController: UIViewController {
    
    @IBOutlet weak var characterTitle: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!
    
    // MARK: - Inputs
    
    // 1. The Film (Required context)
    var film: Film?
    
    // 2. The Existing Character (Use this when EDITING from Film Board)
    var filmCharacter: FilmCharacter?
    
    // 3. The Template (Use this when ADDING from Library)
    var characterTemplate: CharacterItem?
    
    // 4. Temporary storage for the Name being edited
    var characterNameInput: String = ""
    
    // MARK: - Services
    private let characterService = FilmCharacterService.shared
    
    private let posesCellId = "poses_cell"
    private let infoCellId = "info_cell"
    
    // Helper: Gets the visual data (images/poses) regardless of Edit vs Add mode
    private var activeTemplate: CharacterItem? {
        if let template = characterTemplate { return template }
        if let existing = filmCharacter { return characterService.getTemplate(for: existing) }
        return nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // SETUP: Initialize the name input based on mode
        if let existing = filmCharacter {
            // Edit Mode: Use existing override or fallback to template name
            characterNameInput = existing.nameOverride ?? activeTemplate?.name ?? ""
        } else {
            // Add Mode: Use default template name
            characterNameInput = activeTemplate?.name ?? ""
        }

        registerCells()
        updateTitle()

        collectionView.collectionViewLayout = createLayout()
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.reloadData()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.collectionView?.collectionViewLayout.invalidateLayout()
        })
    }
    
    private func updateTitle() {
        // Update the screen title to match the edited name
        characterTitle.text = characterNameInput.isEmpty ? "Character" : characterNameInput
    }
    
    private func registerCells() {
        collectionView.register(UINib(nibName: "CharacterInfoCollectionViewCell", bundle: nil),
                                forCellWithReuseIdentifier: infoCellId)
        
        collectionView.register(UINib(nibName: "CharacterPosesCollectionViewCell", bundle: nil),
                                forCellWithReuseIdentifier: posesCellId)
        collectionView.register(UINib(nibName: "PoseTitleCollectionReusableView",bundle: nil),forSupplementaryViewOfKind: "header",withReuseIdentifier: "header_cell")
    }
    
    // MARK: - Layout
    func createLayout() -> UICollectionViewCompositionalLayout {
        return UICollectionViewCompositionalLayout { section, _ in
            let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(50))
            let headerItem = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: "header", alignment: .top)
            
            if section == 0 {
                // Info Section
                let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1)))
                let group = NSCollectionLayoutGroup.vertical(layoutSize: .init(widthDimension: .fractionalWidth(0.9), heightDimension: .fractionalHeight(0.6)), subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = .init(top: 10, leading: 10, bottom: 10, trailing: 10)
                return section
            } else {
                // Poses Section
                let item = NSCollectionLayoutItem(layoutSize: .init(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1)))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: .init(widthDimension: .fractionalWidth(0.2), heightDimension: .absolute(300)), subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.orthogonalScrollingBehavior = .continuous
                section.contentInsets = .init(top: 10, leading: 30, bottom: 10, trailing: 10)
                section.interGroupSpacing = 20
                section.boundarySupplementaryItems = [headerItem]
                return section
            }
        }
    }
    
    // MARK: - SAVE / ADD ACTION
    @IBAction func addButtonTapped(_ sender: Any) {
        guard let film = film else { return }

        // MODE A: Update Existing Character
        if let existingChar = filmCharacter {
            var updatedChar = existingChar
            updatedChar.nameOverride = characterNameInput // Save the new name
            
            characterService.updateCharacter(updatedChar)
            print("Updated character: \(updatedChar.nameOverride ?? "nil")")
        }
        // MODE B: Add New Character
        else if let template = activeTemplate {
            characterService.addCharacter(
                template: template,
                filmId: film.id,
                nameOverride: characterNameInput.isEmpty ? nil : characterNameInput
            )
            print("Added new character")
        }

        dismiss(animated: true)
    }
}

// MARK: - Data Source
extension CharacterDetailsViewController: UICollectionViewDataSource, UpdateCharacterInfoDelegate {
    
    func updateHeight(value: Float) { }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int { 2 }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 { return 1 }
        return activeTemplate?.pose.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
         // SECTION 0: INFO CELL (Text Field)
         if indexPath.section == 0 {
             guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: infoCellId, for: indexPath) as? CharacterInfoCollectionViewCell else {
                 return UICollectionViewCell()
             }
             
             if let template = activeTemplate {
                 // 1. Configure standard image data
                 cell.configureCell(character: template, delegate: self)
                 
                 // 2. CRITICAL: Manually set the text field to our current edited name.
                 // This ensures the box isn't empty or showing the default template name when editing.
                 cell.nameTextField.text = characterNameInput
             }
             return cell
         }
         
         // SECTION 1: POSES
         guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: posesCellId, for: indexPath) as? CharacterPosesCollectionViewCell else {
             return UICollectionViewCell()
         }
         if let pose = activeTemplate?.pose[indexPath.item] {
             cell.configure(with: pose)
         }
         return cell
     }
     
     func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
         guard let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: "header", withReuseIdentifier: "header_cell", for: indexPath) as? PoseTitleCollectionReusableView else {
             return UICollectionReusableView()
         }
         if indexPath.section == 1 { headerView.configureCell() }
         return headerView
     }
        
    // Delegate called when typing
    func updateName(text: String) {
        characterNameInput = text
        // Optional: Update top title while typing
        // characterTitle.text = text
    }
}
    
// MARK: - Delegate
extension CharacterDetailsViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.section == 1 else { return }
    }
}
