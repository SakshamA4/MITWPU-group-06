//
//  TemplatesCollectionViewCell.swift
//  FilmsPage
//
//  Created by SDC-USER on 28/11/25.
//

import UIKit

class TemplatesCollectionViewCell: UICollectionViewCell {
    
    private let gradientLayer = CAGradientLayer()

    
    @IBOutlet weak var templatesImageView: UIImageView!
    
    @IBOutlet weak var templateLabel: UILabel!
    
    

    override func awakeFromNib() {
        super.awakeFromNib()

        templatesImageView.contentMode = .scaleAspectFill
        templatesImageView.layer.cornerRadius = 16
        templatesImageView.clipsToBounds = true

        contentView.layer.cornerRadius = 16
        contentView.layer.borderWidth = 0.7
        contentView.layer.borderColor = UIColor.gray.cgColor

        templateLabel.textColor = .white
        templateLabel.clipsToBounds = true

        setupGradient()
    }
    
    
    private func setupGradient() {
        gradientLayer.colors = [
            UIColor.black.withAlphaComponent(0.7).cgColor,
            UIColor.black.withAlphaComponent(0.0).cgColor
        ]

        // Bottom → Top
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 1.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 0.0)

        // Only darken bottom part
        gradientLayer.locations = [0.0, 0.6]

        templatesImageView.layer.addSublayer(gradientLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = templatesImageView.bounds
    }

}
