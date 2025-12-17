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
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        recentImageView.contentMode = .scaleAspectFill
                recentImageView.layer.cornerRadius = 16
                recentImageView.clipsToBounds = true
        contentView.layer.cornerRadius = 16
        contentView.layer.borderColor = UIColor.gray.cgColor
        
                
                recentLabel.textColor = .white
                recentLabel.clipsToBounds = true

    }

}
