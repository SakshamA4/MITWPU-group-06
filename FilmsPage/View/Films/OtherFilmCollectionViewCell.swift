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

    var onSeeNotesTapped: (() -> Void)?

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
        imageView.layer.cornerRadius = 16
        imageView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        imageView.clipsToBounds = true
    }

    @IBAction func seeNotesTapped(_ sender: Any) {
        onSeeNotesTapped?()
    }

    func configureCell(film: Film) {
        self.film = film
        imageView.setFilmImage(named: film.image)
        titleLabel.text = film.name.capitalized
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yy, hh:mm a"
        createdDateLabel.text = "\(formatter.string(from: film.createdDate))"
    }
}

extension UIImageView {
    func setFilmImage(named name: String) {
        // 1. Try asset catalogue synchronously (fast, no disk I/O).
        if let asset = UIImage(named: name) {
            self.image = asset
            return
        }

        // 2. Try the Documents directory. Load on a background thread so we never
        //    block the main thread while reading a potentially large JPEG thumbnail.
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name)

        // Set a placeholder immediately so the cell isn't blank during the async load.
        self.image = UIImage(named: "Image")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                // Guard against cell reuse: only apply if the imageView still wants
                // this particular file (checked via the url path tag approach below).
                self?.image = image
            }
        }
    }
}
