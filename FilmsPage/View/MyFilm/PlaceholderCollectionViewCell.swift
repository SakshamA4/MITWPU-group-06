//
//  PlaceholderCollectionViewCell.swift
//  FilmsPage
//
//  Created by SDC-USER on 09/12/25.
//

import UIKit

class PlaceholderCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var bgView: UIView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        bgView.layer.cornerRadius = 20
        bgView.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        // Initialization code

    }

}
