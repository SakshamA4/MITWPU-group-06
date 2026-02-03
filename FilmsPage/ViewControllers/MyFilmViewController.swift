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

        let longPress = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleLongPress(_:))
        )
        collectionView.addGestureRecognizer(longPress)

        filmName.text = film?.name ?? "My Film"
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }

        let point = gesture.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: point) else { return }

        // Ignore placeholder cells
        if (indexPath.section == 0 && sequence.isEmpty) ||
           (indexPath.section == 1 && characters.isEmpty) ||
           (indexPath.section == 2 && prop.isEmpty) {
            return
        }

        presentMenu(for: indexPath)
    }

    private func presentMenu(for indexPath: IndexPath) {

        let alert = UIAlertController(
            title: "Options",
            message: nil,
            preferredStyle: .actionSheet
        )

        alert.addAction(UIAlertAction(title: "Edit", style: .default) { _ in
            self.handleEdit(at: indexPath)
        })

        alert.addAction(UIAlertAction(title: destructiveTitle(for: indexPath),
                                      style: .destructive) { _ in
            self.handleDeleteOrRemove(at: indexPath)
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        present(alert, animated: true)
    }

    private func destructiveTitle(for indexPath: IndexPath) -> String {
        if indexPath.section == 0 {
            return "Delete Sequence"
        } else {
            return "Remove from Film"
        }
    }

    private func handleEdit(at indexPath: IndexPath) {
        if indexPath.section == 0 {
            performSegue(withIdentifier: "sequenceSegue", sender: sequence[indexPath.item])
        } else if indexPath.section == 1 {
            performSegue(withIdentifier: "characterInfoSegue", sender: characters[indexPath.item])
        } else {
            performSegue(withIdentifier: "propSegue", sender: prop[indexPath.item])
        }
    }

    private func handleDeleteOrRemove(at indexPath: IndexPath) {
        guard let film = film else { return }

        if indexPath.section == 0 {
            // 🔥 DELETE SEQUENCE COMPLETELY
            let seq = sequence[indexPath.item]
            sequenceService.deleteSequence(by: seq.id)

        } else if indexPath.section == 1 {
            // 🔗 REMOVE CHARACTER FROM FILM ONLY
            let char = characters[indexPath.item]
            filmCharacterService.removeCharacter(by: char.id)

        } else {
            // 🔗 REMOVE PROP FROM FILM ONLY
            let pr = prop[indexPath.item]
            guard let propId = pr.id else { return }
            propService.removeProp(propId, fromFilmId: film.id)
        }
    }

    
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
    
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        if section == 0 { return sequence.isEmpty ? 1 : sequence.count }
        if section == 1 { return characters.isEmpty ? 1 : characters.count }
        return prop.isEmpty ? 1 : prop.count
    }

    
    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        switch indexPath.section {

        case 0:
            if sequence.isEmpty { return placeholder(collectionView, indexPath) }
            let cell = dequeue(sequenceCellId, as: SequencesCollectionViewCell.self, collectionView, indexPath)
            cell.configureCell(sequence: sequence[indexPath.item])
            
            return cell

        case 1:
            if characters.isEmpty { return placeholder(collectionView, indexPath) }
            let cell = dequeue(characterCellId, as: CharactersCollectionViewCell.self, collectionView, indexPath)
            let filmCharacter = characters[indexPath.item]
            let template = characterService.getCharacter(by: filmCharacter.characterTemplateId)

            cell.configureCell(
                filmCharacter: filmCharacter,
                template: template
            )

            return cell

        default:
            if prop.isEmpty { return placeholder(collectionView, indexPath) }
            let cell = dequeue(propCellId, as: PropsCollectionViewCell.self, collectionView, indexPath)
            cell.configureCell(prop: prop[indexPath.item])
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

    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {

        if indexPath.section == 0 {
            performSegue(withIdentifier: "sequenceSegue", sender: sequence[indexPath.item])
        } else if indexPath.section == 1 {
            performSegue(withIdentifier: "characterInfoSegue", sender: characters[indexPath.item])
        } else {
            performSegue(withIdentifier: "propSegue", sender: prop[indexPath.item])
        }
    }

    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "sequenceSegue" {
            let vc = segue.destination as! SequenceViewController
            vc.sequence = sender as? Sequence
            vc.filmName = self.film?.name  //NEW
        }

        if segue.identifier == "characterInfoSegue" {
            let vc = segue.destination as! CharacterDetailsViewController
            vc.character = sender as? CharacterItem
        }

        if segue.identifier == "propSegue" {
            let vc = segue.destination as! PropDetailViewController
            vc.prop = sender as? PropItem
        }

        if segue.identifier == "addButtonSegue" {
            let vc = segue.destination as! AddViewController
            vc.film = film
        }
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



