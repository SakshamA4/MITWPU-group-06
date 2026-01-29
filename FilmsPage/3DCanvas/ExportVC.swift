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
            label.text = projectName.uppercased()
            label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
            label.textColor = .systemGray
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }()
    
    private lazy var formatStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var qualityStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var headerLabel: UILabel = {
        let label = UILabel()
        label.text = "Export Options"
        label.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Lifecycle & Setup
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Match the Dark Navy theme of your main project
        view.backgroundColor = UIColor(red: 11/255, green: 11/255, blue: 22/255, alpha: 1.0)
        
        setupHeader()
        setupFormatSelection()
        setupQualitySelection()
        
        updateFormatButtonAppearance(selectedFormat)
        updateQualityButtonAppearance(selectedQuality)
    }

    private func setupHeader() {
        view.addSubview(headerLabel)
        
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
            
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            closeButton.centerYAnchor.constraint(equalTo: headerLabel.centerYAnchor)
        ])
    }
    
    private func setupFormatSelection() {
        let formatLabel = createSubtitleLabel(text: "Format:")
        let formatContainer = UIView()
        formatContainer.translatesAutoresizingMaskIntoConstraints = false
        formatContainer.addSubview(formatStackView)
        
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
            
            formatContainer.leadingAnchor.constraint(equalTo: formatLabel.trailingAnchor, constant: 20),
            formatContainer.centerYAnchor.constraint(equalTo: formatLabel.centerYAnchor),
            formatContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            formatStackView.topAnchor.constraint(equalTo: formatContainer.topAnchor),
            formatStackView.bottomAnchor.constraint(equalTo: formatContainer.bottomAnchor),
            formatStackView.leadingAnchor.constraint(equalTo: formatContainer.leadingAnchor),
            formatStackView.trailingAnchor.constraint(equalTo: formatContainer.trailingAnchor)
        ])
    }
    
    private func setupQualitySelection() {
        let qualityLabel = createSubtitleLabel(text: "Quality:")
        let qualityContainer = UIView()
        qualityContainer.translatesAutoresizingMaskIntoConstraints = false
        qualityContainer.addSubview(qualityStackView)
        
        let qualities = ["High", "Good"]
        
        for quality in qualities {
            let button = createSelectionButton(title: quality, action: #selector(didTapQualityButton(_:)))
            qualityStackView.addArrangedSubview(button)
        }
        
        view.addSubview(qualityLabel)
        view.addSubview(qualityContainer)

        NSLayoutConstraint.activate([
            qualityLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            // 📍 THE FIX: Anchor to the stack view which IS in scope
            qualityLabel.topAnchor.constraint(equalTo: formatStackView.bottomAnchor, constant: 40),
            
            qualityContainer.leadingAnchor.constraint(equalTo: qualityLabel.trailingAnchor, constant: 20),
            qualityContainer.centerYAnchor.constraint(equalTo: qualityLabel.centerYAnchor),
            
            qualityStackView.topAnchor.constraint(equalTo: qualityContainer.topAnchor),
            qualityStackView.bottomAnchor.constraint(equalTo: qualityContainer.bottomAnchor),
            qualityStackView.leadingAnchor.constraint(equalTo: qualityContainer.leadingAnchor),
            qualityStackView.trailingAnchor.constraint(equalTo: qualityContainer.trailingAnchor)
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
        button.setTitleColor(.lightGray, for: .normal)
        button.backgroundColor = UIColor(white: 0.3, alpha: 0.5)
        button.layer.cornerRadius = 6
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityIdentifier = title
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
        
        // ⚡️ IMMEDIATELY TRIGGER EXPORT:
        // Since the button is in the CanvasVC, clicking the format here
        // acts as the final confirmation.
        onFormatSelected?(selectedFormat)
    }
    
    @objc private func didTapQualityButton(_ sender: UIButton) {
        guard let title = sender.accessibilityIdentifier else { return }
        selectedQuality = title
        updateQualityButtonAppearance(title)
    }

    private func updateFormatButtonAppearance(_ selectedTitle: String) {
        for view in formatStackView.arrangedSubviews {
            if let button = view as? UIButton {
                let isSelected = (button.accessibilityIdentifier == selectedTitle)
                button.backgroundColor = isSelected ? .systemBlue : UIColor(white: 0.3, alpha: 0.5)
                button.setTitleColor(isSelected ? .white : .lightGray, for: .normal)
            }
        }
    }
    
    private func updateQualityButtonAppearance(_ selectedTitle: String) {
        for view in qualityStackView.arrangedSubviews {
            if let button = view as? UIButton {
                let isSelected = (button.accessibilityIdentifier == selectedTitle)
                button.backgroundColor = isSelected ? .systemGray : UIColor(white: 0.3, alpha: 0.5)
                button.setTitleColor(isSelected ? .white : .lightGray, for: .normal)
            }
        }
    }
}
