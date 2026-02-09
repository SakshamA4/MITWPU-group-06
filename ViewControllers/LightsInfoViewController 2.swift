//
//  LightsInfoViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 12/12/25.
//

import UIKit

class LightsInfoViewController: UIViewController {

    @IBOutlet weak var infoImageView: UIImageView!
        @IBOutlet weak var titleLabel: UILabel!
        @IBOutlet weak var descriptionLabel: UILabel!

        // Values to be filled by the presenting VC
        var titleText: String = ""
        var detailText: String = ""
        var imageName: String = ""

        override func viewDidLoad() {
            super.viewDidLoad()
            configureView()
        }

        private func configureView() {
            titleLabel.text = titleText

            descriptionLabel.text = detailText
            descriptionLabel.numberOfLines = 0
            descriptionLabel.lineBreakMode = .byWordWrapping

            infoImageView.image = UIImage(named: imageName)
        }

        @IBAction func closeButtonTapped(_ sender: Any) {
            dismiss(animated: true, completion: nil)
        }
    }
