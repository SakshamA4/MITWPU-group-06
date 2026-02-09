//
//  MyFilmViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 26/11/25.
//


import UIKit

class MyFilmViewController: UIViewController {
    
    var film: Film?

    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var filmName: UILabel!
    
    private let sequenceCellId = "sequence_cell"
    private let characterCellId = "character_cell"
    private let propCellId = "prop_cell"
    
    var sequence: [Sequence] = []
    var characters: [FilmCharacter] = []

    private let filmCharacterService = FilmCharacterService.shared

    var prop: [PropItem] = []
    
    // Services
    private let sequenceService = SequenceService.shared
    private let characterService = CharacterService.shared
    private let propService = PropService.shared
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        refreshData()

        let layout = generateLayout()
        collectionView.setCollectionViewLayout(layout, animated: true)

        registerCells()
        setupObservers()

        collectionView.dataSource = self
        collectionView.delegate = self

//        let longPress = UILongPressGestureRecognizer(
//            target: self,
//            action: #selector(handleLongPress(_:))
//        )
//        collectionView.addGestureRecognizer(longPress)

        filmName.text = film?.name ?? "My Film"
    }

//    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
//        guard gesture.state == .began else { return }
//
//        let point = gesture.location(in: collectionView)
//        
//        // In handleLongPress...
//        guard let indexPath = collectionView.indexPathForItem(at: point) else { return }
//
//        // Ignore Placeholder (Index 0)
//        if indexPath.item == 0 { return }
//
//        presentMenu(for: indexPath)
//
//        // Ignore placeholder cells
//        if (indexPath.section == 0 && sequence.isEmpty) ||
//           (indexPath.section == 1 && characters.isEmpty) ||
//           (indexPath.section == 2 && prop.isEmpty) {
//            return
//        }
//
//        presentMenu(for: indexPath)
//    }
//
//    private func presentMenu(for indexPath: IndexPath) {
//
//        let alert = UIAlertController(
//            title: "Options",
//            message: nil,
//            preferredStyle: .actionSheet
//        )
//
//        alert.addAction(UIAlertAction(title: "Edit", style: .default) { _ in
//            self.handleEdit(at: indexPath)
//        })
//
//        alert.addAction(UIAlertAction(title: destructiveTitle(for: indexPath),
//                                      style: .destructive) { _ in
//            self.handleDeleteOrRemove(at: indexPath)
//        })
//
//        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
//
//        present(alert, animated: true)
//    }
//
//    private func destructiveTitle(for indexPath: IndexPath) -> String {
//        if indexPath.section == 0 {
//            return "Delete Sequence"
//        } else {
//            return "Remove from Film"
//        }
//    }
//
//    private func handleEdit(at indexPath: IndexPath) {
//        let dataIndex = indexPath.item - 1 // Shift index
//        
//        if indexPath.section == 0 {
//            performSegue(withIdentifier: "sequenceSegue", sender: sequence[dataIndex])
//        } else if indexPath.section == 1 {
//            performSegue(withIdentifier: "characterInfoSegue", sender: characters[dataIndex])
//        } else {
//            performSegue(withIdentifier: "propSegue", sender: prop[dataIndex])
//        }
//    }
//    private func handleDeleteOrRemove(at indexPath: IndexPath) {
//        guard let film = film else { return }
//        
//        // Shift index to find real data
//        let dataIndex = indexPath.item - 1
//
//        if indexPath.section == 0 {
//            let seq = sequence[dataIndex]
//            sequenceService.deleteSequence(by: seq.id)
//        } else if indexPath.section == 1 {
//            let char = characters[dataIndex]
//            filmCharacterService.removeCharacter(by: char.id)
//        } else {
//            let pr = prop[dataIndex]
//            guard let propId = pr.id else { return }
//            propService.removeProp(propId, fromFilmId: film.id)
//        }
//    }

    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshData),
            name: NSNotification.Name(NotificationNames.sequencesUpdated),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshData),
            name: NSNotification.Name(NotificationNames.filmCharactersUpdated),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshData),
            name: NSNotification.Name(NotificationNames.propsUpdated),
            object: nil
        )
    }
    
    @objc private func refreshData() {
        guard let film = film else { return }
        sequence = sequenceService.getSequences(forFilmId: film.id)
        characters = filmCharacterService.getCharacters(forFilmId: film.id)
        prop = propService.getProps(forFilmId: film.id)
        collectionView?.reloadData()
    }
    
    func registerCells() {
        collectionView.register(UINib(nibName: "SequencesCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "sequence_cell")
        collectionView.register(UINib(nibName: "CharactersCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "character_cell")
        collectionView.register(UINib(nibName: "PropsCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "prop_cell")
        collectionView.register(UINib(nibName: "HeaderView",bundle: nil),forSupplementaryViewOfKind: "header",withReuseIdentifier: "header_cell")
        collectionView.register(UINib(nibName: "PlaceholderCollectionViewCell",bundle: nil), forCellWithReuseIdentifier: "placeholder_cell")
    }
    

    func generateLayout()-> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout {
            section, env in
            
             let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(50))
             let headerItem = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: "header", alignment: .top)
            
            if section == 0 {
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.25), heightDimension: .fractionalHeight(1.0))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.9), heightDimension: .estimated(235))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                
                group.interItemSpacing = .fixed(10)
                let section = NSCollectionLayoutSection(group: group)
                section.orthogonalScrollingBehavior = .groupPagingCentered
                
                item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
                section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 12, bottom: 32, trailing: 12)
                section.boundarySupplementaryItems = [headerItem]
                
                return section
            }
            else if section == 1 {
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.25), heightDimension: .fractionalHeight(1.0))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)

                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.90), heightDimension: .estimated(235))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                
                let section = NSCollectionLayoutSection(group: group)
                section.orthogonalScrollingBehavior = .groupPagingCentered
                group.interItemSpacing = .fixed(10)
                section.interGroupSpacing = 50
                section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 12, bottom: 32, trailing: 12)
                section.boundarySupplementaryItems = [headerItem]
                
                return section
            }
            else {
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.25), heightDimension: .fractionalHeight(1.0))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)

                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.90), heightDimension: .estimated(235))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                
                let section = NSCollectionLayoutSection(group: group)
                section.orthogonalScrollingBehavior = .groupPagingCentered
                group.interItemSpacing = .fixed(10)
                section.interGroupSpacing = 50
                section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 12, bottom: 32, trailing: 12)
                section.boundarySupplementaryItems = [headerItem]
                
                return section
            }
        }
        return layout
    }
}


