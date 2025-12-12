//
//  HeaderView.swift
//  FilmsPage
//
//  Created by SDC-USER on 25/11/25.
//

import UIKit

protocol HeaderViewDelegate: AnyObject {
    func didTapHeader(section: Int)
}

class HeaderView: UICollectionReusableView {

    @IBOutlet weak var nextChevron: UIButton!
    
    @IBOutlet weak var headerLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    weak var delegate: HeaderViewDelegate?
    private var sectionIndex: Int = 0
    
    func configureHeader(text: String, section: Int) {
        headerLabel.text = text
        sectionIndex = section
    }

    
    @IBAction func chevronTapped(_ sender: UIButton) {
        delegate?.didTapHeader(section: sectionIndex)
    }
}







