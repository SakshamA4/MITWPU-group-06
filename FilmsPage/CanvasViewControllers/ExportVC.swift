// ExportVC.swift

import UIKit

class ExportVC: UIViewController {
    
    // Closure to pass back the selected format (e.g., "JPEG", "PNG")
    var onFormatSelected: ((String) -> Void)?
    
    private var selectedFormat: String = "JPEG" // Default selection
    private var selectedQuality: String = "High" // Default selection

    // MARK: - UI Components
    
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
        stack.spacing = 8
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
    
    private lazy var exportButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Export", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 169/255, green: 32/255, blue: 62/255, alpha: 1.0)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(didTapFinalExport), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Lifecycle & Setup
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Use a semi-transparent dark background for the modal effect
        view.backgroundColor = UIColor(red: 14/255, green: 14/255, blue: 24/255, alpha: 1.0)
        setupHeader()
        setupFormatSelection()
        setupQualitySelection()
        
        // Initial button state setup
        updateFormatButtonAppearance(selectedFormat)
        updateQualityButtonAppearance(selectedQuality)
    }

    private func setupHeader() {
        view.addSubview(headerLabel)
        view.addSubview(exportButton)
        
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
            closeButton.centerYAnchor.constraint(equalTo: headerLabel.centerYAnchor),

            exportButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            exportButton.centerYAnchor.constraint(equalTo: headerLabel.centerYAnchor),
            exportButton.widthAnchor.constraint(equalToConstant: 80),
            exportButton.heightAnchor.constraint(equalToConstant: 30)
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
            formatLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 80), // Position below header
            
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
        
        // This is a toggle-like selection, not fillEqually
        let qualities = ["High", "Good"]
        
        for quality in qualities {
            let button = createSelectionButton(title: quality, action: #selector(didTapQualityButton(_:)))
            qualityStackView.addArrangedSubview(button)
        }
        
        view.addSubview(qualityLabel)
        view.addSubview(qualityContainer)

        NSLayoutConstraint.activate([
            qualityLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
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
        button.backgroundColor = UIColor(white: 0.3, alpha: 1.0) // Unselected gray
        button.layer.cornerRadius = 6
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityIdentifier = title // Use identifier to know which button was tapped
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    // MARK: - Action Handlers & Appearance
    
    @objc private func didTapClose() {
        dismiss(animated: true)
    }
    
    @objc private func didTapFormatButton(_ sender: UIButton) {
        guard let title = sender.accessibilityIdentifier else { return }
        selectedFormat = title
        updateFormatButtonAppearance(title)
        
        // Hide/Show Quality options if not PNG/JPEG (not fully implemented yet, but good practice)
        let isImageFormat = (title == "JPEG" || title == "PNG")
        qualityStackView.isHidden = !isImageFormat
        
        // NOTE: Layout and Select buttons are omitted for simplicity in this first pass.
    }
    
    @objc private func didTapQualityButton(_ sender: UIButton) {
        guard let title = sender.accessibilityIdentifier else { return }
        selectedQuality = title
        updateQualityButtonAppearance(title)
    }

    @objc private func didTapFinalExport() {
        // 🚨 Final step: Call the closure with the selected format
        onFormatSelected?(selectedFormat)
        // Dismissal happens in MyFeatureCanvasVC's completion handler
    }

    private func updateFormatButtonAppearance(_ selectedTitle: String) {
        for view in formatStackView.arrangedSubviews {
            if let button = view as? UIButton {
                let isSelected = (button.accessibilityIdentifier == selectedTitle)
                button.backgroundColor = isSelected ? .systemBlue : UIColor(white: 0.3, alpha: 1.0)
                button.setTitleColor(isSelected ? .white : .lightGray, for: .normal)
            }
        }
    }
    
    private func updateQualityButtonAppearance(_ selectedTitle: String) {
        for view in qualityStackView.arrangedSubviews {
            if let button = view as? UIButton {
                let isSelected = (button.accessibilityIdentifier == selectedTitle)
                button.backgroundColor = isSelected ? .systemGray : UIColor(white: 0.3, alpha: 1.0)
                button.setTitleColor(isSelected ? .white : .lightGray, for: .normal)
            }
        }
    }
}