extension MyFilmViewController: UICollectionViewDataSource, UICollectionViewDelegate {



    // Helper — generic dequeue
    private func dequeue<T: UICollectionViewCell>(_ id: String, as: T.Type, _ cv: UICollectionView, _ index: IndexPath) -> T {
        return cv.dequeueReusableCell(withReuseIdentifier: id, for: index) as! T
    }

    // Helper — placeholder cell
    private func placeholder(_ cv: UICollectionView, _ index: IndexPath) -> PlaceholderCollectionViewCell {
        return dequeue("placeholder_cell", as: PlaceholderCollectionViewCell.self, cv, index)
    }

    
    func numberOfSections(in collectionView: UICollectionView) -> Int { 3 }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 { return sequence.count + 1 }
        if section == 1 { return characters.count + 1 }
        return prop.count + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        // Helper to setup placeholder
        func configurePlaceholder(segueIdentifier: String) -> UICollectionViewCell {
            let cell = placeholder(collectionView, indexPath)
            cell.onPlusButtonTapped = { [weak self] in
                self?.performSegue(withIdentifier: segueIdentifier, sender: nil)
            }
            return cell
        }

        switch indexPath.section {
        case 0: // Sequences
            if indexPath.item == 0 { return configurePlaceholder(segueIdentifier: "AddNewSequenceSegue") }
            
            let cell = dequeue(sequenceCellId, as: SequencesCollectionViewCell.self, collectionView, indexPath)
            // SHIFT: Access data at [item - 1]
            cell.configureCell(sequence: sequence[indexPath.item - 1])
            return cell

        case 1: // Characters
            if indexPath.item == 0 { return configurePlaceholder(segueIdentifier: "AddNewCharacterSegue") }
            
            let cell = dequeue(characterCellId, as: CharactersCollectionViewCell.self, collectionView, indexPath)
            // SHIFT: Access data at [item - 1]
            let filmCharacter = characters[indexPath.item - 1]
            let template = characterService.getCharacter(by: filmCharacter.characterTemplateId)
            cell.configureCell(filmCharacter: filmCharacter, template: template)
            return cell

        default: // Props
            if indexPath.item == 0 { return configurePlaceholder(segueIdentifier: "AddNewPropSegue") }
            
            let cell = dequeue(propCellId, as: PropsCollectionViewCell.self, collectionView, indexPath)
            // SHIFT: Access data at [item - 1]
            cell.configureCell(prop: prop[indexPath.item - 1])
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {

        let headerView = collectionView.dequeueReusableSupplementaryView(
            ofKind: "header",
            withReuseIdentifier: "header_cell",
            for: indexPath) as! HeaderView

        if indexPath.section == 0 {
            headerView.configureHeader(text: "Sequences", section: 0)
        } else if indexPath.section == 1 {
            headerView.configureHeader(text: "Characters", section: 1)
        } else {
            headerView.configureHeader(text: "Props", section: 2)
        }

        headerView.delegate = self
        return headerView
    }

    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if indexPath.section == 0 && sequence.isEmpty { return false }
        if indexPath.section == 1 && characters.isEmpty { return false }
        if indexPath.section == 2 && prop.isEmpty { return false }
        return true
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Ignore the placeholder (Index 0)
        if indexPath.item == 0 { return }

        // Shift index back by 1 to get the actual data
        let dataIndex = indexPath.item - 1

        if indexPath.section == 0 {
            performSegue(withIdentifier: "sequenceSegue", sender: sequence[dataIndex])
        } else if indexPath.section == 1 {
            performSegue(withIdentifier: "characterInfoSegue", sender: characters[dataIndex])
        } else {
            performSegue(withIdentifier: "propSegue", sender: prop[dataIndex])
        }
    }

    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
            
