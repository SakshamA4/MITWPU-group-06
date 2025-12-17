//
//  AddSequenceViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 08/12/25.
//

import UIKit

class AddSequenceViewController: UIViewController {
    
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var notesTextField: UITextView!
    
    var film: Film?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func AddNewSequence(_ sender: Any) {
        guard let film = film else { return }
        guard let name = nameTextField.text, !name.isEmpty else { return }

        let sequence = Sequence(
            id: UUID(),
            name: name,
            image: "Image",
            filmId: film.id
        )
        
        SequenceService.shared.addSequence(sequence)
        dismiss(animated: true)
    }
}
