// ExportVC.swift

import UIKit

class ExportVC: UIViewController {
    
    // Closure to pass back the selected format and quality
    // We update the closure to pass both format and quality.
    var onExportSelected: ((String, String) -> Void)? // Changed name for clarity
    
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

    // UISegmentedControl for Quality
    private lazy var qualitySegmentedControl: UISegmentedControl = {
        let items = ["High", "Good"]
        let control = UISegmentedControl(items: items)
        control.selectedSegmentIndex = 0 // Default to High
        control.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        // Use tintColor for selected background color on older iOS, or appearance proxy
        control.selectedSegmentTintColor = .systemGray
        control.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        control.setTitleTextAttributes([.foregroundColor: UIColor.black], for: .selected)
        control.translatesAutoresizingMaskIntoConstraints = false
        control.addTarget(self, action: #selector(didChangeQualitySegment), for: .valueChanged)
        return control
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
        view.backgroundColor = UIColor(red: 14/255, green: 14/255, blue: 24/255, alpha: 1.0)
        setupHeader()
        setupFormatSelection()
        setupQualitySelection()
        
        // Initial setup for visual selection state
        updateFormatButtonAppearance(selectedFormat)
        
        // Quality Segment is set via its selectedSegmentIndex = 0 in the lazy var
        // No need for updateQualityButtonAppearance anymore
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
        
        // Ensure "PDF" is available for the next step
        let formats = ["JPEG", "PNG", "PDF", "MP4"]
        
        for format in formats {
            let button = createSelectionButton(title: format, action: #selector(didTapFormatButton(_:)))
            formatStackView.addArrangedSubview(button)
        }
        
        view.addSubview(formatLabel)
        view.addSubview(formatContainer)

        NSLayoutConstraint.activate([
            formatLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            formatLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 80),
            
            formatContainer.leadingAnchor.constraint(equalTo: formatLabel.trailingAnchor, constant: 20),
            formatContainer.centerYAnchor.constraint(equalTo: formatLabel.centerYAnchor),
            formatContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            formatStackView.topAnchor.constraint(equalTo: formatContainer.topAnchor),
            formatStackView.bottomAnchor.constraint(equalTo: formatContainer.bottomAnchor),
            formatStackView.leadingAnchor.constraint(equalTo: formatContainer.leadingAnchor),
            formatStackView.trailingAnchor.constraint(equalTo: formatContainer.trailingAnchor)
        ])
    }
    
    // CLEANED UP: Only uses the qualitySegmentedControl
    private func setupQualitySelection() {
        let qualityLabel = createSubtitleLabel(text: "Quality:")
        
        view.addSubview(qualityLabel)
        view.addSubview(qualitySegmentedControl) // Use the new segmented control

        NSLayoutConstraint.activate([
            qualityLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            qualityLabel.topAnchor.constraint(equalTo: formatStackView.bottomAnchor, constant: 40),
            
            qualitySegmentedControl.leadingAnchor.constraint(equalTo: qualityLabel.trailingAnchor, constant: 20),
            qualitySegmentedControl.centerYAnchor.constraint(equalTo: qualityLabel.centerYAnchor),
            qualitySegmentedControl.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.45)
        ])
    }

    // MARK: - UI Helper Functions (Unchanged)
    
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
        button.backgroundColor = UIColor(white: 0.3, alpha: 1.0)
        button.layer.cornerRadius = 6
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityIdentifier = title
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
        
        // Show/Hide Quality segmented control based on format type
        let isImageFormat = (title == "JPEG" || title == "PNG")
        qualitySegmentedControl.isHidden = !isImageFormat // Check against the new segmented control
    }
    
    @objc private func didChangeQualitySegment(_ sender: UISegmentedControl) {
        // Get the title of the selected segment
        let selectedTitle = sender.titleForSegment(at: sender.selectedSegmentIndex) ?? "High"
        selectedQuality = selectedTitle
    }
    
    @objc private func didTapFinalExport() {
        // Pass both the selected format and quality back via the closure
        onExportSelected?(selectedFormat, selectedQuality)
        // We will let MyFeatureCanvasVC handle the dismissal after processing the export
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
    
    // REMOVED: updateQualityButtonAppearance is no longer needed since UISegmentedControl handles its own appearance
}