            // --- Existing Edit Segues ---
            if segue.identifier == "sequenceSegue" {
                let vc = segue.destination as! SequenceViewController
                vc.sequence = sender as? Sequence
                vc.filmName = self.film?.name
            }
        if segue.identifier == "characterInfoSegue" {
                    let vc = segue.destination as! CharacterDetailsViewController
                    // Sender is FilmCharacter (from didSelectItemAt), NOT CharacterItem
                    vc.filmCharacter = sender as? FilmCharacter
                }
        if segue.identifier == "propSegue" {
                let vc = segue.destination as! PropDetailViewController
                vc.prop = sender as? PropItem
            }
            
            // --- NEW ADD SEGUES (You must pass the Film!) ---
            
        if segue.identifier == "AddNewSequenceSegue" {
                // Cast to AddSequenceViewController specifically
                if let vc = segue.destination as? AddSequenceViewController {
                    vc.film = self.film
                }
            }
            
            if segue.identifier == "AddNewCharacterSegue" {
                // Cast to AddCharacterViewController specifically
                if let vc = segue.destination as? AddCharacterViewController {
                    vc.film = self.film
                }
            }
            
            if segue.identifier == "AddNewPropSegue" {
                // Cast to AddPropViewController specifically
                if let vc = segue.destination as? AddPropViewController {
                    vc.film = self.film
                }
            }
            // Keep existing "View All" logic...
            if segue.identifier == "allSequencesSegue" {
                let vc = segue.destination as! AllSequencesViewController
                vc.sequence = sender as! [Sequence]
            }
            if segue.identifier == "allCharactersSegue" {
                let vc = segue.destination as! AllCharactersViewController
                vc.characters = sender as! [FilmCharacter]
                vc.film = film
            }
            if segue.identifier == "allPropsSegue" {
                let vc = segue.destination as! AllPropsViewController
                vc.prop = sender as! [PropItem]
                vc.film = self.film
            }
        }
}


