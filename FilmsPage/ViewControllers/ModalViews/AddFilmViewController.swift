//
//  AddFilmViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 08/12/25.
//

import UIKit

protocol AddFilmDelegate {
    func addFilm(film: Film)
}

class AddFilmViewController: UIViewController {
    
    
    @IBOutlet weak var notesTextField: UITextView!
    @IBOutlet weak var nameTextField: UITextField!
    var delegate: AddFilmDelegate?
    override func viewDidLoad() {
        super.viewDidLoad()


    }
    
    
    @IBAction func addFilm(_ sender: Any) {
        let film = Film(
            id: UUID(),
            name: nameTextField.text ?? "",
            sequences: 0,
            scenes: 0,
            time: "",
            characters: 0,
            image: "Image"
        )
        
        FilmService.shared.addFilm(film)

        delegate?.addFilm(film: film)
        dismiss(animated: true)
    }


}
