//
//  StaticshotsCollectionViewCell.swift
//  FilmsPage
//
//  Created by SDC-USER on 10/12/25.
//

import UIKit

class StaticshotsCollectionViewCell: UICollectionViewCell {

    
    @IBOutlet weak var staticShotImage: UIImageView!
    
    @IBOutlet weak var staticShotLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupCellAppearance()
        // Initialization code
    }
    
    //ensures old images/text don’t flash while the collection view scrolls fast
    override func prepareForReuse() {
            super.prepareForReuse()
        staticShotImage.image = nil
        staticShotLabel.text = nil
        }
    
    func configure(with item: CameraLibraryItem) {
        staticShotLabel.text = item.name
        staticShotImage.image = UIImage(named: item.imageName)
        staticShotImage.layer.cornerRadius = 12.0
        staticShotImage.clipsToBounds = true
        }
    
    //Makes it feel more interactive when tapped.
    override var isHighlighted: Bool {
            didSet {
                UIView.animate(withDuration: 0.15) {
                    self.contentView.transform = self.isHighlighted
                        ? CGAffineTransform(scaleX: 0.96, y: 0.96)
                        : .identity
                }
            }
        }

}

private extension StaticshotsCollectionViewCell {
    
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
        staticShotImage.clipsToBounds = true
            
            // Label style
            //featuredLabel.textColor = .white
//        staticShotLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
            
        }


}
