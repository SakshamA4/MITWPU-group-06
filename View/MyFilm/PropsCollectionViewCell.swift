//
//  PropsCollectionViewCell.swift
//  FilmsPage
//
//  Created by SDC-USER on 26/11/25.
//

import UIKit

class PropsCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var imageView: UIImageView!
    
    @IBOutlet weak var titleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        contentView.layer.cornerRadius = 20
        contentView.layer.masksToBounds = true
        
        contentView.layer.borderWidth = 0.7
        contentView.layer.borderColor = UIColor.gray.cgColor

        // Round the imageView
        imageView.layer.cornerRadius = 20
        imageView.layer.masksToBounds = true
        imageView.layer.maskedCorners = [
            .layerMinXMinYCorner,
            .layerMaxXMinYCorner
        ]

        // Initialization code
    }
   
    
    func configureCell(prop: PropItem) {
        if !prop.imageName.isEmpty {
            imageView.image = UIImage(named: prop.imageName)
        } else {
            imageView.image = nil // or set a placeholder: UIImage(named: "placeholder")
        }
        titleLabel.text = prop.name.capitalized
    }


}
