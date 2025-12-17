//
//  LightsViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 11/12/25.
//

import UIKit

class LightsViewController: UIViewController {

    @IBOutlet weak var lightsCollectionView: UICollectionView!

        private var lights = LightsDataStore.items   // [LightItem]
    private var selectedLight: LightItem?

        override func viewDidLoad() {
            super.viewDidLoad()
            lightsCollectionView.dataSource = self
            lightsCollectionView.delegate = self
            lightsCollectionView.backgroundColor = .clear

            lightsCollectionView.register(
                UINib(nibName: "LightsCollectionViewCell", bundle: nil),
                forCellWithReuseIdentifier: "LightsCollectionViewCell"
            )
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            configureLayout()
        }

    private func configureLayout() {
        guard let layout = lightsCollectionView.collectionViewLayout as? UICollectionViewFlowLayout else {
            let newLayout = UICollectionViewFlowLayout()
            lightsCollectionView.setCollectionViewLayout(newLayout, animated: false)
            configureLayout()
            return
        }

        // 🔴 IMPORTANT: disable self-sizing
        layout.estimatedItemSize = .zero

        let columns: CGFloat = 4
        let spacing: CGFloat = 35
        let sideInset: CGFloat = 75
//        let verticalInset: CGFloat = 0

        let width = lightsCollectionView.bounds.width
        guard width > 0 else { return }

        let totalSpacing = spacing * (columns - 1) + sideInset * 2
        let itemWidth = floor((width - totalSpacing) / columns)
        let itemHeight = itemWidth

        layout.itemSize = CGSize(width: itemWidth, height: itemHeight)
        layout.minimumInteritemSpacing = spacing
        layout.minimumLineSpacing = spacing
        layout.sectionInset = UIEdgeInsets(top: 0,
                                           left: sideInset,
                                           bottom: 0,
                                           right: sideInset)
        layout.scrollDirection = .vertical
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
            if segue.identifier == "LightsInfoSegue",
               let infoVC = segue.destination as? LightsInfoViewController,
               let light = selectedLight {
                infoVC.titleText = light.name
                infoVC.detailText = light.description
                infoVC.imageName = light.imageName
            }
        }
    }

    extension LightsViewController: UICollectionViewDataSource {

        func collectionView(_ collectionView: UICollectionView,
                            numberOfItemsInSection section: Int) -> Int {
            lights.count
        }

        func collectionView(_ collectionView: UICollectionView,
                            cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "LightsCollectionViewCell",
                for: indexPath
            ) as! LightsCollectionViewCell

            cell.configure(with: lights[indexPath.item])
            return cell
        }
    }

extension LightsViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedLight = lights[indexPath.item]
        performSegue(withIdentifier: "LightsInfoSegue", sender: self)
    }
}

