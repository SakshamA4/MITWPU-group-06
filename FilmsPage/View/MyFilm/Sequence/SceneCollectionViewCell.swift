//
//  SceneCollectionViewCell.swift
//  FilmsPage
//
//  Created by SDC-USER on 28/11/25.
//

import UIKit

class SceneCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    
    private var gradientLayer: CAGradientLayer?

    override func awakeFromNib() {
        super.awakeFromNib()
        
        contentView.layer.cornerRadius = 20
        contentView.layer.masksToBounds = true

        imageView.layer.cornerRadius = 20
        imageView.layer.masksToBounds = true

        titleLabel.textColor = .white
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateGradientFrame()
    }

    func configureCell(scene: Scene) {

        if let image = UIImage(named: scene.image) {
            imageView.image = image
            
            if let color = image.dominantColor() {
                applyGradientBehindLabel(using: color)
            }

        } else {
            imageView.image = nil
        }

        titleLabel.text = scene.name.capitalized
    }
    
    
    // MARK: - GRADIENT BEHIND LABEL
    func applyGradientBehindLabel(using color: UIColor) {
        
        gradientLayer?.removeFromSuperlayer()
        
        let gradient = CAGradientLayer()
        
        gradient.colors = [
            UIColor.clear.cgColor,
            color.withAlphaComponent(0.6).cgColor,
            color.withAlphaComponent(0.9).cgColor
        ]
        
        gradient.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradient.endPoint   = CGPoint(x: 0.5, y: 1.0)

        gradient.cornerRadius = contentView.layer.cornerRadius
        
        // Insert gradient between image and label
        contentView.layer.insertSublayer(gradient, above: imageView.layer)
        
        gradientLayer = gradient
        
        updateGradientFrame()
        
        // Keep label above gradient always
        contentView.bringSubviewToFront(titleLabel)

        // Border
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = UIColor.lightGray.cgColor
    }
    
    
    private func updateGradientFrame() {
        guard let gradient = gradientLayer else { return }
        
        contentView.layoutIfNeeded()
        
        // Where gradient should start (slightly below the label)
        let labelY = titleLabel.frame.minY
        let safeOffset: CGFloat = 8
        
        let gradientStartY = labelY + safeOffset
        
        gradient.frame = CGRect(
            x: 0,
            y: gradientStartY,
            width: contentView.bounds.width,
            height: contentView.bounds.height - gradientStartY
        )
    }
}


// MARK: - Dominant Color Extraction
extension UIImage {

    func SceneCelldominantColor() -> UIColor? {

        let size = CGSize(width: 10, height: 10)
        UIGraphicsBeginImageContext(size)
        draw(in: CGRect(origin: .zero, size: size))
        
        guard let resized = UIGraphicsGetImageFromCurrentImageContext() else {
            UIGraphicsEndImageContext()
            return nil
        }
        UIGraphicsEndImageContext()
        
        guard let cgImage = resized.cgImage,
              let data = cgImage.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data)
        else { return nil }
        
        var r = 0, g = 0, b = 0
        let length = CFDataGetLength(data)

        for i in stride(from: 0, to: length, by: 4) {
            r += Int(ptr[i])
            g += Int(ptr[i + 1])
            b += Int(ptr[i + 2])
        }

        let count = length / 4
        
        return UIColor(
            red: CGFloat(r / count) / 255,
            green: CGFloat(g / count) / 255,
            blue: CGFloat(b / count) / 255,
            alpha: 1
        )
    }
}
