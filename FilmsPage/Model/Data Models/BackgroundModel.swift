//
//  BackgroundItem.swift
//  FilmsPage
//
//  Created by SDC-USER on 08/12/25.
//
import Foundation
import UIKit

struct BackgroundItem: Identifiable, Hashable {
    let id: UUID = UUID()
    var title: String
    var imageName: String? // Optional: for assets like "bg_placeholder"
    var customImage: UIImage? // For images picked from the gallery

    // We need to tell Swift how to hash UIImage if we want to keep Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: BackgroundItem, rhs: BackgroundItem) -> Bool {
        lhs.id == rhs.id
    }
}
