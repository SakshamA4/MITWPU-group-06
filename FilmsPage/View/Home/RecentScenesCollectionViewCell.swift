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
                
                recentLabel.textColor = .white
                recentLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
                recentLabel.backgroundColor = UIColor.black.withAlphaComponent(0.45)
                recentLabel.layer.cornerRadius = 4
                recentLabel.clipsToBounds = true

    }

}
