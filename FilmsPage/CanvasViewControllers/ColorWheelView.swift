//
// ColorWheelView.swift
// FilmsPage
//
// Created by Ritik
//

import UIKit

class ColorWheelView: UIView {

    override func layoutSubviews() {
        super.layoutSubviews()
        // Ensure the view is always circular
        layer.cornerRadius = bounds.width / 2
        clipsToBounds = true
    }

    override func draw(_ rect: CGRect) {
        // Define the color stops (Approximation of the spectrum)
        let colors = [
            UIColor.red.cgColor,
            UIColor.yellow.cgColor,
            UIColor.green.cgColor,
            UIColor.blue.cgColor,
            UIColor.purple.cgColor,
            UIColor.red.cgColor
        ]
        
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Center point and radius for the gradient
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = max(rect.width, rect.height) / 2
        
        // Create the color space
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        // Define the gradient
        guard let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: colors as CFArray,
            locations: nil // Locations will be automatically distributed
        ) else { return }
        
        // Draw the radial gradient
        context.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: radius,
            options: .drawsAfterEndLocation
        )
    }
}
