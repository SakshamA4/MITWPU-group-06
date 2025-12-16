//
//  AddSequenceViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 08/12/25.
//

import UIKit

protocol AddSequenceDelegate {
    func addSequence(sequence: Sequence)
}

class AddSequenceViewController: UIViewController {
    
    var delegate: AddSequenceDelegate?
    var dataStore = DataStore.shared
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var notesTextField: UITextView!

    var film: Film?
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    @IBAction func AddNewSequence(_ sender: Any) {
        guard let film = film else { return }
        guard let name = nameTextField.text, !name.isEmpty else { return }

        let sequence = Sequence(
            id: UUID(),
            name: nameTextField.text!,
            image: "Image",
            filmId: film.id   // attach to the correct film!// ← use existing film id
        )
        
        delegate?.addSequence(sequence: sequence)
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
