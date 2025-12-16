//
//  BackgroundCollectionViewCell.swift
//  FilmsPage
//
//  Created by SDC-USER on 08/12/25.
//

import UIKit

class BackgroundCollectionViewCell: UICollectionViewCell {
    
    static let reuseIdentifier = "BackgroundCollectionViewCell"
    
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    
    private let gradientLayer = CAGradientLayer()
       
       override func awakeFromNib() {
           super.awakeFromNib()
           
           setupUI()
           setupGradient()
       }
       
       override func layoutSubviews() {
           super.layoutSubviews()
           gradientLayer.frame = backgroundImageView.bounds
       }
       
       func configure(with item: BackgroundItem) {
           backgroundImageView.image = UIImage(named: item.imageName)
           titleLabel.text = item.title
       }
   }

   // MARK: - Setup
   private extension BackgroundCollectionViewCell {
       
       func setupUI() {
           contentView.layer.cornerRadius = 12
           contentView.layer.masksToBounds = true
           contentView.backgroundColor = UIColor(hex: "#1A1A1A")
           
           backgroundImageView.contentMode = .scaleAspectFill
           backgroundImageView.clipsToBounds = true
           
           titleLabel.textColor = .white
           titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
           titleLabel.numberOfLines = 2
       }
       
       func setupGradient() {
           gradientLayer.colors = [
               UIColor(hex: "#00000000").cgColor, // transparent top
               UIColor(hex: "#00000099").cgColor  // black 60% bottom
           ]
           gradientLayer.locations = [0.0, 1.0]
           gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
           gradientLayer.endPoint = CGPoint(x: 0.0, y: 1.0)
           backgroundImageView.layer.addSublayer(gradientLayer)
       }
   }
