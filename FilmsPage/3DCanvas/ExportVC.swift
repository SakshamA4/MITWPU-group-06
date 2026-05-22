import UIKit

class ExportVC: UIViewController {

    // Closure to pass back the selected format (e.g., "JPEG", "PNG")
    var onFormatSelected: ((String) -> Void)?
    var projectName: String = "Untitled Scene"

    private var selectedFormat: String = "JPEG"
    private var selectedQuality: String = "High"

    // MARK: - UI Components
    private lazy var projectTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "PROJECT: \(projectName.uppercased())"
        label.font = UIFont.systemFont(ofSize: 12, weight: .black)
        label.textColor = .lightGray
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var formatStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var qualityStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var headerLabel: UILabel = {
        let label = UILabel()
        label.text = "Export Options"
        label.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Lifecycle & Setup

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 11/255, green: 11/255, blue: 22/255, alpha: 1.0)

        setupHeader()
        setupFormatSelection()
        setupQualitySelection()

        updateFormatButtonAppearance(selectedFormat)
        updateQualityButtonAppearance(selectedQuality)
    }

    private func setupHeader() {
        view.addSubview(headerLabel)
        view.addSubview(projectTitleLabel)
        view.addSubview(formatStackView)

        // Add a close button (top left corner)
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
        view.addSubview(closeButton)

        NSLayoutConstraint.activate([
            headerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            headerLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),

            projectTitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            projectTitleLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 4),

            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            closeButton.centerYAnchor.constraint(equalTo: headerLabel.centerYAnchor)
        ])
    }

    private func setupFormatSelection() {
        let formatLabel = createSubtitleLabel(text: "Format:")
        let formatContainer = UIView()
        formatContainer.translatesAutoresizingMaskIntoConstraints = false
        formatContainer.addSubview(formatStackView)
        formatStackView.distribution = .fill // Change from .fillEqually if it feels too stretched
        formatStackView.spacing = 16
        let formats = ["JPEG", "PNG", "PDF", "MP4"]

        for format in formats {
            let button = createSelectionButton(title: format, action: #selector(didTapFormatButton(_:)))
            formatStackView.addArrangedSubview(button)
        }

        view.addSubview(formatLabel)
        view.addSubview(formatContainer)

        NSLayoutConstraint.activate([
            formatLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            formatLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 60),

            formatContainer.leadingAnchor.constraint(equalTo: formatLabel.trailingAnchor, constant: 12),
            formatContainer.centerYAnchor.constraint(equalTo: formatLabel.centerYAnchor),

            formatStackView.topAnchor.constraint(equalTo: formatContainer.topAnchor),
            formatStackView.bottomAnchor.constraint(equalTo: formatContainer.bottomAnchor),
            formatStackView.leadingAnchor.constraint(equalTo: formatContainer.leadingAnchor),
            formatStackView.trailingAnchor.constraint(equalTo: formatContainer.trailingAnchor)
        ])
    }
    private func setupQualitySelection() {
        let qualityLabel = createSubtitleLabel(text: "Quality:")
        view.addSubview(qualityLabel)
        qualityStackView.distribution = .fill
        qualityStackView.spacing = 16
        view.addSubview(qualityStackView)
        qualityStackView.isUserInteractionEnabled = true
        qualityStackView.axis = .horizontal
        qualityStackView.alignment = .fill
        qualityStackView.distribution = .fill
        qualityStackView.spacing = 16

        let qualities = ["High", "Good"]
        for quality in qualities {
            let button = createSelectionButton(title: quality, action: #selector(didTapQualityButton(_:)))
            button.accessibilityIdentifier = quality
            qualityStackView.addArrangedSubview(button)
        }

        // 2. 📍 Ensure we have the top row buttons to match sizes
        guard let jpegBtn = formatStackView.arrangedSubviews.first as? UIButton,
              let pngBtn = formatStackView.arrangedSubviews.count > 1 ? formatStackView.arrangedSubviews[1] as? UIButton : nil
        else { return }

        NSLayoutConstraint.activate([
            qualityLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            qualityLabel.topAnchor.constraint(equalTo: formatStackView.bottomAnchor, constant: 40),

            // 3. 📍 Anchor the stack directly to the top row's leading edge
            qualityStackView.leadingAnchor.constraint(equalTo: formatStackView.leadingAnchor),
            qualityStackView.centerYAnchor.constraint(equalTo: qualityLabel.centerYAnchor),

            // 4. 📍 Match High to JPEG and Good to PNG
            (qualityStackView.arrangedSubviews[0]).widthAnchor.constraint(equalTo: jpegBtn.widthAnchor),
            (qualityStackView.arrangedSubviews[1]).widthAnchor.constraint(equalTo: pngBtn.widthAnchor),

            // 5. 📍 Match the height of the format stack
            qualityStackView.heightAnchor.constraint(equalTo: formatStackView.heightAnchor)
        ])
    }

    // MARK: - UI Helper Functions

    private func createSubtitleLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        label.textColor = .lightGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func createSelectionButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(white: 0.1, alpha: 0.5)
        button.layer.cornerRadius = 6
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityIdentifier = title
        button.widthAnchor.constraint(equalToConstant: 90).isActive = true
        button.heightAnchor.constraint(equalToConstant: 40).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    // MARK: - Action Handlers

    @objc private func didTapClose() {
        dismiss(animated: true)
    }

    @objc private func didTapFormatButton(_ sender: UIButton) {
        guard let title = sender.accessibilityIdentifier else { return }
        selectedFormat = title
        updateFormatButtonAppearance(title)

        onFormatSelected?(selectedFormat)
    }

    @objc private func didTapQualityButton(_ sender: UIButton) {
        print("Button tapped with ID: \(sender.accessibilityIdentifier ?? "NIL")")

        guard let title = sender.accessibilityIdentifier else { return }
        selectedQuality = title
        updateQualityButtonAppearance(title)
    }

    private func updateFormatButtonAppearance(_ selectedTitle: String) {
        let appRed = UIColor(red: 177/255, green: 32/255, blue: 57/255, alpha: 1.0)

        formatStackView.arrangedSubviews.compactMap { $0 as? UIButton }.forEach { btn in
            let isSelected = btn.accessibilityIdentifier == selectedTitle

            btn.backgroundColor = isSelected ? appRed : UIColor.white.withAlphaComponent(0.05)
            btn.layer.borderWidth = isSelected ? 0 : 1
            btn.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor

            // Ensure text is white when selected for contrast
            btn.setTitleColor(isSelected ? .white : .lightGray, for: .normal)
        }
    }

    private func updateQualityButtonAppearance(_ selectedTitle: String) {
        let appRed = UIColor(red: 169/255, green: 32/255, blue: 57/255, alpha: 1.0)

        qualityStackView.arrangedSubviews.compactMap { $0 as? UIButton }.forEach { btn in
            let isSelected = btn.accessibilityIdentifier == selectedTitle

            if isSelected { print("📍 UI Success: Selected \(selectedTitle)") }

            btn.layer.borderWidth = isSelected ? 0 : 1
            btn.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor
            btn.backgroundColor = isSelected ? appRed : UIColor.white.withAlphaComponent(0.05)

            btn.setTitleColor(isSelected ? .white : .lightGray, for: .normal)
        }
    }
}
