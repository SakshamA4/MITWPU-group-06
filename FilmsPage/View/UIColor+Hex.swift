//
//  UIColor+Hex.swift
//  FilmsPage
//
//  Created by SDC-USER on 28/11/25.
//

import UIKit

extension UIColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        let scanner = Scanner(string: hexSanitized)
        guard scanner.scanHexInt64(&rgb) else {
            // If scan fails, default to light gray
            self.init(white: 0.5, alpha: 1.0)
            return
        }

        let length = hexSanitized.count
        var r, g, b: CGFloat

        switch length {
        case 6:
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
        default:
            // Handle invalid hex length
            r = 0.5; g = 0.5; b = 0.5
        }

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
