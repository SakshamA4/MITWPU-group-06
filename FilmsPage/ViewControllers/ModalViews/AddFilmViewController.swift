//
//  AddFilmViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 08/12/25.
//

import UIKit

class AddFilmViewController: UIViewController {
    
    @IBOutlet weak var notesTextField: UITextView!
    @IBOutlet weak var nameTextField: UITextField!
    
    @IBOutlet weak var mainView: UIView!
    
    
    override func viewDidLoad() {
        
        
        super.viewDidLoad()
        
        notesTextField.layer.cornerRadius = 16
      
        mainView.layer.cornerRadius = 16
        mainView.clipsToBounds = true
        
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
        dismiss(animated: true)
    }
}
