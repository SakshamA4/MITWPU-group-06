//
//  WelcomeViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 13/12/25.
//

import UIKit

class WelcomeViewController: UIViewController {
    
    @IBOutlet weak var createAccountButton: UIButton!
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        applyBorderToCreateAccountButton()
            }
            
            // --- Helper function for cleanliness ---
            func applyBorderToCreateAccountButton() {
                // 1. Set the Corner Radius (to match rounded edges)
                createAccountButton.layer.cornerRadius = 8.0

                // 2. Set the Border Width (thickness)
                createAccountButton.layer.borderWidth = 1.0

                // 3. Set the Border Color to White
                // .cgColor is required when setting color on a layer
                createAccountButton.layer.borderColor = UIColor.white.cgColor
            }

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


