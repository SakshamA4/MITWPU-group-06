//
// PoseCardCell.swift
// FilmsPage
//
// Created by [Your Name]
//

import UIKit

class PoseCardCell: UICollectionViewCell {
    
    static let reuseID = "PoseCardCell"
    
    var poseName: String? {
            didSet {
                titleLabel.text = poseName
                
                // --- NEW: Simplified Image Loading Logic ---
                if let pose = poseName {
                    // 1. Clean the Pose Name (e.g., "Fighting pose" -> "Fightingpose")
                    // We still need to clean spaces for image asset names
                    let assetName = pose.replacingOccurrences(of: " ", with: "")
                    
                    // 2. Load the image using ONLY the cleaned pose name.
                    // NOTE: This assumes an asset named "Fightingpose" exists and is the correct one
                    // for the currently selected character (Woman 1 or Man in a Suit).
                    imageView.image = UIImage(named: assetName)
                    imageView.backgroundColor = .clear
                }
            }
        }
        
        // DELETE the didSet for baseCharacterName and the baseCharacterName property itself
        // if you absolutely do not want to use it for image construction.
        // If you need it for *future* logic, keep it but leave its didSet empty.
        
        // Since you want to keep them separate:
        var baseCharacterName: String? // Keep this property if needed for other logic
    
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        // Placeholder background for the 3D model look
        iv.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
        return iv
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        contentView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true
        
        contentView.addSubview(imageView)
        contentView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            // Image View
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            
            // Title Label
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            titleLabel.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    override var isSelected: Bool {
        didSet {
            contentView.layer.borderWidth = isSelected ? 2 : 0
            contentView.layer.borderColor = isSelected ? UIColor.systemRed.cgColor : nil
        }
    }
}
