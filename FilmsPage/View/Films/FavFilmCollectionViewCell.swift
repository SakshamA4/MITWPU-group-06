//
//  FavFilmCollectionViewCell.swift
//  FilmsPage
//
//  Created by SDC-USER on 24/11/25.
//

import UIKit

class FavFilmCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var sequencesLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var characterLabel: UILabel!
    @IBOutlet weak var sceneLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
            contentView.layer.cornerRadius = 20
            contentView.layer.masksToBounds = true
        
        contentView.layer.borderWidth = 0.7
        contentView.layer.borderColor = UIColor.gray.cgColor
            // Round the imageView
            imageView.layer.cornerRadius = 20
            imageView.layer.masksToBounds = true
        // Initialization code
    }
    

    
    func configureCell(film: Film) {
        if !film.image.isEmpty {
            imageView.image = UIImage(named: film.image)
        } else {
            imageView.image = nil // or set a placeholder: UIImage(named: "placeholder")
        }
        titleLabel.text = film.name.capitalized
        
        sequencesLabel.text = "Sequences: \(film.sequences)"
        characterLabel.text = "Characters: \(film.characters)"
        sceneLabel.text = "Scenes: \(film.scenes)"

        // Time (always 0 for now)
        timeLabel.text = "Time: 0"
    }


}

