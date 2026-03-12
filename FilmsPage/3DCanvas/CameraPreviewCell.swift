//
//  CameraPreviewCell.swift
//  3DCanvas
//
//  Created by SDC-USER on 14/01/26.
//

import UIKit
import RealityKit

class CameraPreviewCell: UICollectionViewCell {

    static let reuseID = "CameraPreviewCell"

    // Image view receives live snapshots — replaces the static ARView clone
    let previewImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = .black
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    let label = UILabel()

    // Gradient overlay so the label is always legible on top of the image
    private let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.backgroundColor = UIColor(white: 0.15, alpha: 1)
        contentView.layer.cornerRadius = 10
        contentView.clipsToBounds = true

        // Image fills the entire cell
        contentView.addSubview(previewImageView)
        NSLayoutConstraint.activate([
            previewImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            previewImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            previewImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            previewImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        // Dark gradient at the bottom so the label is readable
        gradientLayer.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.65).cgColor]
        gradientLayer.locations = [0.55, 1.0]
        contentView.layer.addSublayer(gradientLayer)

        // Label overlaid at the bottom
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textAlignment = .center
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            label.heightAnchor.constraint(equalToConstant: 18),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = contentView.bounds
    }

    /// Called by the timer in CanvasViewController to push a fresh snapshot into this cell
    func updatePreview(image: UIImage, name: String) {
        label.text = name
        previewImageView.image = image
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        previewImageView.image = nil
        label.text = nil
    }

    required init?(coder: NSCoder) { fatalError() }
}

extension Entity {
    func forEachDescendant(_ body: (Entity) -> Void) {
        body(self)
        for child in children {
            child.forEachDescendant(body)
        }
    }
}
