//
//  ViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 06/12/25.
//

import UIKit

class NewFilmViewController: UIViewController {

    @IBOutlet weak var NewFilmView: UIView!
    @IBOutlet weak var BoxView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        NewFilmView.layer.cornerRadius = 20
        NewFilmView.layer.masksToBounds = true
        BoxView.layer.cornerRadius = 20
        BoxView.layer.masksToBounds = true

        // Do any additional setup after loading the view.
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
