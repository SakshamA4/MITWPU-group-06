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

    private enum Constants {
        static let aspectOverlayTag = 9300
        static let barAlpha: CGFloat = 1.0
    }

    // Image view receives live snapshots — replaces the static ARView clone
    let previewImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .black
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
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
            previewImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
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
            label.heightAnchor.constraint(equalToConstant: 18)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = contentView.bounds
        // Re-draw aspect bars on layout change so they match current bounds
        if let overlay = contentView.viewWithTag(Constants.aspectOverlayTag) {
            overlay.frame = contentView.bounds
        }
    }

    /// Called by the timer in CanvasViewController to push a fresh snapshot into this cell
    func updatePreview(image: UIImage, name: String) {
        label.text = name
        previewImageView.image = image
    }

    /// Draws pillarbox or letterbox bars on the cell to indicate the camera's aspect ratio.
    /// Call after updatePreview to ensure bars are on top of the image.
    func updateAspectRatio(_ ratio: CameraAspectRatio) {
        // Remove previous overlay
        contentView.viewWithTag(Constants.aspectOverlayTag)?.removeFromSuperview()

        // 16:9 cells are the default — no bars needed
        if ratio == .sixteenByNine { return }

        let cellSize = contentView.bounds.size
        guard cellSize.width > 0, cellSize.height > 0 else { return }

        let cellRatio = Float(cellSize.width / cellSize.height)
        let targetRatio = ratio.ratio

        let overlay = UIView(frame: contentView.bounds)
        overlay.tag = Constants.aspectOverlayTag
        overlay.isUserInteractionEnabled = false
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // Insert below the label but above the image
        contentView.insertSubview(overlay, belowSubview: label)

        if targetRatio < cellRatio {
            // Pillarbox (bars on left & right)
            let targetWidth = cellSize.height * CGFloat(targetRatio)
            let barWidth = (cellSize.width - targetWidth) / 2.0

            let leftBar = UIView(frame: CGRect(x: 0, y: 0, width: barWidth, height: cellSize.height))
            leftBar.backgroundColor = UIColor.black.withAlphaComponent(Constants.barAlpha)
            leftBar.autoresizingMask = [.flexibleHeight, .flexibleRightMargin]
            overlay.addSubview(leftBar)

            let rightBar = UIView(frame: CGRect(
                x: cellSize.width - barWidth, y: 0,
                width: barWidth, height: cellSize.height))
            rightBar.backgroundColor = UIColor.black.withAlphaComponent(Constants.barAlpha)
            rightBar.autoresizingMask = [.flexibleHeight, .flexibleLeftMargin]
            overlay.addSubview(rightBar)
        } else {
            // Letterbox (bars on top & bottom)
            let targetHeight = cellSize.width / CGFloat(targetRatio)
            let barHeight = (cellSize.height - targetHeight) / 2.0

            let topBar = UIView(frame: CGRect(x: 0, y: 0, width: cellSize.width, height: barHeight))
            topBar.backgroundColor = UIColor.black.withAlphaComponent(Constants.barAlpha)
            topBar.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
            overlay.addSubview(topBar)

            let bottomBar = UIView(frame: CGRect(
                x: 0, y: cellSize.height - barHeight,
                width: cellSize.width, height: barHeight))
            bottomBar.backgroundColor = UIColor.black.withAlphaComponent(Constants.barAlpha)
            bottomBar.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
            overlay.addSubview(bottomBar)
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        previewImageView.image = nil
        label.text = nil
        contentView.viewWithTag(Constants.aspectOverlayTag)?.removeFromSuperview()
    }

    required init?(coder: NSCoder) { fatalError() }
}
