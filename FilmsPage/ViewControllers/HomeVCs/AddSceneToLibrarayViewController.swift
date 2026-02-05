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
    
    var targetSequenceId: UUID?
    
    @IBAction func saveButtonTapped(_ sender: Any) {
        guard let name = sceneNameTextField.text, !name.isEmpty else { return }
            let notes = sceneNotes.text ?? ""
            
            // 1. Create the global model (for Home/Recent Scenes)
            let newRecentModel = ScenesModel(name: name, image: "Image", notes: notes)
            ScenesDataStore.shared.addToRecent(scene: newRecentModel)
            
            // 2. 📍 THE FIX: Create and save the Scene for the specific Film Sequence
            if let seqId = targetSequenceId {
                // Create a Scene object that matches your project hierarchy
                let projectScene = Scene(
                    id: newRecentModel.id, // Keep IDs identical for consistency
                    name: name,
                    SequenceId: seqId
                )
                
                // You may need to add a 'notes' field to your Scene struct in SequenceService.swift
                // projectScene.notes = notes
                
                // Add the scene to your project database
                // SequenceService.shared.addScene(projectScene)
            }
            
            dismiss(animated: true)
    }
}
