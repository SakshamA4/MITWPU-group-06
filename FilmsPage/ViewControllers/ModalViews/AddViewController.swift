//
//  AddViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 10/12/25.
//

import UIKit

class AddViewController: UIViewController {

    var film: Film?
    var sequenceDelegate: AddSequenceDelegate?
    var propDelegate: AddPropDelegate?
    var characterDelegate: AddCharacterDelegate?
    

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func addCharacterButtonTapped(_ sender: Any) {
        performSegue(withIdentifier: "addCharacterSegue", sender: nil)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "addCharacterSegue" {
            let vc = segue.destination as! AddCharacterViewController
            vc.film = self.film
            vc.addCharacterDelegate = self.characterDelegate
        }
        else if segue.identifier == "addPropSegue" {
            let vc = segue.destination as! AddPropViewController
            vc.film = self.film
            vc.delegate = self.propDelegate
        }
        else if segue.identifier == "addSequenceSegue" {
        let vc = segue.destination as! AddSequenceViewController
            vc.film = self.film
            vc.delegate = self.sequenceDelegate 
            
        }
    }
}
