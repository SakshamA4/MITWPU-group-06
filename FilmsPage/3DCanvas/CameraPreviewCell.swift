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

    override init(frame: CGRect) {
        super.init(frame: frame)

        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textAlignment = .center
        label.textColor = .white

        contentView.addSubview(previewImageView)
        contentView.addSubview(label)

        label.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            previewImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            previewImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            previewImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            previewImageView.heightAnchor.constraint(equalToConstant: 90),

            label.topAnchor.constraint(equalTo: previewImageView.bottomAnchor, constant: 4),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        contentView.backgroundColor = .darkGray
        contentView.layer.cornerRadius = 10
        contentView.clipsToBounds = true
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
