//
// ItemCardCell.swift
// FilmsPage
//
// Created by [Your Name]
//

import UIKit

class ItemCardCell: UICollectionViewCell {
    
    static let reuseID = "ItemCardCell"
    
    // Public property to configure the cell
    var itemName: String? {
        didSet {
                    titleLabel.text = itemName
                    
                    // --- NEW: Load the actual image asset ---
                    if let name = itemName {
                        // Assuming your asset names match the item names (e.g., "Man in a Suit")
                        imageView.image = UIImage(named: name)
                        
                        // Remove the placeholder background color
                        imageView.backgroundColor = .clear
                    }
                }
    }
    
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 10  //changed from 8->10
        iv.translatesAutoresizingMaskIntoConstraints = false
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
        // Set the card container appearance
        contentView.backgroundColor = UIColor.white.withAlphaComponent(0.1) // Lightly visible card
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true
        
        contentView.addSubview(imageView)
        contentView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            // Image View (Takes up most of the space)
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            
            // Title Label (Pinned to the bottom)
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            titleLabel.heightAnchor.constraint(equalToConstant: 20) // Fixed height for title
        ])
    }
    
    // Override the default selection visual
    override var isSelected: Bool {
        didSet {
            contentView.layer.borderWidth = isSelected ? 3 : 0
            contentView.layer.borderColor = isSelected ? UIColor.systemRed.cgColor : nil
        }
    }
}
