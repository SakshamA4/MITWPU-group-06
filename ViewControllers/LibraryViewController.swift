//
//  LibraryViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 27/11/25.
//

import UIKit

class LibraryViewController: UIViewController, UICollectionViewDelegate {
    
    
    @IBOutlet weak var libraryCollectionView: UICollectionView!
    
    private let libraryData = LibraryModel.sections
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
                registerCell()
        libraryCollectionView.delegate = self
                libraryCollectionView.dataSource = self
                libraryCollectionView.setCollectionViewLayout(generateLayout(), animated: false)
            }

        // Do any additional setup after loading the view.
    
    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        
        let sectionType = LibrarySection.allCases[indexPath.section]
        guard let items = LibraryModel.sections[sectionType] else { return }
        let item = items[indexPath.row]
        
        let storyboard = UIStoryboard(name: "Library", bundle: nil)  // or "Main" if that's where it is

            switch item.destinationKey {

            case "background":
                guard let backgroundVC = storyboard.instantiateViewController(
                    withIdentifier: "BackgroundViewController"
                ) as? BackgroundViewController else { return }

                navigationController?.pushViewController(backgroundVC, animated: true)

            case "scenes":
                guard let scenesVC = storyboard.instantiateViewController(
                    withIdentifier: "SceneViewController"
                ) as? SceneViewController else { return }

                navigationController?.pushViewController(scenesVC, animated: true)

            case "camerasAndMovements":
                
                guard let cameraVC = storyboard.instantiateViewController(
                    withIdentifier: "CameraViewController"   // storyboard ID
                ) as? CameraViewController else { return }

                navigationController?.pushViewController(cameraVC, animated: true)
                
            case "props":
                
                guard let propsVC = storyboard.instantiateViewController(
                        withIdentifier: "LibraryPropsViewController"
                    ) as? LibraryPropsViewController else { return }
                    navigationController?.pushViewController(propsVC, animated: true)
                    
            case "lights":
                    guard let lightsVC = storyboard.instantiateViewController(
                        withIdentifier: "LightsViewController"
                    ) as? LightsViewController else { return }
                    navigationController?.pushViewController(lightsVC, animated: true)
                    
            case "characters":
                    guard let charactersVC = storyboard.instantiateViewController(
                        withIdentifier: "LibraryCharactersViewController"
                    ) as? LibraryCharactersViewController else { return }
                    navigationController?.pushViewController(charactersVC, animated: true)

            default:
                break
            }
        }
    
    func generateLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, environment in
            
            // Common item configuration
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .fractionalHeight(1.0)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 14, bottom: 0, trailing: 14)

            // MARK: Section 0 — Featured (Scenes + Cameras)
            if sectionIndex == 0 {
                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(0.5),
                    heightDimension: .absolute(220) // big cards
                )
                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: groupSize,
                    repeatingSubitem: item,
                    count: 2
                )
                
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 73, bottom: 0, trailing: 73)
//                section.interGroupSpacing = 25
                section.orthogonalScrollingBehavior = .none  // no horizontal scrolling
                return section
            }

            // MARK: Section 1 — Assets (4 small cards)
            else {
                let groupSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(0.25),
                    heightDimension: .absolute(241.5)
                )
                let group = NSCollectionLayoutGroup.horizontal(
                    layoutSize: groupSize,
                    repeatingSubitem: item,
                    count: 4
                )
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 36, leading: 73, bottom: 10, trailing: 73)
                section.interGroupSpacing = 28
                section.orthogonalScrollingBehavior = .none // no horizontal scrolling
                return section
            }
        }

        // Disable vertical scrolling on the whole collection view by constraining its height later
        return layout
    }
    
    private func registerCell() {
        libraryCollectionView.register(
            UINib(nibName: "ScenesAndCameraCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "featured_cell"
        )
        
        libraryCollectionView.register(
            UINib(nibName: "CharactersPropsLightsBackgroundCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "assets_cell"
        )
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

extension LibraryViewController: UICollectionViewDataSource {

        func numberOfSections(in collectionView: UICollectionView) -> Int {
            return LibrarySection.allCases.count
        }

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            let sectionType = LibrarySection.allCases[section]
            return LibraryModel.sections[sectionType]?.count ?? 0
            }

        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

            let sectionType = LibrarySection.allCases[indexPath.section]
            guard let items = LibraryModel.sections[sectionType] else {
                fatalError("No items found for section \(sectionType)")
            }
            let item = items[indexPath.row]

           switch sectionType {
           case . featured:
               let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "featured_cell", for: indexPath) as! ScenesAndCameraCollectionViewCell
               cell.configure(with: item)
               return cell

           case .assets:
                   let cell = collectionView.dequeueReusableCell(
                       withReuseIdentifier: "assets_cell",
                       for: indexPath
                   ) as! CharactersPropsLightsBackgroundCollectionViewCell
                   cell.configure(with: item)
                   return cell
               }
            }
        }
        
