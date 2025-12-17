//
//  LibraryPropsCollectionViewCell.swift
//  FilmsPage
//
//  Created by SDC-USER on 10/12/25.
//

import UIKit

class LibraryPropsCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var libraryPropLabel: UILabel!
    @IBOutlet weak var libraryPropImage: UIImageView!
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupCellAppearance()
        // Initialization code
    }
    func configure(with item: PropItem) {
        libraryPropLabel.text = item.name
        libraryPropImage.image = UIImage(named: item.imageName)
//        featuredImageView.layer.cornerRadius = 12.0
//        featuredImageView.clipsToBounds = true
// DispatchQueue.main.async { [weak self] in
//             guard let self = self else { return }
//             self.libraryPropLabel?.text = item.name
//             self.libraryPropImage?.image = UIImage(named: item.imageName)
//         }
        }

}

private extension LibraryPropsCollectionViewCell {
    
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
        libraryPropImage.clipsToBounds = true
            
            // Label style
            //featuredLabel.textColor = .white
        libraryPropLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
            
        }


}
