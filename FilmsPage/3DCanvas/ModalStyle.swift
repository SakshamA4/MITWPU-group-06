//
//  ModalStyle.swift
//  FilmsPage
//
//  Shared design tokens for modal sheets (e.g., Ground/Wall Creation).
//

import SwiftUI

enum ModalStyle {
    static let background = Color(red: 11 / 255, green: 11 / 255, blue: 22 / 255)
    static let sectionLabelFont = Font.system(size: 11, weight: .semibold)
    static let sectionLabelColor = Color(UIColor.secondaryLabel)
    static let sectionLabelKerning: CGFloat = 1.2
    
    static let sliderFilledColor = Color(UIColor.systemBlue)
    static let sliderEmptyColor = UIColor(white: 0.25, alpha: 1.0)
    
    static let controlLabelFont = Font.system(size: 13, weight: .regular)
    static let controlValueFont = Font.system(size: 13, weight: .medium)
    
    static let buttonSelectedBackground = Color(white: 0.22)
    static let buttonUnselectedBackground = Color(white: 0.13)
    
    static let buttonSelectedTextColor = Color(UIColor.label)
    static let buttonUnselectedTextColor = Color(UIColor.label).opacity(0.45)
    
    static let tileCornerRadius: CGFloat = 10
    
    // Spacing
    static let sectionSpacingTop: CGFloat = 24
    static let interSliderSpacing: CGFloat = 20
}
