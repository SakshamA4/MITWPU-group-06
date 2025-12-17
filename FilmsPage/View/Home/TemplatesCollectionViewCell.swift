//
//  TemplatesCollectionViewCell.swift
//  FilmsPage
//
//  Created by SDC-USER on 28/11/25.
//

import UIKit

class TemplatesCollectionViewCell: UICollectionViewCell {
    
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

                // dark translucent background so text is readable


                templateLabel.clipsToBounds = true
    }

}
