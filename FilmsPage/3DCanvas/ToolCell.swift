//
//  ToolCell.swift
//  3DCanvas
//
//  Created by SDC-USER on 12/01/26.
//

import UIKit

class ToolCell: UICollectionViewCell {

    let imageView = UIImageView()
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 14
        contentView.clipsToBounds = true

        // IMAGE
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 10

        // LABEL
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 20, weight: .medium)
        label.numberOfLines = 1
        label.textColor = .label

        imageView.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(imageView)
        contentView.addSubview(label)

        NSLayoutConstraint.activate([

            // Image occupies top area
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            imageView.heightAnchor.constraint(equalTo: contentView.heightAnchor, multiplier: 0.7),

            // Label below image
            label.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            label.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -6)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with item: SpawnItem) {
        imageView.image = UIImage(named: item.imageName)
        label.text = item.title
    }
}
