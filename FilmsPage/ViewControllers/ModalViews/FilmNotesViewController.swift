//
//  FilmNotesViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 06/03/26.
//

import UIKit

class FilmNotesViewController: UIViewController {

    @IBOutlet weak var notesTextView: UITextView!

    @IBOutlet weak var checkmarkButton: UIButton!

    @IBOutlet weak var sequencesLabel: UILabel!

    @IBOutlet weak var scenesLabel: UILabel!

    @IBOutlet weak var characterLabel: UILabel!

    @IBOutlet weak var propsLabel: UILabel!

    @IBOutlet weak var filmName: UILabel!

    var film: Film?   // ← ADD THIS

    override func viewDidLoad() {
        super.viewDidLoad()
        populateUI()
        notesTextView.layer.borderColor = UIColor(hex: "#D9D9D9").withAlphaComponent(0.3).cgColor
        notesTextView.layer.borderWidth = 1.0
        notesTextView.layer.cornerRadius = 12

    }

    private func populateUI() {
        guard let film else { return }
        filmName.text        = film.name.capitalized
        notesTextView.text   = film.notes.isEmpty ? "No notes added." : film.notes
        sequencesLabel.text  = "Sequences: \(film.sequences)"
        scenesLabel.text     = "Scenes: \(film.scenes)"
        characterLabel.text  = "Characters: \(film.characters)"
        propsLabel.text      = "Props: \(film.props)"   // use film.props once added to model
    }

    @IBAction func checkmarkTapped(_ sender: UIButton) {
        dismiss(animated: true)
    }

}
