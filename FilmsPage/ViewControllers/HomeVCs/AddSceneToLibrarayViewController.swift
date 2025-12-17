//
//  AddSceneToLibrarayViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 17/12/25.
//

import UIKit

class AddSceneToLibrarayViewController: UIViewController {

    @IBOutlet weak var sceneNameTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func saveButtonTapped(_ sender: Any) {
        guard let name = sceneNameTextField.text, !name.isEmpty else { return }
        
        // Update the data store (which posts notification automatically)
        let newScene = ScenesModel(name: name, image: "default_scene_image")
        ScenesDataStore.shared.addToRecent(scene: newScene)
        
        // Dismiss
        dismiss(animated: true)
    }
}
