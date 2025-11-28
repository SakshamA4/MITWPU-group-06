//
//  SequenceViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 28/11/25.
//

import UIKit

class SequenceViewController: UIViewController {

    var sequence: Sequence?
    var dataStore: DataStore?
    @IBOutlet weak var collectionView: UICollectionView!
    
    var scene: [Scene] = []
    var sceneCellId = "scene_cell"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = sequence?.name ?? "Sequence"
        
        // Do any additional setup after loading the view.
    }
    
    func registerCells() {
        collectionView.register(UINib(nibName: "ScenesCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "scene_cell")
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
