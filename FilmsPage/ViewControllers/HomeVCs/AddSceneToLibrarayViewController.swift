//
//  AddSceneToLibrarayViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 17/12/25.
//

import UIKit


protocol SceneLibraryDelegate: AnyObject {
    func didAddScene()
    func reloadSceneData()
}


class AddSceneToLibrarayViewController: UIViewController {

    weak var delegate: SceneLibraryDelegate?
        
        @IBOutlet weak var sceneNameTextField: UITextField!
        override func viewDidLoad() {
            
            super.viewDidLoad()
        }

        @IBAction func saveButtonTapped(_ sender: Any) {
            guard let name = sceneNameTextField.text, !name.isEmpty else { return }
            
            // 1. Update the Single Source of Truth
            let newScene = ScenesModel(name: name, image: "default_scene_image")
            ScenesDataStore.shared.addToRecent(scene: newScene)
            
            // 2. Notify the Delegate (HomeVC)
            delegate?.didAddScene()
            delegate?.reloadSceneData()
            
            // 3. Dismiss
            dismiss(animated: true)
        }
        
    }
