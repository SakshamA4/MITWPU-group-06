//
//  SequenceViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 28/11/25.
//

import UIKit

class SequenceViewController: UIViewController {

    var dataStore = DataStore.shared
    @IBOutlet weak var collectionView: UICollectionView!
    
    var scene: [Scene] = []
    var sceneCellId = "scene_cell"
    var sequence: Sequence?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let sequence = sequence {
            scene = DataStore.shared.getScenes(sequenceId: sequence.id)
        }
        

        
        updateTitle()
        //print("[SequenceViewController] sequence name:", sequence.name)
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 8
        collectionView.setCollectionViewLayout(layout, animated: false)
        collectionView.dataSource = self
        collectionView.delegate = self
        registerCells()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if let sequence = sequence {
            scene = DataStore.shared.getScenes(sequenceId: sequence.id)
        }

        updateTitle()
        collectionView.reloadData()
    }
    
    func registerCells() {
        collectionView.register(UINib(nibName: "SceneCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "scene_cell")
    }
    
    private func updateTitle() {
        navigationItem.title = sequence?.name ?? "Sequence"
    }

}

extension SequenceViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: sceneCellId , for: indexPath) as? SceneCollectionViewCell else {
            return UICollectionViewCell()
        }
        let scene = scene[indexPath.item]
        cell.configureCell(scene: scene)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return scene.count
    }
}

extension SequenceViewController: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, AddSceneDelegate {
    func addScene(scene: Scene) {
        
        DataStore.shared.createNewScene(newScene: scene)
        
        if let sequence = sequence {
            self.scene = DataStore.shared.getScenes(sequenceId: sequence.id)
        }
        collectionView.reloadData()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "addSceneSegue" {
            let vc = segue.destination as! AddSceneViewController
            vc.delegate = self
            vc.dataStore = DataStore.shared
            vc.sequence = sequence
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let inset: CGFloat = 40
        let interItem: CGFloat = 40
        let columns: CGFloat = 4
        let totalSpacing = inset * 2 + interItem * (columns - 1)
        let width = (collectionView.bounds.width - totalSpacing) / columns
        return CGSize(width: width, height: width)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let sequence = sequence else { return }
        performSegue(withIdentifier: "sequence2Segue", sender: sequence)
    }

    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 16, left: 52, bottom: 16, right: 52)
    }
}

