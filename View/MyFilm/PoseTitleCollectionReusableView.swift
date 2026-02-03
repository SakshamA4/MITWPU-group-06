//
//  PoseTitleCollectionReusableView.swift
//  FilmsPage
//
//  Created by SDC-USER on 17/12/25.
//

import UIKit

class PoseTitleCollectionReusableView: UICollectionReusableView {

    @IBOutlet weak var HeaderLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    func configureCell() {
        HeaderLabel.text = "Character Poses"
    }
    
}
