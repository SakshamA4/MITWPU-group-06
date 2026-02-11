//
//  PoseCell.swift
//  3DCanvas
//
//  Created by SDC-USER on 20/01/26.
//

import UIKit

class PoseCell: UICollectionViewCell {
    static let reuseID = "PoseCell"
    
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = UIColor(red: 20/255, green:  20/255, blue: 30/255, alpha: 1)
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let titleLabelContainer: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 20/255, green:  20/255, blue: 30/255, alpha: 1)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    
    private let titleLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        lbl.textColor = .white
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()
    
    private let checkmarkIcon: UIImageView = {
        let iv = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
        iv.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: config)
        iv.tintColor = .systemBlue
        iv.backgroundColor = .white
        iv.layer.cornerRadius = 11
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.isHidden = true
        return iv
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .systemBackground
        contentView.layer.cornerRadius = 12
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = UIColor.systemGray4.cgColor
        contentView.clipsToBounds = true
        
        setupLayout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupLayout() {
        contentView.addSubview(imageView)
        contentView.addSubview(titleLabelContainer)
        titleLabelContainer.addSubview(titleLabel)
        contentView.addSubview(checkmarkIcon)
        
        NSLayoutConstraint.activate([
            // Image takes up most of the card
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: titleLabelContainer.topAnchor),
            
            // Label Container at bottom
            titleLabelContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titleLabelContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            titleLabelContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            titleLabelContainer.heightAnchor.constraint(equalToConstant: 30), // Slightly taller for readability
            
            titleLabel.centerYAnchor.constraint(equalTo: titleLabelContainer.centerYAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: titleLabelContainer.centerXAnchor),
            
            // Checkmark
            checkmarkIcon.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            checkmarkIcon.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            checkmarkIcon.widthAnchor.constraint(equalToConstant: 22),
            checkmarkIcon.heightAnchor.constraint(equalToConstant: 22)
        ])
    }
    
    func configure(image: UIImage?, title: String) {
        imageView.image = image
        titleLabel.text = title
        }
    
    override var isSelected: Bool {
        didSet {
            checkmarkIcon.isHidden = !isSelected
            contentView.layer.borderColor = isSelected ? UIColor.systemBlue.cgColor : UIColor.systemGray2.cgColor
            contentView.layer.borderWidth = isSelected ? 2 : 0.5
        }
    }
}
