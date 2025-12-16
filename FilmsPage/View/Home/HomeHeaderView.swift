//
//  HomeHeaderView.swift
//  FilmsPage
//
//  Created by SDC-USER on 08/12/25.
//

import UIKit

class HomeHeaderView: UICollectionReusableView {
    
    @IBOutlet weak var titleLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        titleLabel.textColor = .white
                titleLabel.font = UIFont.systemFont(ofSize: 34, weight: .bold)
    }
    
}
