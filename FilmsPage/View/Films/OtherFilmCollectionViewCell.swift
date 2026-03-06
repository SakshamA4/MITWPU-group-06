//
//  OtherFilmCollectionViewCell.swift
//  FilmsPage
//

import UIKit

class OtherFilmCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!

    @IBOutlet weak var seeNotesButton: UIButton!
    
    @IBOutlet weak var createdDateLabel: UILabel!
    
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
        imageView.setFilmImage(named: film.image)
        titleLabel.text = film.name.capitalized
    }
}

extension UIImageView {
    func setFilmImage(named name: String) {
        // 1. Try asset catalogue (default "Image", template names)
        if let asset = UIImage(named: name) {
            self.image = asset
            return
        }
        // 2. Try documents directory (user-picked photos saved to disk)
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name)
        if let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            self.image = image
            return
        }
        // 3. Fallback
        self.image = UIImage(named: "Image")
    }
}
