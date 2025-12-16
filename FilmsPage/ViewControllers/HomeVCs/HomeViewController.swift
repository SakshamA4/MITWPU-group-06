//
//  HomeViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 28/11/25.
//

import UIKit

struct Home {
    var id: Int,
        title: String,
        imageName: String
}

class HomeViewController: UIViewController {

    var template: [Home] = [
        Home(id: 1, title: "Outdoor scene", imageName: "outdoor"),
        Home(id: 2, title: "Home", imageName: "home"),
    ]

    var recentScenes: [Home] = [
        Home(id: 3, title: "Scene 1", imageName: "scene1")
    ]

    @IBOutlet weak var collectionView: UICollectionView!

    override func viewDidLoad() {
        super.viewDidLoad()
        registerCells()

        collectionView.collectionViewLayout = createLayout()
        collectionView.delegate = self
        collectionView.dataSource = self

        // Do any additional setup after loading the view.
    }

    func registerCells() {

        collectionView.register(
            UINib(nibName: "RecentScenesCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "recentscenes_cell"
        )

        collectionView.register(
            UINib(nibName: "TemplatesCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "templates_cell"
        )

        collectionView.register(
            UINib(nibName: "HomeHeaderView", bundle: nil),
            forSupplementaryViewOfKind: UICollectionView
                .elementKindSectionHeader,
            withReuseIdentifier: "home_header_view"
        )
    }
    func createLayout() -> UICollectionViewLayout {

        return UICollectionViewCompositionalLayout {
            sectionIndex,
            environment in

            let itemSize = NSCollectionLayoutSize(
                widthDimension: .absolute(320),
                heightDimension: .absolute(180)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .estimated(320),
                heightDimension: .absolute(180)
            )
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: groupSize,
                subitems: [item]
            )

            let section = NSCollectionLayoutSection(group: group)
            section.orthogonalScrollingBehavior = .continuous
            section.interGroupSpacing = 16
            section.contentInsets = NSDirectionalEdgeInsets(
                top: sectionIndex == 0 ? 10 : 0,
                leading: 20,
                bottom: 20,
                trailing: 20
            )

            let headerSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(44)
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

extension HomeViewController: UICollectionViewDelegate,
    UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout
{

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 2
    }

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        if section == 0 {
            return template.count
        }
        return recentScenes.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {

        if indexPath.section == 0 {
            // Templates section
            let cell =
                collectionView.dequeueReusableCell(
                    withReuseIdentifier: "templates_cell",
                    for: indexPath
                ) as! TemplatesCollectionViewCell

            let item = template[indexPath.row]
            cell.templateLabel.text = item.title
            cell.templatesImageView.image = UIImage(named: item.imageName)
            return cell

        } else {
            // Recent scenes section
            let cell =
                collectionView.dequeueReusableCell(
                    withReuseIdentifier: "recentscenes_cell",
                    for: indexPath
                ) as! RecentScenesCollectionViewCell

            let item = recentScenes[indexPath.row]
            cell.recentLabel.text = item.title
            cell.recentImageView.image = UIImage(named: item.imageName)
            return cell
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {

        guard kind == UICollectionView.elementKindSectionHeader else {
            return UICollectionReusableView()
        }

        let header =
            collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: "home_header_view",
                for: indexPath
            ) as! HomeHeaderView

        if indexPath.section == 0 {
            header.titleLabel.text = "Templates"
        } else {
            header.titleLabel.text = "Recent Scenes"
        }

        return header
    }

}
