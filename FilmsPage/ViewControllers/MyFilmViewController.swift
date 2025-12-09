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
    
    private let sequenceCellId = "sequence_cell"
    private let characterCellId = "character_cell"
    private let propCellId = "prop_cell"
    
    var sequence: [Sequence] = []
    var character: [Character] = []
    var prop: [Prop] = []
    var dataStore: DataStore?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sequence = dataStore!.getSequenceByFilmID(filmId: film!.id )
        character = dataStore!.getCharacters(filmId: film!.id)
        prop = dataStore!.getProps(filmId: film!.id)
        
        let layout = generateLayout()
        collectionView.setCollectionViewLayout(layout, animated: true)
        
        registerCells()
        
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.collectionViewLayout = generateLayout()

        collectionView.reloadData()
        
        navigationItem.title = film?.name ?? "My Film"
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
                section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 12, bottom: 16, trailing: 12)
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
                section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 12, bottom: 16, trailing: 12)
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
                section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 12, bottom: 16, trailing: 12)
                section.boundarySupplementaryItems = [headerItem]
                
                return section
            }
        }
        return layout
    }
}


extension MyFilmViewController: UICollectionViewDataSource, UICollectionViewDelegate, AddSequenceDelegate {
    func addSequence(sequence: Sequence) {
        
        dataStore?.createNewSequence(newSequence: sequence)
        collectionView.reloadData()
        
    }
    

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
        if section == 1 { return character.isEmpty ? 1 : character.count }
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
            if character.isEmpty { return placeholder(collectionView, indexPath) }
            let cell = dequeue(characterCellId, as: CharactersCollectionViewCell.self, collectionView, indexPath)
            cell.configureCell(character: character[indexPath.item])
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
        if indexPath.section == 1 && character.isEmpty { return false }
        if indexPath.section == 2 && prop.isEmpty { return false }
        return true
    }

    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {

        if indexPath.section == 0 {
            performSegue(withIdentifier: "sequenceSegue", sender: sequence[indexPath.item])
        } else if indexPath.section == 1 {
            performSegue(withIdentifier: "characterSegue", sender: character[indexPath.item])
        } else {
            performSegue(withIdentifier: "propSegue", sender: prop[indexPath.item])
        }
    }

    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "sequenceSegue" {
            let vc = segue.destination as! SequenceViewController
            vc.sequence = sender as? Sequence
            vc.dataStore = dataStore
        }

        if segue.identifier == "characterSegue" {
            let vc = segue.destination as! CharacterViewController
            vc.character = sender as? Character
            vc.dataStore = dataStore
        }

        if segue.identifier == "propSegue" {
            let vc = segue.destination as! PropViewController
            vc.prop = sender as? Prop
            vc.dataStore = dataStore
        }

        if segue.identifier == "allSequencesSegue" {
            let vc = segue.destination as! AllSequencesViewController
            vc.dataStore = dataStore
            vc.sequence = sender as! [Sequence]
        }

        if segue.identifier == "allCharactersSegue" {
            let vc = segue.destination as! AllCharactersViewController
            vc.dataStore = dataStore
            vc.character = sender as! [Character]
        }

        if segue.identifier == "allPropsSegue" {
            let vc = segue.destination as! AllPropsViewController
            vc.dataStore = dataStore
            vc.prop = sender as! [Prop]
        }
    }
}


// ---------------------------------------------------------
// MARK: - HEADER TAP HANDLER
// ---------------------------------------------------------

extension MyFilmViewController: HeaderViewDelegate {
    func didTapHeader(section: Int) {
        if section == 0 {
            performSegue(withIdentifier: "allSequencesSegue", sender: sequence)
        } else if section == 1 {
            performSegue(withIdentifier: "allCharactersSegue", sender: character)
        } else if section == 2 {
            performSegue(withIdentifier: "allPropsSegue", sender: prop)
        }
    }
}

