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
                
                templateLabel.textColor = .white
                templateLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
                // dark translucent background so text is readable
                templateLabel.backgroundColor = UIColor.black.withAlphaComponent(0.45)
                templateLabel.layer.cornerRadius = 4
                templateLabel.clipsToBounds = true
    }

}
