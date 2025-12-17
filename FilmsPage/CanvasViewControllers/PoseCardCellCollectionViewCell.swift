//
// PoseCardCell.swift
// FilmsPage
//
// Created by Ritik
//

import UIKit

class PoseCardCell: UICollectionViewCell {
    
    static let reuseID = "PoseCardCell"
    
    var poseName: String? {
            didSet {
                titleLabel.text = poseName
                
                // --- NEW: Simplified Image Loading Logic ---
                if let pose = poseName {
                    let assetName = pose
                    imageView.image = UIImage(named: assetName)
                    imageView.backgroundColor = .clear
                } else {
                    imageView.image = nil
                    imageView.backgroundColor = .systemGray
                }
            }
        }
        
       
    
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
            contentView.layer.borderColor = isSelected ? UIColor.systemGray6.cgColor : nil
        }
    }
}
