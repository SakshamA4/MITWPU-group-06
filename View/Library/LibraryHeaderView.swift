//
//  LibraryHeaderView.swift
//  FilmsPage
//
//  Created by SDC-USER on 10/12/25.
//

import UIKit

class LibraryHeaderView: UICollectionReusableView {

        @IBOutlet weak var libraryHeaderLabel: UILabel!
        
        override func awakeFromNib() {
            super.awakeFromNib()
            // Initialization code
        }
        
        func configureHeader(text: String) {
            libraryHeaderLabel.text = text
        }
    }
