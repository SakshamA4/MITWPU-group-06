import UIKit

class SignupViewController: UIViewController {

    @IBOutlet weak var createAccountButton: UIButton!

    @IBOutlet weak var emailTextField: UITextField!

    @IBOutlet weak var passwordTextField: UITextField!

    override func viewDidLoad() {
            super.viewDidLoad()

            // --- 1. Define the desired light color (e.g., light gray) ---
            let lightPlaceholderColor = UIColor.systemGray3 // A bright, common light gray color

            // --- 2. Update Email Text Field Placeholder ---
            if let emailPlaceholder = emailTextField.placeholder {
                emailTextField.attributedPlaceholder = NSAttributedString(
                    string: emailPlaceholder,
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

     // Connect the 'Create account' button to this action
     @IBAction func createAccountButtonTapped(_ sender: UIButton) {

         guard let email = emailTextField.text, !email.isEmpty else {
                 showValidationAlert(title: "Validation Error", message: "Email field is empty. Please enter a valid email address.")
                 return
             }

             guard let password = passwordTextField.text, !password.isEmpty else {
                 showValidationAlert(title: "Validation Error", message: "Password field is empty. Please enter a password.")
                 return
             }

             // 2. NOW YOU CAN USE THE 'email' and 'password' variables
             print("User attempting to sign up with: \(email) and password: \(password)")

         // **VITAL: Transition to the Home Page**

         let storyboard = UIStoryboard(name: "HomePage", bundle: nil) // **Check your Storyboard name**

         guard let homeVC = storyboard.instantiateViewController(withIdentifier: "HomeViewControllerID") as? UIViewController else {
             return
         }

         guard let window = self.view.window else { return }
         window.rootViewController = homeVC

         UIView.transition(with: window, duration: 0.5, options: .transitionCrossDissolve, animations: nil, completion: nil)
     }

     private func showValidationAlert(title: String, message: String) {
         let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
         alertController.addAction(UIAlertAction(title: "OK", style: .default))
         self.present(alertController, animated: true)
     }
 }
