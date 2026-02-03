//
//  CharactersPropsLightsBackgroundCollectionViewCell.swift
//  FilmsPage
//
//  Created by SDC-USER on 27/11/25.
//

import UIKit

class CharactersPropsLightsBackgroundCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var assetsImageView: UIImageView!
    
    @IBOutlet weak var assetsLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupCellAppearance()
        // Initialization code
    }
    func configure(with item: LibraryItem) {
        assetsLabel.text = item.title
        assetsImageView.image = UIImage(named: item.imageName)
        assetsImageView.layer.cornerRadius = 12.0
        assetsImageView.clipsToBounds = true
        }

}
private extension CharactersPropsLightsBackgroundCollectionViewCell {
    
    private func setupCellAppearance() {
            // Rounded corners on the whole card
            contentView.layer.cornerRadius = 12
            contentView.layer.masksToBounds = true
            
            // Add border (stroke)
            contentView.layer.borderColor = UIColor(hex: "#D9D9D9").withAlphaComponent(0.3).cgColor
            contentView.layer.borderWidth = 1.0
            
            // Shadow on the cell layer (outside contentView so it’s not clipped)
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.25
            layer.shadowOffset = CGSize(width: 0, height: 6)
            layer.shadowRadius = 8
            layer.masksToBounds = false
            
            // Image setup
            //featuredImageView.contentMode = .scaleAspectFill
            assetsImageView.clipsToBounds = true
            
            // Label style
            //featuredLabel.textColor = .white
            assetsLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
            
        }


}
