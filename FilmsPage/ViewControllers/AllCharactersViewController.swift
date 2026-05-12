////
////  CharactersViewController.swift
////  FilmsPage
////
////  Created by SDC-USER on 08/12/25.
////
//
//import UIKit
//
//class AllCharactersViewController: UIViewController , UICollectionViewDataSource {
//
//    var characters: [FilmCharacter] = []
//    var film: Film!
//    
//    
//    @IBOutlet weak var collectionView: UICollectionView!
//    
//    private let characterCellId = "character_cell"
//
//    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//
//
//        
//        collectionView.register(UINib(nibName: "CharactersCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "character_cell")
//        
//
//        collectionView.dataSource = self
//        let layout = UICollectionViewFlowLayout()
//        layout.scrollDirection = .vertical
//        layout.minimumLineSpacing = 8
//        layout.minimumInteritemSpacing = 8
//        collectionView.setCollectionViewLayout(layout, animated: false)
//        collectionView.dataSource = self
//        collectionView.delegate = self
//        // Do any additional setup after loading the view.
//        loadCharacters()
//    }
//    
//    override func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(animated)
//
//        NotificationCenter.default.addObserver(
//            self,
//            selector: #selector(refreshData),
//            name: NSNotification.Name(FilmCharacterService.NotificationNames.filmCharactersUpdated),
//            object: nil
//        )
//    }
//
//    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
//        super.viewWillTransition(to: size, with: coordinator)
//        coordinator.animate(alongsideTransition: { _ in
//            self.collectionView?.collectionViewLayout.invalidateLayout()
//        })
//    }
//
//
//    @objc private func refreshData() {
//        loadCharacters()
//    }
//
//    
//    
//    private func loadCharacters() {
//        characters = FilmCharacterService.shared.getCharacters(forFilmId: film.id)
//        collectionView.reloadData()
//    }
//
//    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
//        return characters.count
//    }
//    
//     func collectionView(_ collectionView: UICollectionView,
//                            cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
//
//            guard let cell = collectionView.dequeueReusableCell(
//                withReuseIdentifier: characterCellId,
//                for: indexPath
//            ) as? CharactersCollectionViewCell else {
//                return UICollectionViewCell()
//            }
//
//            let filmCharacter = characters[indexPath.item]
//
//            // Resolve template from service
//            let template = FilmCharacterService.shared.getTemplate(for: filmCharacter)
//
//            cell.configureCell(
//                filmCharacter: filmCharacter,
//                template: template
//            )
//
//            return cell
//        }
//    /*
//    // MARK: - Navigation
//
//    // In a storyboard-based application, you will often want to do a little preparation before navigation
//    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
//        // Get the new view controller using segue.destination.
//        // Pass the selected object to the new view controller.
//    }
//    */
//
//}
//
//extension AllCharactersViewController: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
//    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
//        let inset: CGFloat = 40
//        let interItem: CGFloat = 40
//        let columns: CGFloat = 4
//        let totalSpacing = inset * 2 + interItem * (columns - 1)
//        let width = (collectionView.bounds.width - totalSpacing) / columns
//        return CGSize(width: width, height: width)
//    }
//
//    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
//        return UIEdgeInsets(top: 16, left: 52, bottom: 16, right: 52)
//    }
//}
//
//
//// Add this extension to AllCharactersViewController.swift
//
//extension AllCharactersViewController {
//    
//    // MARK: - Context Menu
//    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
//        
//        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { suggestedActions in
//            
//            let char = self.characters[indexPath.item]
//            
//            // 1. Edit Details (Standard navigation)
//            let editAction = UIAction(title: "Edit Details", image: UIImage(systemName: "pencil")) { [weak self] _ in
//                // Assuming you have a segue identifier for this, or use the didSelect logic
//                 self?.performSegue(withIdentifier: "characterInfoSegue", sender: char)
//            }
//            
//            // 2. Delete Action
//            let deleteAction = UIAction(title: "Remove from Film", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
//                self?.deleteCharacter(char)
//            }
//            
//            return UIMenu(title: "Options", children: [editAction, deleteAction])
//        }
//    }
//    
//    private func deleteCharacter(_ char: FilmCharacter) {
//        // Remove from film via Service
//        FilmCharacterService.shared.removeCharacter(by: char.id)
//        
//        // The existing observer in viewWillAppear will catch this and call loadCharacters()
//    }
//}
//
//
