//
//  ProfileViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 10/12/25.
//

import UIKit

class ProfileViewController: UIViewController {

    @IBOutlet weak var cardView: UIView!
    
    @IBOutlet weak var headerView: UIView!
    
    @IBOutlet weak var NameLabel: UILabel!
    
    
    @IBOutlet weak var closeButton: UIButton!
    
    @IBOutlet weak var SignOutButton: UIButton!
    
    // Reference to the embedded child VC
        private var staticTableVC: UserProfileTableViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // ----------------------------------------------------------------------
        // --- 1. Background Setup (The Fix for No Blur) ---
        
        // VITAL 1: Set the view's background to clear to allow sampling underneath.
        view.backgroundColor = .clear
        
        // VITAL 2: Ensure the presentation style is set (redundant if segue is correct, but safe)
        self.modalPresentationStyle = .overFullScreen
        
        // 3. Setup the Blur Effect
        let blurEffect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = view.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // 4. Insert the blur view at the absolute back.
        // NOTE: This line MUST be executed AFTER the view has been loaded,
        // and BEFORE any other view that might cover it is added.
        view.insertSubview(blurView, at: 0)
        
        // ----------------------------------------------------------------------
        // --- 2. Card Styling and Embedding ---
        
        // Make the close button circular
        closeButton.layer.cornerRadius = closeButton.bounds.height / 2
        
        // Execute the Table View Embedding
        embedStaticTableViewController()
    }
        
        // MARK: - Parent-Child Embedding Logic (VITAL)
        
        private func embedStaticTableViewController() {
            // NOTE: This assumes Storyboard ID 'UserProfileTableViewControllerID' is set on the child scene.
            let storyboard = UIStoryboard(name: "HomePage", bundle: nil) // Check your Storyboard name!
            guard let childVC = storyboard.instantiateViewController(withIdentifier: "UserProfileTableViewControllerID") as? UserProfileTableViewController else {
                fatalError("Error: Check Storyboard ID for UserProfileTableViewController.")
            }

            self.staticTableVC = childVC
            
            // 1. Establish the Parent-Child Relationship
            self.addChild(childVC)
            
            // 2. Add the Child's view to the Card's view hierarchy
            cardView.addSubview(childVC.view)
            
            // 3. Set Constraints to pin the table view between the header and the button
            childVC.view.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                // TOP: Pin to the bottom of the Avatar/Name View
                childVC.view.topAnchor.constraint(equalTo: NameLabel.bottomAnchor, constant: 20), // ADD spacing
                
                // BOTTOM: Pin just above the Sign Out Button (using -15 for spacing)
                childVC.view.bottomAnchor.constraint(equalTo: SignOutButton.topAnchor, constant: -15),
                
                childVC.view.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20), // ADD +20 margin
                    childVC.view.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20) // ADD -20 margin
                ])
            
            // 4. Notify the Child that the transition is complete
            childVC.didMove(toParent: self)
        }
            
            // Function for the Sign Out or Close Button (The checkmark button)
    @IBAction func closeButtonTapped(_ sender: UIButton) {
            // This dismisses the entire modal view controller
            dismiss(animated: true, completion: nil)
        }
    }

