//
//  CharactersCollectionViewCell.swift
//  FilmsPage
//
//  Created by SDC-USER on 26/11/25.
//

import UIKit

class CharactersCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var imageView: UIImageView!

    @IBOutlet weak var titleLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        contentView.layer.cornerRadius = 20
        contentView.layer.masksToBounds = true

        imageView.layer.borderWidth = 0.7
        imageView.layer.borderColor = UIColor.gray.cgColor

        contentView.layer.borderWidth = 0.7
        contentView.layer.borderColor = UIColor.gray.cgColor

        // Round the imageView
        imageView.layer.cornerRadius = 16
        imageView.layer.masksToBounds = true
        imageView.layer.maskedCorners = [
            .layerMinXMinYCorner,
            .layerMaxXMinYCorner
        ]
        // Initialization code
    }

    func configureForLibrary(character: CharacterItem) {
        imageView.image = UIImage(named: character.imageName)
        titleLabel.text = character.name.capitalized
    }

    func configureCell(
        filmCharacter: FilmCharacter,
        template: CharacterItem?
    ) {
        // Image always comes from the library template
        if let imageName = template?.imageName {
            imageView.image = UIImage(named: imageName)
        } else {
            imageView.image = UIImage(named: "placeholder")
        }

        // Name can be overridden per film
        titleLabel.text = (filmCharacter.nameOverride ?? template?.name ?? "Character").capitalized
    }

}
