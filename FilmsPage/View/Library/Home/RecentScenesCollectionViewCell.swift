//
//  RecentScenesCollectionViewCell.swift
//  FilmsPage
//

import UIKit

class RecentScenesCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var recentImageView: UIImageView!
    @IBOutlet weak var recentLabel: UILabel!

    private let gradientLayer = CAGradientLayer()

    override func awakeFromNib() {
        super.awakeFromNib()

        // Image view

        recentImageView.contentMode = .scaleAspectFill
        recentImageView.layer.cornerRadius = 16
        recentImageView.clipsToBounds = true

        // Cell border
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = true
        contentView.layer.borderWidth = 0.7
        contentView.layer.borderColor = UIColor.gray.cgColor

        // Label
        recentLabel.textColor = .white

        // Gradient — must be called here
        setupGradient()

        // Bring label above gradient
        contentView.bringSubviewToFront(recentLabel)
    }
    
    func configure(with item: ScenesModel) {
        recentImageView.setFilmImage(named: item.image ?? "Image")
        recentLabel.text = item.name
    }

    private func setupGradient() {
        gradientLayer.colors = [
            UIColor.black.withAlphaComponent(0.75).cgColor,
            UIColor.clear.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 1.0)  // bottom
        gradientLayer.endPoint   = CGPoint(x: 0.5, y: 0.5)  // mid
        gradientLayer.locations  = [0.0, 1.0]

        // Add to contentView (not imageView) so it sits above the image
        // but the label can still be brought to front of contentView
        contentView.layer.addSublayer(gradientLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Match gradient to full cell size every layout pass
        gradientLayer.frame = contentView.bounds
    }
}
