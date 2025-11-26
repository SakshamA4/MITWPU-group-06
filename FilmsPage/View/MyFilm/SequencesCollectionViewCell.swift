//
//  ScenesCollectionViewCell.swift
//  FilmsPage
//
//  Created by SDC-USER on 26/11/25.
//

import UIKit

class SequencesCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        contentView.layer.cornerRadius = 20
        contentView.layer.masksToBounds = true

        // Round the imageView
        imageView.layer.cornerRadius = 20
        imageView.layer.masksToBounds = true
        // Initialization code
    }
   
    
    func configureCell(sequences: Sequence) {
        if let imageName = sequences.image.first {
            imageView.image = UIImage(named: imageName)
        } else {
            imageView.image = nil // or set a placeholder: UIImage(named: "placeholder")
        }
        titleLabel.text = sequences.name.capitalized
    }


}
