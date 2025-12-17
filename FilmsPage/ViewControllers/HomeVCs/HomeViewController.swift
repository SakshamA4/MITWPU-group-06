//
//  HomeViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 28/11/25.
//
import UIKit

class HomeViewController: UIViewController, UICollectionViewDelegate {

    @IBOutlet weak var collectionView: UICollectionView!
    
    // Local Data Source (Mirrors the Store)
    private var templates: [ScenesModel] = []
    private var recentScenes: [ScenesModel] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        refreshData() // Initial load
    }
    
    // MARK: - Setup
    private func setupCollectionView() {
        // Ensure you register your NIBs/Classes here if not done in Storyboard
        collectionView.register(UINib(nibName: "RecentScenesCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "recentscenes_cell")
        collectionView.register(UINib(nibName: "TemplatesCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "templates_cell")
        collectionView.register(UINib(nibName: "HomeHeaderView", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "home_header_view")
        
        collectionView.collectionViewLayout = createCompositionalLayout()
        collectionView.delegate = self
        collectionView.dataSource = self
    }
    
    private func refreshData() {
        // 1. Fetch latest data from the Single Source of Truth
        templates = ScenesDataStore.shared.currentTemplates
        recentScenes = ScenesDataStore.shared.currentRecentScenes
        
        // 2. Reload UI
        collectionView.reloadData()
    }
    
    func reloadSceneData(){
        print("Reloading Scena")
        refreshData()
    }

    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "goToAddSceneToLibrary" {
            // Handle case where destination is the VC itself OR a Nav Controller wrapping it
            let destination = segue.destination
            
            if let addVC = destination as? AddSceneToLibrarayViewController {
                addVC.delegate = self
            } else if let nav = destination as? UINavigationController,
                      let addVC = nav.viewControllers.first as? AddSceneToLibrarayViewController {
                addVC.delegate = self
            }
        }
    }
}

// MARK: - Delegate Implementation
extension HomeViewController: SceneLibraryDelegate {
    func didAddScene() {
        // The modal has updated the Store. Now we refresh our view.
        refreshData()
    }
}

// MARK: - CollectionView DataSource
extension HomeViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return section == 0 ? templates.count : recentScenes.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if indexPath.section == 0 {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "templates_cell", for: indexPath) as! TemplatesCollectionViewCell
            let item = templates[indexPath.row]
            cell.templateLabel.text = item.name
            cell.templatesImageView.image = UIImage(named: item.image)
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "recentscenes_cell", for: indexPath) as! RecentScenesCollectionViewCell
            let item = recentScenes[indexPath.row]
            cell.recentLabel.text = item.name
            cell.recentImageView.image = UIImage(named: item.image)
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader else { return UICollectionReusableView() }
        
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "home_header_view", for: indexPath) as! HomeHeaderView
        header.titleLabel.text = indexPath.section == 0 ? "Templates" : "Recent Scenes"
        return header
    }
}



extension HomeViewController {
    func createCompositionalLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { sectionIndex, _ in
            
            // 1. Item (The internal cell setup)
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .fractionalHeight(1.0)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .absolute(240),
                heightDimension: .absolute(240)
            )
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: groupSize,
                subitems: [item]
            )
            
            // 3. Section Configuration
            let section = NSCollectionLayoutSection(group: group)
            
            // This enables the Horizontal Scrolling seen in the image
            section.orthogonalScrollingBehavior = .continuous
            
            // The gap between "Outdoor Scene" and "Home"
            section.interGroupSpacing = 24
            

            section.contentInsets = NSDirectionalEdgeInsets(
                top: 10,
                leading: 50,
                bottom: 40,
                trailing: 20
            )
            section.supplementaryContentInsetsReference = .none
            // 4. Header Setup
            // Estimated height allows the header to grow if the font is large (like in your design)
            let headerSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(60)
            )
            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: headerSize,
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top
            )
            
            section.boundarySupplementaryItems = [header]
            
            return section
        }
    }
}
