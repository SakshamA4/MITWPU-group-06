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

    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var notesTextField: UITextView!
    var delegate: AddSequenceDelegate?
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    @IBAction func AddNewSequence(_ sender: Any) {
        let sequence = Sequence(id: UUID(), name: nameTextField.text!, image: "Image", filmId: UUID())
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
