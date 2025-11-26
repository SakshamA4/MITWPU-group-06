//
//  MyFilmViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 26/11/25.
//

import UIKit

//class MyFilmViewController: UIViewController {
//
//    @IBOutlet weak var collectionView: UICollectionView!
//    
//    private let sceneCellId = "scene_cell"
//    private let characterCellId = "character_cell"
//    private let propCellId = "prop_cell"
//    
//    var Scene: [scenes] = []
//    var Character: [characters] = []
//    var Props: [props] = []
//    let dataStore = DataStore(Scenes: [], Props: [], Characters: [])
//    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        
//        dataStore.loadData()
//        
//        registerCells()
//        // Do any additional setup after loading the view.
//    }
//    
//    func registerCells() {
//        
//        collectionView.register(UINib(nibName: "ScenesCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "scene_cell")
//        
//        collectionView.register(UINib(nibName: "CharactersCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "character_cell")
//        
//        collectionView.register(UINib(nibName: "PropsCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "prop_cell")
//        
//        collectionView.register(UINib(nibName: "HeaderView",bundle: nil),forSupplementaryViewOfKind: "header",withReuseIdentifier: "header_cell")
//        
//    }
//    
//
//    
//
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
//extension MyFilmViewController: UICollectionViewDataSource, UICollectionViewDelegate{
//    func numberOfSections(in collectionView: UICollectionView) -> Int {
//        3
//    }
//    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
//        if section == 0 {
//            return Scene.count
//        } else if section == 1 {
//            return Character.count
//        } else {
//            return Props.count
//        }
//    }
//    
//    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
//        <#code#>
//    }
//    
    
    
//}
