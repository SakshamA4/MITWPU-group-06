import UIKit

class SceneInfoViewController: UIViewController {

    // MARK: - Tracking Properties
    var sceneImage: UIImage?
    var sceneName: String = ""
    var sequenceName: String?
    var filmName: String?
    var lastEditedDate: Date = Date()
    var initialNotes: String = ""

    var onSave: ((String, String) -> Void)?

    // MARK: - UI Components
    private lazy var thumbnailImageView: UIImageView = {
            let iv = UIImageView()
            iv.image = sceneImage ?? UIImage(systemName: "photo.artframe")
            iv.contentMode = .scaleAspectFill
            iv.clipsToBounds = true
            iv.layer.cornerRadius = 16
            iv.layer.borderWidth = 1
            iv.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
            iv.translatesAutoresizingMaskIntoConstraints = false
            return iv
        }()

    private let containerView: UIView = {
        let view = UIView()
        // Premium Dark Theme
        view.backgroundColor = UIColor(red: 18/255, green: 18/255, blue: 28/255, alpha: 1.0)
        view.layer.cornerRadius = 24
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var confirmButton: UIButton = {
            let btn = UIButton(type: .system)
            let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .bold)
            btn.setImage(UIImage(systemName: "checkmark.circle.fill", withConfiguration: config), for: .normal)
            btn.tintColor = UIColor(red: 177/255, green: 32/255, blue: 57/255, alpha: 1)
            btn.translatesAutoresizingMaskIntoConstraints = false
            btn.addTarget(self, action: #selector(didTapSave), for: .touchUpInside)
            return btn
        }()

    // Transparent layer to catch "Cancel" taps outside the card
    private let backgroundTapView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6) // Dim the background
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var sceneNameField: UITextField = {
            let tf = UITextField()
            tf.text = sceneName
            tf.font = .systemFont(ofSize: 28, weight: .black) // Larger, bolder font
            tf.textColor = .white
            tf.translatesAutoresizingMaskIntoConstraints = false
            return tf
        }()

    private lazy var labelsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // Inside SceneInfoViewController.swift

    private lazy var notesTextView: UITextView = {
        let tv = UITextView()
        // 📍 Placeholder logic: If notes are empty, show placeholder
        if initialNotes.isEmpty || initialNotes == "Notes" {
            tv.text = "Notes"
            tv.textColor = .systemGray // Grey for placeholder
        } else {
            tv.text = initialNotes
            tv.textColor = .white // White for real user content
        }

        tv.font = .systemFont(ofSize: 18)
        tv.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        tv.layer.cornerRadius = 15
        tv.textContainerInset = UIEdgeInsets(top: 15, left: 12, bottom: 15, right: 12)
        tv.translatesAutoresizingMaskIntoConstraints = false

        tv.delegate = self
        return tv
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        if let image = sceneImage {
                thumbnailImageView.image = image
            }
        setupLayout()
        configureDataLabels()
        setupCancelGesture()

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissModal))
                backgroundTapView.addGestureRecognizer(tap)
    }

    private func setupCancelGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapOutside))
        backgroundTapView.addGestureRecognizer(tap)
    }

    @objc private func didTapOutside() {
        dismiss(animated: true)
    }

    private func configureDataLabels() {
            if let seq = sequenceName { labelsStack.addArrangedSubview(createLabel(text: "SEQUENCE: \(seq)")) }
            if let film = filmName { labelsStack.addArrangedSubview(createLabel(text: "FILM: \(film)")) }
            let timeStr = lastEditedDate.timeAgoDisplay()
            labelsStack.addArrangedSubview(createLabel(text: "Last Edited: \(timeStr)", color: .systemRed))
        }

    private func createLabel(text: String, color: UIColor = .lightGray) -> UILabel {
            let l = UILabel(); l.text = text.uppercased(); l.font = .systemFont(ofSize: 13, weight: .bold); l.textColor = color; return l
        }

        @objc private func didTapSave() {
            let finalizedNotes = (notesTextView.text == "Notes" && notesTextView.textColor == .systemGray) ? "" : notesTextView.text
            onSave?(sceneNameField.text ?? "", notesTextView.text)
            dismiss(animated: true)
        }

    @objc private func dismissModal() { dismiss(animated: true) }

    private func setupLayout() {
        view.addSubview(backgroundTapView)
                view.addSubview(containerView)
                containerView.addSubview(thumbnailImageView)
                containerView.addSubview(confirmButton)
                containerView.addSubview(sceneNameField)
                containerView.addSubview(labelsStack)
                containerView.addSubview(notesTextView)

                NSLayoutConstraint.activate([
                    backgroundTapView.topAnchor.constraint(equalTo: view.topAnchor),
                    backgroundTapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    backgroundTapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                    backgroundTapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

                    containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                    containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                    containerView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.9),
                    containerView.heightAnchor.constraint(equalToConstant: 600), // 📍 Height increased for better UI

                    thumbnailImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 30),
                    thumbnailImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 30),
                    thumbnailImageView.widthAnchor.constraint(equalToConstant: 140), // 📍 Larger Image
                    thumbnailImageView.heightAnchor.constraint(equalToConstant: 140),

                    confirmButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 25),
                    confirmButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -25),
                    confirmButton.widthAnchor.constraint(equalToConstant: 50),
                    confirmButton.heightAnchor.constraint(equalToConstant: 50),

                    sceneNameField.topAnchor.constraint(equalTo: thumbnailImageView.topAnchor),
                    sceneNameField.leadingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: 20),
                    sceneNameField.trailingAnchor.constraint(equalTo: confirmButton.leadingAnchor, constant: -10),

                    labelsStack.topAnchor.constraint(equalTo: sceneNameField.bottomAnchor, constant: 8),
                    labelsStack.leadingAnchor.constraint(equalTo: sceneNameField.leadingAnchor),

                    notesTextView.topAnchor.constraint(equalTo: thumbnailImageView.bottomAnchor, constant: 35),
                    notesTextView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 30),
                    notesTextView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -30),
                    notesTextView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -30)
                ])
    }
}
extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        // This automatically returns "2 hours ago", "1 day ago", etc.
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
// MARK: - UITextViewDelegate for Notes Placeholder
extension SceneInfoViewController: UITextViewDelegate {

    // Called when the user taps inside the Notes box
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == .systemGray {
            textView.text = nil // Clear "Notes" placeholder
            textView.textColor = .white // Set to normal typing color
        }
    }

    // Called when the user stops typing/leaves the box
    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.text = "Notes"
            textView.textColor = .systemGray // Bring back grey placeholder
        }
    }
}
