//
//  CharacterPosesCollectionViewCell.swift
//  FilmsPage
//
//  Created by SDC-USER on 11/12/25.
//

import UIKit

class CharacterPosesCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var view: UIView!
    
    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var titleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        contentView.layer.cornerRadius = 20
        contentView.layer.masksToBounds = true

        imageView.layer.cornerRadius = 16
        imageView.layer.masksToBounds = true
        imageView.layer.maskedCorners = [
            .layerMinXMinYCorner,
            .layerMaxXMinYCorner
        ]
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = UIColor.lightGray.cgColor
    }
    
    func configure(with pose: CharacterPoseItem) {
        titleLabel.text = pose.name
        imageView.image = UIImage(named: pose.imageName) // use the image from datastore
    }
}
