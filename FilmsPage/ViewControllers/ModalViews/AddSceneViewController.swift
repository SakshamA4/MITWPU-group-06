//
//  AddSceneViewController.swift
//  FilmsPage
//

import UIKit
import PhotosUI

class AddSceneViewController: UIViewController {

    var sequence: Sequence?

    // Existing outlets
    @IBOutlet weak var sceneName: UITextField!
    @IBOutlet weak var newSceneView: UIView!
    @IBOutlet weak var sceneNotes: UITextView!

    // Wire these two to your storyboard elements
    @IBOutlet weak var sceneImageView: UIImageView!
    @IBOutlet weak var addImageButton: UIButton!

    private var selectedImage: UIImage?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        newSceneView.layer.cornerRadius = 16
        newSceneView.clipsToBounds = true
        sceneNotes.layer.cornerRadius = 16
        sceneName.layer.cornerRadius = 16

        // Tag for onboarding spotlight (Step 6 — scene name field)
        sceneName.accessibilityIdentifier = "onb_sceneNameField"

        setupImageView()
        styleAddImageButton()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Notify the onboarding manager that the Add Scene modal is visible.
        NotificationCenter.default.post(
            name: .onboardingVCAppeared,
            object: self,
            userInfo: ["vcType": "addScene"]
        )
    }

    // MARK: - Image View Setup

    private func setupImageView() {
        sceneImageView.contentMode = .scaleAspectFill
        sceneImageView.clipsToBounds = true
        sceneImageView.layer.cornerRadius = 12
        sceneImageView.layer.borderWidth = 1
        sceneImageView.layer.borderColor = UIColor.gray.withAlphaComponent(0.4).cgColor
        sceneImageView.isUserInteractionEnabled = true
        sceneImageView.image = UIImage(named: "Image") // default image

        let tap = UITapGestureRecognizer(target: self, action: #selector(presentImageSourceOptions))
        sceneImageView.addGestureRecognizer(tap)
        sceneNotes.layer.borderColor = UIColor(hex: "#D9D9D9").withAlphaComponent(0.3).cgColor
        sceneNotes.layer.borderWidth = 1.0
        sceneName.layer.borderColor = UIColor(hex: "#D9D9D9").withAlphaComponent(0.3).cgColor
        sceneName.layer.borderWidth = 1.0
        sceneNotes.layer.cornerRadius = 12
        sceneName.layer.cornerRadius = 10
        sceneName.attributedPlaceholder = NSAttributedString(
            string: "Add Name",
            attributes: [.foregroundColor: UIColor.systemGray]
        )
        sceneNotes.text = "Add Notes"
        sceneNotes.textColor = UIColor.systemGray
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
        let alert = UIAlertController(title: "Add Scene Image", message: nil, preferredStyle: .actionSheet)

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
                self?.sceneImageView.image = UIImage(named: "Image")
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

    // MARK: - Save Scene

    @IBAction func addButtonTapped(_ sender: Any) {
        guard let sequence = sequence else { return }
        guard let name = sceneName.text, !name.isEmpty else {
            shakeField(sceneName)
            return
        }

        let imageNameToStore: String
        if let pickedImage = selectedImage {
            imageNameToStore = saveImageToDisk(pickedImage) ?? "Image"
        } else {
            imageNameToStore = "Image"
        }

        let scene = Scene(
            id: UUID(),
            name: name,
            image: imageNameToStore,
            sequenceId: sequence.id
        )

        SceneService.shared.addScene(scene)
        dismiss(animated: true)
    }

    // MARK: - Helpers

    private func saveImageToDisk(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let filename = "scene_\(UUID().uuidString).jpg"
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        do {
            try data.write(to: url)
            return filename
        } catch {
            print("❌ Scene image save failed: \(error)")
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

extension AddSceneViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let image = object as? UIImage else { return }
            DispatchQueue.main.async {
                self?.selectedImage = image
                self?.sceneImageView.image = image
                var config = self?.addImageButton.configuration
                config?.title = "Change Image"
                self?.addImageButton.configuration = config
            }
        }
    }
}

// MARK: - UIImagePickerControllerDelegate (Camera)

extension AddSceneViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
        selectedImage = image
        sceneImageView.image = image ?? UIImage(named: "Image")
        var config = addImageButton.configuration
        config?.title = "Change Image"
        addImageButton.configuration = config
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
extension AddSceneViewController: UITextViewDelegate {
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
