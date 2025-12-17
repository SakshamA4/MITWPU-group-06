//
//  AddSceneOrFilmViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 17/12/25.
//

import UIKit

class AddSceneOrFilmViewController: UIViewController {
    
    var addSceneDelegate: SceneLibraryDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
    }
     
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {

        if segue.identifier == "goToAddSceneToLibrary" {
            let addSceneVC = segue.destination as! AddSceneToLibrarayViewController
            addSceneVC.delegate = self.addSceneDelegate

            if let nav = presentingViewController as? UINavigationController,
               let homeVC = nav.viewControllers.first as? HomeViewController {
                addSceneVC.delegate = homeVC
            }
        }
        // AddFilmViewController no longer needs delegate - uses NotificationCenter
    }
}
