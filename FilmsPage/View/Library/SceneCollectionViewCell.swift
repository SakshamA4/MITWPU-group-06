//
//  SceneCollectionViewCell.swift
//  FilmsPage
//
//  Created by SDC-USER on 10/12/25.
//

import UIKit

class SceneCollectionViewCell: UICollectionViewCell {
    
    static let reuseIdentifier = "SceneCollectionViewCell"
    
    @IBOutlet weak var sceneImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    
    private let gradientLayer = CAGradientLayer()
       
       override func awakeFromNib() {
           super.awakeFromNib()
           
           setupUI()
           setupGradient()
       }
       
       override func layoutSubviews() {
           super.layoutSubviews()
           gradientLayer.frame = sceneImageView.bounds
       }
       
       func configure(with item: SceneItem) {
           sceneImageView.image = UIImage(named: item.imageName)
           titleLabel.text = item.title
       }
   }

   // MARK: - Setup
   private extension SceneCollectionViewCell {
       
       func setupUI() {
           contentView.layer.cornerRadius = 12
           contentView.layer.masksToBounds = true
           contentView.backgroundColor = UIColor(hex: "#1A1A1A")
           
           sceneImageView.contentMode = .scaleAspectFill
           sceneImageView.clipsToBounds = true
           
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
           sceneImageView.layer.addSublayer(gradientLayer)
       }
   }
