//
//  MyFilmViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 26/11/25.
//

import UIKit

class MyFilmViewController: UIViewController {

    @IBOutlet weak var collectionView: UICollectionView!
    
    private let sequenceCellId = "sequence_cell"
    private let characterCellId = "character_cell"
    private let propCellId = "prop_cell"
    
    var sequence: [Sequence] = []
    var character: [Character] = []
    var prop: [Prop] = []
    let dataStore = DataStore(Sequence: [], Props: [], Characters: [])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        dataStore.loadData()
        
        sequence = dataStore.getSequence()
        character = dataStore.getCharacters()
        prop = dataStore.getProps()
        
        let layout = generateLayout()
        collectionView.setCollectionViewLayout(layout, animated: true)
        
        registerCells()
        
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.collectionViewLayout = generateLayout()

        collectionView.reloadData()
        // Do any additional setup after loading the view.
    }
    
    func registerCells() {
        
        collectionView.register(UINib(nibName: "SequencesCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "sequence_cell")
        
        collectionView.register(UINib(nibName: "CharactersCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "character_cell")
        
        collectionView.register(UINib(nibName: "PropsCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "prop_cell")
        
        //collectionView.register(UINib(nibName: "HeaderView",bundle: nil),forSupplementaryViewOfKind: "header",withReuseIdentifier: "header_cell")
        
    }
    

    func generateLayout()-> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout {
            section, env in
            
//            let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(50))
//            let headerItem = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: "header", alignment: .top)
            
            if section == 0 {
                //set item size
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalHeight(1.0))
                //create item
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                
                //create the group
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.90), heightDimension: .estimated(235))
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                
                group.interItemSpacing = .fixed(10)
                //create the section
                let section = NSCollectionLayoutSection(group: group)
                //scrolling
                section.orthogonalScrollingBehavior = .groupPagingCentered
                
                
                item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
                //spacing between next block
                //section.interGroupSpacing = 10
                section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 12, bottom: 48, trailing: 12)
                //section.boundarySupplementaryItems = [headerItem]
                
                return section
            }
            else if section == 1 {
                //set item size
                let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(221), heightDimension: .absolute(261))
                //create item
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                
                item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)
                
                //create the group
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.9), heightDimension: .estimated(261))
                
                //                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: groupSize,
                    repeatingSubitem: item,
                    count: 4
                )
                
                //create the section
                let section = NSCollectionLayoutSection(group: group)
                section.orthogonalScrollingBehavior = .groupPagingCentered
                
                group.interItemSpacing = .fixed(20)
                //spacing between next block
                section.interGroupSpacing = 50
                section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 12, bottom: 16, trailing: 12)
                
                //add header
                
                
                return section
            }
            
            else {
                let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(221), heightDimension: .absolute(261))
                //create item
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                
                item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10)
                
                //create the group
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.9), heightDimension: .estimated(261))
                
                //                let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: groupSize,
                    repeatingSubitem: item,
                    count: 4
                )
                
                //create the section
                let section = NSCollectionLayoutSection(group: group)
                section.orthogonalScrollingBehavior = .groupPagingCentered
                
                group.interItemSpacing = .fixed(20)
                //spacing between next block
                section.interGroupSpacing = 50
                section.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 12, bottom: 16, trailing: 12)
                
                return section
                
            }
            
        }
            
            return layout
       
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

extension MyFilmViewController: UICollectionViewDataSource, UICollectionViewDelegate{
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        3
    }
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if section == 0 {
            return sequence.count
        } else if section == 1 {
            return character.count
        } else {
            return prop.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: sequenceCellId , for: indexPath) as? SequencesCollectionViewCell else {
                return UICollectionViewCell()
            }
            let sequence = sequence[indexPath.item]
            cell.configureCell(sequences: sequence)
            return cell

        } else if indexPath.section == 1  {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: characterCellId, for: indexPath) as? CharactersCollectionViewCell else {
                return UICollectionViewCell()
            }
            let character = character[indexPath.item]
            cell.configureCell(character: character)
            return cell
        } else {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: propCellId, for: indexPath) as? PropsCollectionViewCell else {
                return UICollectionViewCell()
            }
            let prop = prop[indexPath.item]
            cell.configureCell(prop: prop)
            return cell
        }
        
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        //create headerView
        let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: "header", withReuseIdentifier: "header_cell", for: indexPath) as! HeaderView
        //headerView.backgroundColor = .blue
        
        if indexPath.section == 0 {
            headerView.configureHeader(text: "My Film")
        }
        
        return headerView
    }
    
    
}