extension MyFilmViewController: HeaderViewDelegate {
    func didTapHeader(section: Int) {
        if section == 0 {
            performSegue(withIdentifier: "allSequencesSegue", sender: sequence)
        } else if section == 1 {
            performSegue(withIdentifier: "allCharactersSegue", sender: characters)
        } else if section == 2 {
            performSegue(withIdentifier: "allPropsSegue", sender: prop)
        }
    }
}


extension MyFilmViewController {

    // MARK: - Context Menu (Native Long Press)
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        
        // 1. Ignore Placeholder Cells (Index 0)
        if indexPath.item == 0 { return nil }
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggestedActions in
            
            var actions: [UIAction] = []
            
            // SECTION 0: SEQUENCES (Allow Rename & Delete)
            if indexPath.section == 0 {
                let renameAction = UIAction(title: "Rename Sequence", image: UIImage(systemName: "pencil")) { [weak self] _ in
                    self?.presentRenameSequenceAlert(at: indexPath)
                }
                actions.append(renameAction)
            }
            // SECTIONS 1 & 2: CHARACTERS & PROPS (Allow Edit Details)
            else {
                let editAction = UIAction(title: "Edit Details", image: UIImage(systemName: "pencil")) { [weak self] _ in
                    // For characters/props, we stick to the Segue since they are complex
                    self?.performEditSegue(at: indexPath)
                }
                actions.append(editAction)
            }
            
            // ALL SECTIONS: DELETE ACTION
            let deleteAction = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.deleteItem(at: indexPath)
            }
            actions.append(deleteAction)
            
            return UIMenu(title: "", children: actions)
        }
    }

    // MARK: - Helper Functions

    /// Handles Deletion (Service Only - No Manual UI Update)
    private func deleteItem(at indexPath: IndexPath) {
        guard let film = film else { return }
        let dataIndex = indexPath.item - 1 // Shift index because of placeholder
        
        if indexPath.section == 0 {
            // Sequence
            let seq = sequence[dataIndex]
            sequenceService.deleteSequence(by: seq.id)
            // Note: Ensure SequenceService posts 'NotificationNames.sequencesUpdated'
            
        } else if indexPath.section == 1 {
            // Character
            let char = characters[dataIndex]
            filmCharacterService.removeCharacter(by: char.id)
            // Note: Ensure FilmCharacterService posts 'NotificationNames.filmCharactersUpdated'
            
        } else {
            // Prop
            let pr = prop[dataIndex]
            guard let propId = pr.id else { return }
            propService.removeProp(propId, fromFilmId: film.id)
            // Note: Ensure PropService posts 'NotificationNames.propsUpdated'
        }
        
        // CRITICAL: We do NOT manually delete from array or collectionView.
        // We let the Observers in viewDidLoad call refreshData().
    }

    /// Handles Renaming for Sequences
    private func presentRenameSequenceAlert(at indexPath: IndexPath) {
        let dataIndex = indexPath.item - 1
        let currentSequence = sequence[dataIndex]
        
        let alert = UIAlertController(title: "Rename Sequence", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text = currentSequence.name
            tf.placeholder = "Sequence Name"
        }
        
        let saveAction = UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self = self,
                  let newName = alert.textFields?.first?.text,
                  !newName.isEmpty else { return }
            
            // 1. Create mutable copy
            var updatedSequence = currentSequence
            updatedSequence.name = newName
            
            // 2. Update via Service
            // Assuming you have an update method. If not, you need to add it to SequenceService.
             self.sequenceService.updateSequence(updatedSequence)
            
            // 3. Optional: If your service doesn't post a notification for updates,
            // you might need to manually reload:
            // self.refreshData()
        }
        
        alert.addAction(saveAction)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    /// Handles Navigation for Characters/Props
    private func performEditSegue(at indexPath: IndexPath) {
        let dataIndex = indexPath.item - 1
        
        if indexPath.section == 1 {
            performSegue(withIdentifier: "characterInfoSegue", sender: characters[dataIndex])
        } else if indexPath.section == 2 {
            performSegue(withIdentifier: "propSegue", sender: prop[dataIndex])
        }
    }
}
