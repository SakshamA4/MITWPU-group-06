//
// ItemCardCell.swift
// FilmsPage
//
// Created by [Your Name]
//

import UIKit

class ItemCardCell: UICollectionViewCell {
    
    static let reuseID = "ItemCardCell"
    
    var itemName: String? {
        didSet {
                    titleLabel.text = itemName
                    
                    if let name = itemName {
                        imageView.image = UIImage(named: name)
                        // Removing the placeholder background color
                        imageView.backgroundColor = .clear
                    }
                }
    }
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 12  //changed from 8->10
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 20, weight: .medium)
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
        // Setting the card container appearance
        //contentView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        contentView.backgroundColor = UIColor(
            red: CGFloat(0x14) / 255.0,
            green: CGFloat(0x14) / 255.0,
            blue: CGFloat(0x1E) / 255.0,
            alpha: 1.0
        )
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true
        contentView.layer.borderColor = UIColor.systemGray.cgColor
        contentView.layer.borderWidth = 0.7
        contentView.addSubview(imageView)
        contentView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            
            // Title Label 
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            titleLabel.heightAnchor.constraint(equalToConstant: 20) // Fixed height for title
        ])
    }
    
    
    var isCurrentlySelected: Bool = false {
//        didSet {
//            contentView.layer.borderWidth = isSelected ? 3 : 0
//            contentView.layer.borderColor = isSelected ? UIColor.systemRed.cgColor : nil
//        }
        didSet {
                if isCurrentlySelected {
                    contentView.layer.borderWidth = 3
                    contentView.layer.borderColor = UIColor.systemRed.cgColor
                } else {
                    // Restore the standard look when not selected
                    contentView.layer.borderWidth = 0.7
                    contentView.layer.borderColor = UIColor.systemGray.cgColor
                }
                contentView.layoutIfNeeded() 
            }
    }
}
