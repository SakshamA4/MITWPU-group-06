//
//  LibraryPropsViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 11/12/25.
//

import UIKit


class LibraryPropsViewController: UIViewController {

    @IBOutlet weak var propsCollectionView: UICollectionView!

    private var dataStore = DataStore.shared// [PropItem]
    private var props: [PropItem] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        propsCollectionView.dataSource = self
        propsCollectionView.delegate = self
        propsCollectionView.backgroundColor = .clear
        props = DataStore.shared.getProps()
        print(props)

        propsCollectionView.register(
            UINib(nibName: "LibraryPropsCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "LibraryPropsCollectionViewCell"
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        configureLayout()
    }

    private func configureLayout() {
        guard let layout = propsCollectionView.collectionViewLayout as? UICollectionViewFlowLayout else {
            let newLayout = UICollectionViewFlowLayout()
            propsCollectionView.setCollectionViewLayout(newLayout, animated: false)
            configureLayout()
            return
        }

        // 🔴 IMPORTANT: disable self-sizing
        layout.estimatedItemSize = .zero

        let columns: CGFloat = 4
        let spacing: CGFloat = 35
        let sideInset: CGFloat = 75
//        let verticalInset: CGFloat = 40

        let width = propsCollectionView.bounds.width
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
}

extension LibraryPropsViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        props.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "LibraryPropsCollectionViewCell",
            for: indexPath
        ) as! LibraryPropsCollectionViewCell

        cell.configure(with: props[indexPath.item])
        return cell
    }
}

extension LibraryPropsViewController: UICollectionViewDelegate {}
