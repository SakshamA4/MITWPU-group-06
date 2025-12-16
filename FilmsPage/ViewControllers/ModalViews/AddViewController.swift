//
//  AddViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 10/12/25.
//

import UIKit

class AddViewController: UIViewController {

    var dataStore = DataStore.shared
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
            vc.dataStore = self.dataStore    // ← pass datastore forward
            vc.film = self.film// ← pass film forward
            vc.addCharacterDelegate = self.characterDelegate
//            vc.delegate = self.characterDelegate
        }
        else if segue.identifier == "addPropSegue" {
            let vc = segue.destination as! AddPropViewController
            vc.dataStore = self.dataStore   // ← pass datastore forward
            vc.film = self.film// ← pass film forward
            vc.delegate = self.propDelegate
        }
        else if segue.identifier == "addSequenceSegue" {
        let vc = segue.destination as! AddSequenceViewController
            vc.film = self.film
            vc.dataStore = self.dataStore     // ← You forgot this!
            vc.delegate = self.sequenceDelegate 
            
        }
    }
}
