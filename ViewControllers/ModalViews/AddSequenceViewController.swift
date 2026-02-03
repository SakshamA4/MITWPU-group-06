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
    
    @IBOutlet weak var newSequenceView: UIView!
    
    var film: Film?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        notesTextField.layer.cornerRadius = 16
        nameTextField.layer.cornerRadius = 16
        newSequenceView.layer.cornerRadius = 16
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
