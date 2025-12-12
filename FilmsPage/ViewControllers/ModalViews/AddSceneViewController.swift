//
//  AddSceneViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 12/12/25.
//

import UIKit

protocol AddSceneDelegate {
    func addScene(scene: Scene)
}

class AddSceneViewController: UIViewController {

    @IBOutlet weak var sceneName: UITextField!
    
    @IBOutlet weak var sceneNotes: UITextView!
    
    var delegate: AddSceneDelegate?
    var datastore = DataStore.shared
    var sequence: Sequence?
    //var film: Film?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    

    @IBAction func addScene(_ sender: Any) {
        
        guard let sequence = sequence else { return }
        guard let name = sceneName.text, !name.isEmpty else { return }
        
        let scene = Scene(
            id: UUID(),
            name: sceneName.text!,
            image: "Image",
            SequenceId: sequence.id
        )
        delegate?.addScene(scene: scene)
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
