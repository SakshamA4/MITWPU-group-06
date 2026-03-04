//
//  OtherFilmCollectionViewCell.swift
//  FilmsPage
//

import UIKit

class OtherFilmCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!

    // NOTE: FavButton IBOutlet/IBAction and OtherFilmDelegate have been removed.
    // If you have a FavButton in your .xib, you can delete it or leave it
    // disconnected — it won't cause a crash unless it still has an IBAction wired up.

    private var film: Film?

    override func awakeFromNib() {
        super.awakeFromNib()
        contentView.layer.cornerRadius = 20
        contentView.layer.masksToBounds = true
        contentView.layer.borderWidth = 0.7
        contentView.layer.borderColor = UIColor.gray.cgColor
    }

    func configureCell(film: Film) {
        self.film = film
        imageView.image = film.image.isEmpty ? nil : UIImage(named: film.image)
        titleLabel.text = film.name.capitalized
    }
}
