//
//  CameraViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 10/12/25.
//

import UIKit

class CameraViewController: UIViewController {

    @IBOutlet weak var cameraCollectionView: UICollectionView!

      private let sections = CameraLibraryDataStore.sections
      private var selectedItem: CameraLibraryItem?


      override func viewDidLoad() {
          super.viewDidLoad()
          registerCells()
          cameraCollectionView.delegate = self
          cameraCollectionView.dataSource = self
          cameraCollectionView.setCollectionViewLayout(createLayout(), animated: false)
      }

      private func registerCells() {
          cameraCollectionView.register(
              UINib(nibName: "CameraCollectionViewCell", bundle: nil),
              forCellWithReuseIdentifier: "CameraCollectionViewCell"
          )
          cameraCollectionView.register(
              UINib(nibName: "CameraMovementsCollectionViewCell", bundle: nil),
              forCellWithReuseIdentifier: "CameraMovementsCollectionViewCell"
          )
          cameraCollectionView.register(
              UINib(nibName: "StaticshotsCollectionViewCell", bundle: nil),
              forCellWithReuseIdentifier: "StaticshotsCollectionViewCell"
          )
          cameraCollectionView.register(
              UINib(nibName: "LibraryHeaderView", bundle: nil),
              forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
              withReuseIdentifier: "LibraryHeaderView"
          )
      }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "CameraInfoSegue",
           let infoVC = segue.destination as? CameraInfoViewController,
           let item = selectedItem {
            infoVC.item = item
        }
    }

    
  }
extension CameraViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sections.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        sections[section].items.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        let sectionType = sections[indexPath.section].type
        let item = sections[indexPath.section].items[indexPath.item]

        switch sectionType {
        case .cameras:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "CameraCollectionViewCell",
                for: indexPath
            ) as! CameraCollectionViewCell
            cell.configure(with: item)
            return cell

        case .movements:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "CameraMovementsCollectionViewCell",
                for: indexPath
            ) as! CameraMovementsCollectionViewCell
            cell.configure(with: item)
            return cell

        case .staticShots:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "StaticshotsCollectionViewCell",
                for: indexPath
            ) as! StaticshotsCollectionViewCell
            cell.configure(with: item)
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {

        guard kind == UICollectionView.elementKindSectionHeader else {
            return UICollectionReusableView()
        }

        guard let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: "LibraryHeaderView",
            for: indexPath
        ) as? LibraryHeaderView else {
            return UICollectionReusableView()
        }

        // ✅ FIXED: use .rawValue here
        let sectionType = sections[indexPath.section].type
        header.configureHeader(text: sectionType.title)

        return header
    }

    
}

extension CameraViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let section = sections[indexPath.section]
        let item = section.items[indexPath.item]

         selectedItem = item                         // remember which one was tapped
                performSegue(withIdentifier: "CameraInfoSegue", sender: self)
    }
}
private func createLayout() -> UICollectionViewCompositionalLayout {

    // Layout constants
    let columns: CGFloat = 4                    // 4 full items
    let visibleItems: CGFloat = 4.2             // 🔹 4 + a bit of the 5th
    let itemSpacing: CGFloat = 36
    let groupHeight: CGFloat = 230
    let sideInset: CGFloat = 75
    let verticalInset: CGFloat = 32

    let layout = UICollectionViewCompositionalLayout { sectionIndex, environment in

        // 🔹 Use the effective width of the collection view
        let containerWidth = environment.container.effectiveContentSize.width
        let contentWidth = containerWidth - (sideInset * 2)

        // 🔹 Spacing between the 4 full items
        let totalSpacing = itemSpacing * (columns - 1)

        // 🔹 Key part: compute itemWidth so that 4 full + 0.2 of 5th fit
        let itemWidth = floor((contentWidth - totalSpacing) / visibleItems)
        let itemHeight = groupHeight

        // ITEM (absolute size now, not fractional)
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .absolute(itemWidth),
            heightDimension: .absolute(itemHeight)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        // GROUP: width is just the usable content width
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .absolute(contentWidth),
            heightDimension: .absolute(groupHeight)
        )

        // 🔹 Use modern API: subitems: [item]
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize,
            subitems: [item]
        )
        group.interItemSpacing = .fixed(itemSpacing)

        // SECTION: horizontally scrollable row
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous   // 🔹 shows 4 + peek of 5th as you scroll
        section.contentInsets = NSDirectionalEdgeInsets(
            top: verticalInset,
            leading: sideInset,
            bottom: verticalInset,
            trailing: sideInset
        )

        // HEADER
        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(44)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .topLeading
        )
        section.boundarySupplementaryItems = [header]

        return section
    }

    return layout
}



