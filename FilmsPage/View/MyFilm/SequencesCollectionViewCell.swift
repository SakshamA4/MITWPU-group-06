//
//  ScenesCollectionViewCell.swift
//  FilmsPage
//
//  Created by SDC-USER on 26/11/25.
//

//import UIKit
//
//class SequencesCollectionViewCell: UICollectionViewCell {
//
//    @IBOutlet weak var imageView: UIImageView!
//    @IBOutlet weak var titleLabel: UILabel!
//    
//    override func awakeFromNib() {
//        super.awakeFromNib()
//        
//        contentView.layer.cornerRadius = 20
//        contentView.layer.masksToBounds = true
//
//        // Round the imageView
//        imageView.layer.cornerRadius = 20
//        imageView.layer.masksToBounds = true
//        // Initialization code
//    }
//   
//    
//    func configureCell(sequence: Sequence) {
//        if !sequence.image.isEmpty {
//            imageView.image = UIImage(named: sequence.image)
//        } else {
//            imageView.image = nil // or set a placeholder: UIImage(named: "placeholder")
//        }
//        titleLabel.text = sequence.name.capitalized
//    }
//
//
//}

import UIKit

class SequencesCollectionViewCell: UICollectionViewCell {

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

    func configureCell(sequence: Sequence) {

        if let image = UIImage(named: sequence.image) {
            imageView.image = image
            
            if let color = image.dominantColor() {
                applyGradientBehindLabel(using: color)
            }

        } else {
            imageView.image = nil
        }

        titleLabel.text = sequence.name.capitalized
    }
    
    
    // MARK: - GRADIENT BEHIND LABEL (without overlapping text)
    
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
        
        // Insert behind label but above image
        contentView.layer.insertSublayer(gradient, above: imageView.layer)
        
        gradientLayer = gradient
        
        updateGradientFrame()
        
        // Make sure label stays above gradient
        contentView.bringSubviewToFront(titleLabel)

        // Border
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = UIColor.lightGray.cgColor
    }
    
    
    private func updateGradientFrame() {
        guard let gradient = gradientLayer else { return }
        
        contentView.layoutIfNeeded()
        
        // Gradient starts BELOW label so the text stays white
        let labelY = titleLabel.frame.minY
        
        // Safe space to prevent text from being tinted
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
    func dominantColor() -> UIColor? {

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
