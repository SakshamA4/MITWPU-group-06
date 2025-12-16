//
//  CameraInfoViewController.swift
//  FilmsPage
//
//  Created by SDC-USER on 12/12/25.
//

import UIKit

class CameraInfoViewController: UIViewController {

        @IBOutlet weak var cameraInfoImageView: UIImageView!
        @IBOutlet weak var cameraTitleLabel: UILabel!
        @IBOutlet weak var cameraDescriptionLabel: UILabel!

        // This will be set from CameraViewController before presenting
        var item: CameraLibraryItem?

        override func viewDidLoad() {
            super.viewDidLoad()
            configureView()
        }

        private func configureView() {
            guard let item = item else { return }
            cameraTitleLabel.text = item.name
            cameraDescriptionLabel.text = item.description
            cameraInfoImageView.image = UIImage(named: item.imageName)
        }

        @IBAction func closeButtonTapped(_ sender: Any) {
            dismiss(animated: true, completion: nil)
        }
    }
