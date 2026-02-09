//
//  PlaceholderCollectionViewCell.swift
//  FilmsPage
//
//  Created by SDC-USER on 09/12/25.
//
import UIKit

class PlaceholderCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var bgView: UIView!
    
    @IBOutlet weak var addNew: UILabel!


    var onPlusButtonTapped: (() -> Void)?

        private var dottedBorderLayer: CAShapeLayer?

        override func awakeFromNib() {
            super.awakeFromNib()
            
            bgView.clipsToBounds = false
            contentView.clipsToBounds = false
            layer.masksToBounds = false
            bgView.layer.cornerRadius = 20
            bgView.layer.cornerCurve = .continuous
            bgView.layer.masksToBounds = true
            bgView.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        }


    
    @IBAction func plusButtonTapped(_ sender: UIButton) {
        // 3. Trigger the closure when tapped.
        // The View Controller will decide WHICH segue to open.
        onPlusButtonTapped?()
    }
}
