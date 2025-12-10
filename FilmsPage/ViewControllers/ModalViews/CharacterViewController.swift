//
//  CharacterViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 10/12/25.
//

import UIKit

class CharacterViewController: UIViewController {

    @IBOutlet weak var characterTitle: UILabel!
    
    var film: Film?
    var dataStore: DataStore?
    var characters: Character?
    
    override func viewDidLoad() {
        super.viewDidLoad()
       updateTitle()
        // Do any additional setup after loading the view.
    }
    
    private func updateTitle() {
        characterTitle.text = characters?.name ?? "Character"
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
