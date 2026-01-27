//
//  libraryModel.swift
//  FilmsPage
//
//  Created by SDC-USER on 26/11/25.
//
import Foundation


protocol LibraryDisplayItem: Identifiable, Hashable {
    var id: UUID { get }
    var title: String { get }
    var imageName: String { get }
}

enum LibrarySection: Int, CaseIterable {
    case featured
    case assets

    var title: String {
        switch self {
        case .featured: return "Library"
        case .assets:   return "Assets"
        }
    }
}

// MARK: - Item model

struct LibraryItem: LibraryDisplayItem {
    let id = UUID()
    var title: String
    var imageName: String
    var destinationKey: String
}



enum LibraryModel {


    static let sections: [LibrarySection: [LibraryItem]] = [
        .featured: [
            LibraryItem(
                title: "Scenes",
                imageName: "Scenes",
                destinationKey: "scenes"
            ),
            LibraryItem(
                title: "Cameras and Movements",
                imageName: "t1",
                destinationKey: "camerasAndMovements"
            )
        ],
        .assets: [
            LibraryItem(
                title: "Characters",
                imageName: "Characters",
                destinationKey: "characters"
            ),
            LibraryItem(
                title: "Props",
                imageName: "Props",
                destinationKey: "props"
            ),
            LibraryItem(
                title: "Lights",
                imageName: "lights",
                destinationKey: "lights"
            ),
            LibraryItem(
                title: "Background",
                imageName: "Background",
                destinationKey: "background"
            )
        ]
    ]
}

