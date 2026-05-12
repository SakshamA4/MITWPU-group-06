//
//  LibraryPropsViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 11/12/25.
//

import UIKit
import UniformTypeIdentifiers
class LibraryPropsViewController: UIViewController {

    @IBOutlet weak var propsCollectionView: UICollectionView!

    private let propService = PropService.shared
    private var props: [PropItem] = []
    private var importCoordinator: PropImportCoordinator?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        propsCollectionView.dataSource = self
//        propsCollectionView.delegate = self
        propsCollectionView.backgroundColor = .clear
        props = propService.getProps()
        print(props)
        
        NotificationCenter.default.addObserver(self, selector: #selector(handlePropsUpdated), name: NSNotification.Name(NotificationNames.propsUpdated), object: nil)
        
        let importButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(importTapped))
        navigationItem.rightBarButtonItem = importButton

        propsCollectionView.register(
            UINib(nibName: "LibraryPropsCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "LibraryPropsCollectionViewCell"
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        configureLayout()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.propsCollectionView?.collectionViewLayout.invalidateLayout()
        })
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
    
    @objc private func handlePropsUpdated() {
        self.props = self.propService.getProps()
        self.propsCollectionView.reloadData()
    }
    
    @objc private func importTapped() {
        let coordinator = PropImportCoordinator()
        self.importCoordinator = coordinator
        coordinator.start(presentingViewController: self)
    }
}

extension LibraryPropsViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        props.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "LibraryPropsCollectionViewCell",
            for: indexPath
        ) as? LibraryPropsCollectionViewCell else {
            return UICollectionViewCell()
        }

        cell.configure(with: props[indexPath.item])
        return cell
    }
}

//extension LibraryPropsViewController: UICollectionViewDelegate {
//
//    func collectionView(_ collectionView: UICollectionView,
//                        didSelectItemAt indexPath: IndexPath) {
//
//        let selectedProp = props[indexPath.item]
//
//        let storyboard = UIStoryboard(name: "Main", bundle: nil)
//        guard let vc = storyboard.instantiateViewController(
//            withIdentifier: "PropDetailViewController"
//        ) as? PropDetailViewController else {
//            return
//        }
//
//        vc.prop = selectedProp
//        navigationController?.pushViewController(vc, animated: true)
//    }
//}
