//
//  SequenceViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 28/11/25.
//

import UIKit

class SequenceViewController: UIViewController {

    private let sceneService = SceneService.shared
    @IBOutlet weak var collectionView: UICollectionView!

    @IBOutlet weak var sequenceTitle: UILabel!
    
    var scene: [Scene] = []
    var sceneCellId = "scene_cell"
    var sequence: Sequence?
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        refreshData()

        updateTitle()
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 8
        collectionView.setCollectionViewLayout(layout, animated: false)
        collectionView.dataSource = self
        collectionView.delegate = self
        registerCells()
        setupObservers()
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(refreshData),
            name: NSNotification.Name(NotificationNames.scenesUpdated),
            object: nil
        )
    }
    
    @objc private func refreshData() {
        if let sequence = sequence {
            scene = sceneService.getScenes(forSequenceId: sequence.id)
        }
        collectionView?.reloadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshData()
        updateTitle()
    }

    func registerCells() {
        collectionView.register(
            UINib(nibName: "SceneCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: "scene_cell"
        )
    }

    private func updateTitle() {
        sequenceTitle.text = sequence?.name ?? "Sequence"
    }

}

extension SequenceViewController: UICollectionViewDataSource {
    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: sceneCellId,
                for: indexPath
            ) as? SceneCollectionViewCell
        else {
            return UICollectionViewCell()
        }
        let scene = scene[indexPath.item]
        cell.configureCell(scene: scene)
        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        return scene.count
    }
}

extension SequenceViewController: UICollectionViewDelegate,
    UICollectionViewDelegateFlowLayout
{
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "addSceneSegue" {
            let vc = segue.destination as! AddSceneViewController
            vc.sequence = sequence
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let inset: CGFloat = 40
        let interItem: CGFloat = 40
        let columns: CGFloat = 4
        let totalSpacing = inset * 2 + interItem * (columns - 1)
        let width = (collectionView.bounds.width - totalSpacing) / columns
        return CGSize(width: width, height: width)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        let vc = MyFeatureCanvasVC()
       // navigationController?.pushViewController(vc, animated: true)
        let navController = UINavigationController(rootViewController: vc)
        navController.modalPresentationStyle = .fullScreen
        self.present(navController, animated: true)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        insetForSectionAt section: Int
    ) -> UIEdgeInsets {
        return UIEdgeInsets(top: 16, left: 52, bottom: 16, right: 52)
    }
}
