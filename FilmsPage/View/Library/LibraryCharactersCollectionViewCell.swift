//
//  LibraryCharactersCollectionViewCell.swift
//  FilmsPage
//
//  Created by SDC-USER on 10/12/25.
//

import UIKit

class LibraryCharactersCollectionViewCell: UICollectionViewCell {

    
    @IBOutlet weak var libraryCharacterLabel: UILabel!
    @IBOutlet weak var libraryCharacterImage: UIImageView!
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupCellAppearance()
        // Initialization code
    }
    func configure(with item: CharacterItem) {
        libraryCharacterLabel.text = item.name
        libraryCharacterImage.image = UIImage(named: item.imageName)
        
        libraryCharacterImage.layer.borderWidth = 0.7
        libraryCharacterImage.layer.borderColor = UIColor.gray.cgColor
        
        libraryCharacterImage.layer.cornerRadius = 12.0
        libraryCharacterImage.layer.masksToBounds = true
        libraryCharacterImage.layer.maskedCorners = [
            .layerMinXMinYCorner,
            .layerMaxXMinYCorner
        ]
//        featuredImageView.layer.cornerRadius = 12.0
//        featuredImageView.clipsToBounds = true
        }

}

private extension LibraryCharactersCollectionViewCell {
    
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
        libraryCharacterImage.clipsToBounds = true
            
            // Label style
            //featuredLabel.textColor = .white
        libraryCharacterLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
            
        }


}
