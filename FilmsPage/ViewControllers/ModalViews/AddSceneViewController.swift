//
//  AddSceneViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 12/12/25.
//

import UIKit

class AddSceneViewController: UIViewController {
    
    var sequence: Sequence?

    @IBOutlet weak var sceneName: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func addButtonTapped(_ sender: Any) {
        guard let sequence = sequence else { return }
        guard let name = sceneName.text, !name.isEmpty else { return }
        
        let scene = Scene(id: UUID(), name: name, image: "Image", SequenceId: sequence.id)
        
        SceneService.shared.addScene(scene)
        dismiss(animated: true)
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
