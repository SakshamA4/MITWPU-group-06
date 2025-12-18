//
//  RecentScenesCollectionViewCell.swift
//  FilmsPage
//
//  Created by SDC-USER on 28/11/25.
//

import UIKit

class RecentScenesCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var recentImageView: UIImageView!
    
    @IBOutlet weak var recentLabel: UILabel!
    
    private let gradientLayer = CAGradientLayer()

    override func awakeFromNib() {
        super.awakeFromNib()
        recentImageView.contentMode = .scaleAspectFill
                recentImageView.layer.cornerRadius = 16
                recentImageView.clipsToBounds = true
        contentView.layer.cornerRadius = 16
        contentView.layer.borderWidth = 0.7
        contentView.layer.borderColor = UIColor.gray.cgColor
        
                
                recentLabel.textColor = .white
                recentLabel.clipsToBounds = true

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

        recentImageView.layer.addSublayer(gradientLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = recentImageView.bounds
    }
}
