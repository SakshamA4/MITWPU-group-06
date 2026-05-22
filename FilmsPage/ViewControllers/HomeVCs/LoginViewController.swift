import UIKit

class LoginViewController: UIViewController {

    @IBOutlet weak var logInButton: UIButton!

    @IBOutlet weak var usernameTextField: UITextField!

    @IBOutlet weak var passwordTextField: UITextField!

    override func viewDidLoad() {
            super.viewDidLoad()

            // --- 1. Define the desired light color (e.g., light gray) ---
            let lightPlaceholderColor = UIColor.systemGray3 // A bright, common light gray color

            // --- 2. Update Username Text Field Placeholder ---
            if let usernamePlaceholder = usernameTextField.placeholder {
                usernameTextField.attributedPlaceholder = NSAttributedString(
                    string: usernamePlaceholder,
                    attributes: [
                        .foregroundColor: lightPlaceholderColor
                    ]
                )
            }

            // --- 3. Update Password Text Field Placeholder ---
            if let passwordPlaceholder = passwordTextField.placeholder {
                passwordTextField.attributedPlaceholder = NSAttributedString(
                    string: passwordPlaceholder,
                    attributes: [
                        .foregroundColor: lightPlaceholderColor
                    ]
                )
            }
        }

     // Connect the Log In button to this action
     @IBAction func loginButtonTapped(_ sender: UIButton) {

         guard let username = usernameTextField.text, !username.isEmpty else {
                 showValidationAlert(title: "Validation Error", message: "Username field is empty. Please enter your username.")
                 return
             }

             guard let password = passwordTextField.text, !password.isEmpty else {
                 showValidationAlert(title: "Validation Error", message: "Password field is empty. Please enter your password.")
                 return
             }

             // 2. NOW YOU CAN USE THE 'username' and 'password' variables
             print("User attempting to log in with: \(username) and password: \(password)")

         // **VITAL: Transition to the Home Page**
         // This is a typical way to transition from Auth flow to Main app flow

         let storyboard = UIStoryboard(name: "HomePage", bundle: nil) // **Check your Storyboard name**

         // Assuming your main screen (e.g., the Home VC that presents the profile card) has this ID
         guard let homeVC = storyboard.instantiateViewController(withIdentifier: "HomeViewControllerID") as? UIViewController else {
             return
         }

         // Set the Home VC as the new root of the window
         guard let window = self.view.window else { return }
         window.rootViewController = homeVC

         // Optional: Add a transition animation
         UIView.transition(with: window, duration: 0.5, options: .transitionCrossDissolve, animations: nil, completion: nil)
     }

     private func showValidationAlert(title: String, message: String) {
         let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
         alertController.addAction(UIAlertAction(title: "OK", style: .default))
         self.present(alertController, animated: true)
     }
 }
