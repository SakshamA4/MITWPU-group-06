//
//  AddSceneToLibrarayViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 17/12/25.
//

import UIKit

class AddSceneToLibrarayViewController: UIViewController {

    @IBOutlet weak var sceneNameTextField: UITextField!
    
    @IBOutlet weak var sceneNotes: UITextView!
    
    @IBOutlet weak var sceneView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneNotes.layer.cornerRadius = 16
        sceneView.layer.cornerRadius = 16
        sceneNameTextField.layer.cornerRadius = 16
    }

    @IBAction func saveButtonTapped(_ sender: Any) {
        guard let name = sceneNameTextField.text, !name.isEmpty else { return }
        
        // Update the data store (which posts notification automatically)
        let newScene = ScenesModel(name: name, image: "Image")
        ScenesDataStore.shared.addToRecent(scene: newScene)
        
        // Dismiss
        dismiss(animated: true)
    }
}
