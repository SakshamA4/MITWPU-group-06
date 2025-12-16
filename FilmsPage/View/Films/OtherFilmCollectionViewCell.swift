//
//  OtherFilmCollectionViewCell.swift
//  FilmsPage
//
//  Created by SDC-USER on 24/11/25.
//

import UIKit

protocol OtherFilmDelegate {
    func setFavFilm(film: Film)
}

class OtherFilmCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var FavButton: UIButton!
    
    @IBOutlet weak var view: UIView!
    
    var delegate: OtherFilmDelegate?
    var film: Film?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        contentView.layer.cornerRadius = 20
        contentView.layer.masksToBounds = true
        contentView.layer.borderWidth = 0.7
        contentView.layer.borderColor = UIColor.gray.cgColor
        // Round the imageView

        // Initialization code
    }
    
    @IBAction func onFavClick(_ sender: Any) {
        delegate?.setFavFilm(film: film!)
        
    }
    func configureCell(film: Film) {
        if !film.image.isEmpty {
            imageView.image = UIImage(named: film.image)
        } else {
            imageView.image = nil // or set a placeholder: UIImage(named: "placeholder")
        }
        self.film = film
        titleLabel.text = film.name.capitalized
    }
}
