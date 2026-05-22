//
//  SceneCollectionViewCell.swift
//  FilmsPage
//
//  Created by SDC-USER on 10/12/25.
//

import UIKit

class LibrarySceneCollectionViewCell: UICollectionViewCell {

    static let reuseIdentifier = "SceneCollectionViewCell"

    @IBOutlet weak var sceneImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!

    private let gradientLayer = CAGradientLayer()

       override func awakeFromNib() {
           super.awakeFromNib()

           setupUI()

       }

       override func layoutSubviews() {
           super.layoutSubviews()
           gradientLayer.frame = sceneImageView.bounds
       }

    func configure(with item: ScenesModel) {
        let imageName = item.image ?? "Image"
        sceneImageView.setFilmImage(named: imageName)
        titleLabel.text = item.name
    }
   }

   // MARK: - Setup
private extension LibrarySceneCollectionViewCell {

    func setupUI() {
        contentView.layer.cornerRadius = 12
        contentView.layer.masksToBounds = true
        contentView.backgroundColor = UIColor(hex: "#1A1A1A")

        sceneImageView.contentMode = .scaleAspectFill
        sceneImageView.clipsToBounds = true

        titleLabel.numberOfLines = 2
    }
}
