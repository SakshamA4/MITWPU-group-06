//
//  AddSequenceViewController.swift
//  FilmsPage
//

import UIKit
import PhotosUI

class AddSequenceViewController: UIViewController {

    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var notesTextField: UITextView!
    @IBOutlet weak var newSequenceView: UIView!

    // Wire these two to your storyboard elements
    @IBOutlet weak var sequenceImageView: UIImageView!
    @IBOutlet weak var addImageButton: UIButton!

    var film: Film?
    private var selectedImage: UIImage?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        notesTextField.layer.cornerRadius = 16
        nameTextField.layer.cornerRadius = 16
        newSequenceView.layer.cornerRadius = 16
        newSequenceView.clipsToBounds = true

        setupImageView()
        styleAddImageButton()
    }

    // MARK: - Image View Setup

    private func setupImageView() {
        sequenceImageView.contentMode = .scaleAspectFill
        sequenceImageView.clipsToBounds = true
        sequenceImageView.layer.cornerRadius = 12
        sequenceImageView.layer.borderWidth = 1
        sequenceImageView.layer.borderColor = UIColor.gray.withAlphaComponent(0.4).cgColor
        sequenceImageView.isUserInteractionEnabled = true
        sequenceImageView.image = UIImage(named: "Image")

        let tap = UITapGestureRecognizer(target: self, action: #selector(presentImageSourceOptions))
        sequenceImageView.addGestureRecognizer(tap)

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

    private func styleAddImageButton() {
        var config = UIButton.Configuration.filled()
        config.title = "Add Image"
        config.baseForegroundColor = .white
        config.baseBackgroundColor = UIColor(red: 0.75, green: 0.1, blue: 0.15, alpha: 1.0)
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 24, bottom: 10, trailing: 24)
        addImageButton.configuration = config
    }

    // MARK: - Image Picker

    @IBAction func addImageTapped(_ sender: UIButton) {
        presentImageSourceOptions()
    }

    @objc private func presentImageSourceOptions() {
        let alert = UIAlertController(title: "Add Sequence Image", message: nil, preferredStyle: .actionSheet)

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
                self?.sequenceImageView.image = UIImage(named: "Image")
                var config = self?.addImageButton.configuration
                config?.title = "Add Image"
                self?.addImageButton.configuration = config
            })
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        // Required for iPad — prevents crash
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

    // MARK: - Save Sequence

    @IBAction func addNewSequence(_ sender: Any) {
        guard let film = film else { return }
        guard let name = nameTextField.text, !name.isEmpty else {
            shakeField(nameTextField)
            return
        }

        let imageNameToStore: String
        if let pickedImage = selectedImage {
            imageNameToStore = saveImageToDisk(pickedImage) ?? "Image"
        } else {
            imageNameToStore = "Image"
        }

        let sequence = Sequence(
            id: UUID(),
            name: name,
            image: imageNameToStore,
            filmId: film.id
        )

        SequenceService.shared.addSequence(sequence)
        dismiss(animated: true)
    }

    // MARK: - Helpers

    private func saveImageToDisk(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let filename = "sequence_\(UUID().uuidString).jpg"
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        do {
            try data.write(to: url)
            return filename
        } catch {
            print("❌ Sequence image save failed: \(error)")
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

extension AddSequenceViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else { return }
            DispatchQueue.main.async {
                self?.selectedImage = image
                self?.sequenceImageView.image = image
                var config = self?.addImageButton.configuration
                config?.title = "Change Image"
                self?.addImageButton.configuration = config
            }
        }
    }
}

// MARK: - UIImagePickerControllerDelegate (Camera)

extension AddSequenceViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
        selectedImage = image
        sequenceImageView.image = image ?? UIImage(named: "Image")
        var config = addImageButton.configuration
        config?.title = "Change Image"
        addImageButton.configuration = config
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
extension AddSequenceViewController: UITextViewDelegate {
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
