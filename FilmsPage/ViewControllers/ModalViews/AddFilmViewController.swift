//
//  AddFilmViewController.swift
//  FilmsPage
//

import UIKit
import PhotosUI

class AddFilmViewController: UIViewController {

    @IBOutlet weak var notesTextField: UITextView!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var mainView: UIView!
    @IBOutlet weak var filmImageView: UIImageView!   // ← wire this to your UIImageView in storyboard
    @IBOutlet weak var addImageButton: UIButton!     // ← wire this to your "Add Image" button

    private var selectedImage: UIImage?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        mainView.layer.cornerRadius = 16
        mainView.clipsToBounds = true
        setupImageView()
        styleAddImageButton()
        notesTextField.delegate = self
    }

    private func styleAddImageButton() {
        var config = UIButton.Configuration.filled()
        config.title = "Add Image"
        config.baseForegroundColor = .white
        config.baseBackgroundColor = UIColor(red: 0.75, green: 0.1, blue: 0.15, alpha: 1.0) // your red
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 24, bottom: 10, trailing: 24)
        addImageButton.configuration = config
        notesTextField.layer.borderColor = UIColor(hex: "#D9D9D9").withAlphaComponent(0.3).cgColor
        notesTextField.layer.borderWidth = 1.0
        nameTextField.layer.borderColor = UIColor(hex: "#D9D9D9").withAlphaComponent(0.3).cgColor
        nameTextField.layer.borderWidth = 1.0
        notesTextField.layer.cornerRadius = 12
        nameTextField.layer.cornerRadius = 10
        nameTextField.attributedPlaceholder = NSAttributedString(
            string: "Add Name",
            attributes: [.foregroundColor: UIColor.systemGray]
        )
        notesTextField.text = "Add Notes"
        notesTextField.textColor = UIColor.systemGray
    }

    // MARK: - Image View Setup

    private func setupImageView() {
        filmImageView.contentMode = .scaleAspectFill
        filmImageView.clipsToBounds = true
        filmImageView.layer.cornerRadius = 12
        filmImageView.layer.borderWidth = 1
        filmImageView.layer.borderColor = UIColor.gray.withAlphaComponent(0.4).cgColor
        filmImageView.isUserInteractionEnabled = true

        // Show default image immediately
        filmImageView.image = UIImage(named: "Image")

        // Tap gesture on image itself as backup trigger
        let tap = UITapGestureRecognizer(target: self, action: #selector(presentImageSourceOptions))
        filmImageView.addGestureRecognizer(tap)
    }

    // MARK: - Image Picker Trigger

    // Wire your "Add Image" UIButton's Touch Up Inside to this in storyboard
    @IBAction func addImageTapped(_ sender: UIButton) {
        presentImageSourceOptions()
    }

    @objc private func presentImageSourceOptions() {
        let alert = UIAlertController(title: "Add Film Image", message: nil, preferredStyle: .actionSheet)

        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            alert.addAction(UIAlertAction(title: "Camera", style: .default) { [weak self] _ in
                self?.presentCamera()
            })
        }

        alert.addAction(UIAlertAction(title: "Photo Library", style: .default) { [weak self] _ in
            self?.presentPHPicker()
        })

        if selectedImage != nil {
            alert.addAction(UIAlertAction(title: "Remove Image", style: .destructive) { [weak self] _ in
                self?.selectedImage = nil
                self?.filmImageView.image = UIImage(named: "Image")
                self?.addImageButton.setTitle("Add Image", for: .normal)
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // REQUIRED on iPad — without this it crashes on iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = addImageButton
            popover.sourceRect = addImageButton.bounds
            popover.permittedArrowDirections = .any
        }

        present(alert, animated: true)
    }

    private func presentPHPicker() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func presentCamera() {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = true
        picker.delegate = self
        present(picker, animated: true)
    }

    // MARK: - Save Film

    @IBAction func addFilm(_ sender: Any) {
        guard let name = nameTextField.text, !name.isEmpty else {
            shakeField(nameTextField)
            return
        }

        // ← ADD THIS BLOCK
        let notesText = (notesTextField.text == "Add Notes" || notesTextField.text.isEmpty)
            ? ""
            : notesTextField.text ?? ""

        let imageNameToStore: String
        if let pickedImage = selectedImage {
            imageNameToStore = saveImageToDisk(pickedImage) ?? "Image"
        } else {
            imageNameToStore = "Image"
        }

        let film = Film(
            id: UUID(),
            name: name,
            sequences: 0,
            scenes: 0,
            time: "",
            characters: 0,
            image: imageNameToStore,
            notes: notesText,   // ← ADD THIS LINE
            createdDate: Date()
        )

        FilmService.shared.addFilm(film)
        dismiss(animated: true)
    }

    // MARK: - Helpers

    private func saveImageToDisk(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let filename = "film_\(UUID().uuidString).jpg"
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        do {
            try data.write(to: url)
            return filename
        } catch {
            print("❌ Image save failed: \(error)")
            return nil
        }
    }

    private func shakeField(_ view: UIView) {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = 0.4
        animation.values = [-10, 10, -8, 8, -5, 5, 0]
        view.layer.add(animation, forKey: "shake")
    }
}

// MARK: - PHPickerViewControllerDelegate

extension AddFilmViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else { return }
            DispatchQueue.main.async {
                self?.selectedImage = image
                self?.filmImageView.image = image
                self?.addImageButton.setTitle("Change Image", for: .normal)
            }
        }
    }
}

// MARK: - UIImagePickerControllerDelegate (Camera)

extension AddFilmViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
        selectedImage = image
        filmImageView.image = image ?? UIImage(named: "Image")
        addImageButton.setTitle("Change Image", for: .normal)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

extension AddFilmViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == UIColor.systemGray {
            textView.text = nil
            textView.textColor = .white // or whatever your normal text colour is
        }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.text = "Add Notes"
            textView.textColor = UIColor.systemGray
        }
    }
}
