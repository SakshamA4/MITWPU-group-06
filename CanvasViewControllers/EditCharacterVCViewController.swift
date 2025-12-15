//
// EditCharacterVC.swift
// FilmsPage
//
// Created by [Your Name]
//

import UIKit

protocol EditCharacterDelegate: AnyObject {
    func didConfirmCharacter(name: String)
}


class EditCharacterVC: UIViewController,  UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    var selectedCharacterName: String?
    weak var delegate: EditCharacterDelegate?
    // MARK: - Header Components
    
    private let headerBar: UIView = {
        let h = UIView()
        h.backgroundColor = UIColor(red: 14/255, green: 14/255, blue: 24/255, alpha: 1.0) // Dark Cinder color
        h.translatesAutoresizingMaskIntoConstraints = false
        return h
    }()
    
    
    
    
    
    // MARK: - Left Side Components
        
        private let selectedCharacterCard: UIView = {
            let view = UIView()
            view.backgroundColor = UIColor.white.withAlphaComponent(0.1)
            view.layer.cornerRadius = 12
            view.clipsToBounds = true
            view.layer.borderWidth = 2 // Red border for selected state as per design
            view.layer.borderColor = UIColor.systemRed.cgColor
            view.translatesAutoresizingMaskIntoConstraints = false
            return view
        }()
        
        private let characterPreview: UIImageView = {
            let iv = UIImageView()
            iv.contentMode = .scaleAspectFill
            iv.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
            iv.translatesAutoresizingMaskIntoConstraints = false
            return iv
        }()
        
        private let selectedNameLabel: UILabel = {
            let label = UILabel()
            label.textColor = .white
            label.textAlignment = .center
            label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }()
        
        // MARK: - Customization Controls
        private let controlsStackView: UIStackView = {
            let stack = UIStackView()
            stack.axis = .vertical
            stack.spacing = 16
            stack.translatesAutoresizingMaskIntoConstraints = false
            return stack
        }()
        
    private func createColorPicker(title: String) -> UIView {
            let row = UIStackView()
            row.axis = .horizontal
            row.alignment = .center
            row.spacing = 16 // Spacing between the title and the color group
            
            // --- FIX: Limit the width of the color picker row (already present, keep it) ---
            row.widthAnchor.constraint(equalToConstant: 250).isActive = true
            
            let titleLabel = UILabel()
            titleLabel.text = title
            titleLabel.textColor = .white
            titleLabel.widthAnchor.constraint(equalToConstant: 80).isActive = true
            
            // --- NEW: Group the Swatch and Rainbow Icon TIGHTLY ---
            let colorControlGroup = UIStackView()
            colorControlGroup.axis = .horizontal
            colorControlGroup.alignment = .center
            colorControlGroup.spacing = 8 // Tiny space between Swatch and Icon
            
            let colorSwatch = UIView()
            colorSwatch.backgroundColor = .white
            colorSwatch.layer.cornerRadius = 4
            colorSwatch.widthAnchor.constraint(equalToConstant: 16).isActive = true
            colorSwatch.heightAnchor.constraint(equalToConstant: 16).isActive = true
            colorSwatch.layer.borderWidth = 1
            colorSwatch.layer.borderColor = UIColor.systemGray.cgColor // Added slight border for definition
            
        
        
            // Stylized Rainbow Icon (representing the palette button)
        let colorWheel = ColorWheelView() // Use the custom radial gradient view
            colorWheel.widthAnchor.constraint(equalToConstant: 20).isActive = true
            colorWheel.heightAnchor.constraint(equalToConstant: 20).isActive = true

            colorControlGroup.addArrangedSubview(colorSwatch)
            colorControlGroup.addArrangedSubview(colorWheel)
            
            // --- Final Assembly ---
            row.addArrangedSubview(titleLabel)
            row.addArrangedSubview(colorControlGroup) // Add the tight grouping
            
            // Add a flexible spacer to push the controls to the left (Optional, but ensures control group stays together)
            let spacer = UIView()
            row.addArrangedSubview(spacer)

            return row
        }
        
    private func createHeightSlider() -> UIView {
            let row = UIStackView()
            row.axis = .horizontal
            row.alignment = .center
            row.spacing = 8
            
            // --- FIX: Limit the width of the height slider row ---
            row.widthAnchor.constraint(equalToConstant: 250).isActive = true
            
            let titleLabel = UILabel()
            titleLabel.text = "Height:"
            titleLabel.textColor = .white
            titleLabel.widthAnchor.constraint(equalToConstant: 80).isActive = true
            
            let slider = UISlider()
            slider.minimumValue = 150
            slider.maximumValue = 200
            slider.value = 175
            // FIX: Explicitly constrain the slider width to prevent it from stretching fully
            slider.widthAnchor.constraint(equalToConstant: 120).isActive = true
            
            let cmsLabel = UILabel()
            cmsLabel.text = "cms"
            cmsLabel.textColor = .white
            
            row.addArrangedSubview(titleLabel)
            row.addArrangedSubview(slider)
            row.addArrangedSubview(cmsLabel)
            
            // Add a flexible spacer to push the controls to the left
            let spacer = UIView()
            row.addArrangedSubview(spacer)

            return row
        }
    
    // MARK: - Pose Grid Components (Right Side)
        private let poseTitleLabel: UILabel = {
            let label = UILabel()
            label.text = "Character Poses"
            label.textColor = .white
            label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }()
        
        private lazy var poseCollectionView: UICollectionView = {
            let layout = UICollectionViewFlowLayout()
            layout.scrollDirection = .vertical
            layout.minimumLineSpacing = 16
            layout.minimumInteritemSpacing = 16
            
            let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
            cv.backgroundColor = .clear
            cv.translatesAutoresizingMaskIntoConstraints = false
            cv.register(PoseCardCell.self, forCellWithReuseIdentifier: PoseCardCell.reuseID) // Register custom cell
            cv.dataSource = self
            cv.delegate = self
            return cv
        }()
        
    
    
    
        // Data source for the poses
    private let poses: [String] = ["fighting pose", "Talking Woman", "Sitting Woman", "Falling", "Sleeping", "Buffering"]
    
    
    
    
    
    
    
    
    private let titleLabel: UILabel = {
        let l = UILabel()
        l.textAlignment = .center
        l.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        l.textColor = .white
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = "Edit Character"
        return l
    }()
    
    // Glass effect button container for the Close button
    private let closeButtonContainer: UIVisualEffectView = {
        let blurEffect = UIBlurEffect(style: .systemThinMaterialDark)
        let view = UIVisualEffectView(effect: blurEffect)
        view.layer.cornerRadius = 20 // Half of 40 for a circle
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let closeButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("✕", for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .regular)
        b.tintColor = .white
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    
    // Deep Carmine Confirm Button
    private let confirmButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("✓", for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        // Deep Carmine: #A9203E
        b.backgroundColor = UIColor(red: 169/255, green: 32/255, blue: 62/255, alpha: 1.0)
        b.layer.cornerRadius = 20
        b.clipsToBounds = true
        b.tintColor = .white
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 14/255, green: 14/255, blue: 24/255, alpha: 1.0) // Cinder Background
        setupViews()
        setupConstraints()
        
        // Update the title and name label
        selectedNameLabel.text = selectedCharacterName ?? "Unknown Character"
        
        if let characterName = selectedCharacterName,
               let image = UIImage(named: characterName) {
                
                // This will load "Woman 1" or "Man in a suit" into the large preview card
                characterPreview.image = image
                
            } else {
                // Fallback for debugging, will show the default light gray background
                print("Error: Could not find image asset for selected character: \(selectedCharacterName ?? "nil")")
            }
    }
    
    private func setupViews() {
        view.addSubview(headerBar)
        headerBar.addSubview(titleLabel)
        headerBar.addSubview(closeButtonContainer)
        closeButtonContainer.contentView.addSubview(closeButton)
        headerBar.addSubview(confirmButton)
        
        // --- Add Pose Grid Components ---
                view.addSubview(poseTitleLabel)
                view.addSubview(poseCollectionView)
        
        // --- Add Pose Grid Components (Right Side) ---
                view.addSubview(poseTitleLabel)
                view.addSubview(poseCollectionView)
                
                // --- Add Selected Character Card (Left Side) ---
                view.addSubview(selectedCharacterCard)
                selectedCharacterCard.addSubview(characterPreview)
                selectedCharacterCard.addSubview(selectedNameLabel)
                
                // --- Add Controls ---
                view.addSubview(controlsStackView)
                controlsStackView.addArrangedSubview(createColorPicker(title: "Shirt Color:"))
                controlsStackView.addArrangedSubview(createColorPicker(title: "Pant Color:"))
                controlsStackView.addArrangedSubview(createHeightSlider())
        
        
        
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
        confirmButton.addTarget(self, action: #selector(didTapConfirm), for: .touchUpInside)
    }

    private func setupConstraints() {
        // Header Bar (fixed to the top of the modal content area)
        NSLayoutConstraint.activate([
            headerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerBar.topAnchor.constraint(equalTo: view.topAnchor),
            headerBar.heightAnchor.constraint(equalToConstant: 64)
        ])
        
        // MARK: - Right Side (Pose Grid)
                let padding: CGFloat = 32
                
                NSLayoutConstraint.activate([
                    // Pose Title
                    poseTitleLabel.topAnchor.constraint(equalTo: headerBar.bottomAnchor, constant: padding),
                    poseTitleLabel.leadingAnchor.constraint(equalTo: view.centerXAnchor, constant: 16), // Starts right of the center
                    
                    // Pose Collection View (Fills the right half)
                    poseCollectionView.topAnchor.constraint(equalTo: poseTitleLabel.bottomAnchor, constant: 16),
                    poseCollectionView.leadingAnchor.constraint(equalTo: view.centerXAnchor, constant: 16),
                    poseCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -padding),
                    poseCollectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -padding)
                ])
        
        // MARK: - Left Side (Selected Character & Controls)
                let cardWidth: CGFloat = 200
                let leftRightMargin: CGFloat = 32
                
                NSLayoutConstraint.activate([
                    // Selected Character Card
                    selectedCharacterCard.topAnchor.constraint(equalTo: headerBar.bottomAnchor, constant: leftRightMargin),
                    selectedCharacterCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: leftRightMargin),
                    selectedCharacterCard.widthAnchor.constraint(equalToConstant: cardWidth),
                    selectedCharacterCard.heightAnchor.constraint(equalToConstant: 250),
                    
                    // Character Preview Image
                    characterPreview.topAnchor.constraint(equalTo: selectedCharacterCard.topAnchor, constant: 8),
                    characterPreview.leadingAnchor.constraint(equalTo: selectedCharacterCard.leadingAnchor, constant: 8),
                    characterPreview.trailingAnchor.constraint(equalTo: selectedCharacterCard.trailingAnchor, constant: -8),
                    
                    // Selected Name Label
                    selectedNameLabel.topAnchor.constraint(equalTo: characterPreview.bottomAnchor, constant: 4),
                    selectedNameLabel.leadingAnchor.constraint(equalTo: selectedCharacterCard.leadingAnchor, constant: 4),
                    selectedNameLabel.trailingAnchor.constraint(equalTo: selectedCharacterCard.trailingAnchor, constant: -4),
                    selectedNameLabel.bottomAnchor.constraint(equalTo: selectedCharacterCard.bottomAnchor, constant: -8),
                    selectedNameLabel.heightAnchor.constraint(equalToConstant: 20),
                    
                    // Customization Controls Stack
                    controlsStackView.topAnchor.constraint(equalTo: selectedCharacterCard.bottomAnchor, constant: leftRightMargin),
                    controlsStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: leftRightMargin),
                    controlsStackView.trailingAnchor.constraint(equalTo: view.centerXAnchor, constant: -16)
                ])
        
        
        
        
        // Title Label (centered)
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: headerBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor)
        ])
        
        // Close Button (Blur Effect container on the left)
        NSLayoutConstraint.activate([
            closeButtonContainer.leadingAnchor.constraint(equalTo: headerBar.leadingAnchor, constant: 16),
            closeButtonContainer.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor),
            closeButtonContainer.widthAnchor.constraint(equalToConstant: 40),
            closeButtonContainer.heightAnchor.constraint(equalToConstant: 40),
            closeButton.centerXAnchor.constraint(equalTo: closeButtonContainer.centerXAnchor),
            closeButton.centerYAnchor.constraint(equalTo: closeButtonContainer.centerYAnchor)
        ])
        
        // Confirm Button (Deep Carmine on the right)
        NSLayoutConstraint.activate([
            confirmButton.trailingAnchor.constraint(equalTo: headerBar.trailingAnchor, constant: -16),
            confirmButton.centerYAnchor.constraint(equalTo: headerBar.centerYAnchor),
            confirmButton.widthAnchor.constraint(equalToConstant: 40),
            confirmButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    // MARK: - Actions
    @objc private func didTapClose() {
        dismiss(animated: true)
    }

    @objc private func didTapConfirm() {
            if let characterName = selectedCharacterName {
                // Tell the presenting VC (Canvas) to add the item
                delegate?.didConfirmCharacter(name: characterName)
            }
            // Dismiss the Edit modal
            dismiss(animated: true)
        }
    
}

// MARK: - UICollectionViewDataSource & Delegate (Poses)
extension EditCharacterVC{
    
    // 1. REQUIRED: Number of items
        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            return poses.count
        }
    
    // 2. Cell for item
        func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PoseCardCell.reuseID, for: indexPath) as? PoseCardCell else {
                return UICollectionViewCell()
            }
            
            // Pass the pose name directly
            let poseKey = poses[indexPath.row]
            
            // Pass the pose name and the base character name
            cell.poseName = poseKey
            
            
            return cell
        }
   
    
    // Define the size for a 3-column grid layout (for poses)
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        // Calculate the available width for the grid area
        let availableWidth = collectionView.bounds.width
        
        // 3 items with 2 spaces (16 each)
        let interItemSpacing: CGFloat = 16 * 2
        let width = (availableWidth - interItemSpacing) / 3
        
        // Height to maintain aspect ratio for the card appearance
        let height: CGFloat = 1.3 * width
        
        return CGSize(width: width, height: height)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Handle pose selection here (e.g., store the selected pose)
        print("Pose selected: \(poses[indexPath.row])")
    }
}
