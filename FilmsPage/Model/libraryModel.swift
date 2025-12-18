//
//  libraryModel.swift
//  FilmsPage
//
//  Created by SDC-USER on 26/11/25.
//
import Foundation

// made this protocol for everything we have to show in the grid in library

protocol LibraryDisplayItem: Identifiable, Hashable {
    var id: UUID { get }
    var title: String { get }
    var imageName: String { get }
}

enum LibrarySection: Int, CaseIterable {
    case featured          // top row: big cards
    case assets            // bottom row: smaller cards

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
    var imageName: String      // name of the image in your asset catalog
    var destinationKey: String // e.g. which screen you push when tapped
}

// MARK: - Static “data source” for the screen

enum LibraryModel {

    /// Items shown in each section of the Library screen
    static let sections: [LibrarySection: [LibraryItem]] = [
        .featured: [
            LibraryItem(
                title: "Scenes",
                imageName: "Scenes",        // put this image in Assets
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
                imageName: "Lights",
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



//protocol LibraryDisplayItem: Identifiable, Hashable {
//    var id: UUID { get }
//    var name: String { get set }
//    var imageName: String { get set }
//}
//
//
//enum LibraryCategoryType: String, CaseIterable {
//    case scenes = "Scenes"
//    case camerasAndMovements = "Cameras & Movements"
//    case characters = "Characters"
//    case props = "Props"
//    case lights = "Lights"
//    case backgrounds = "Background"
//}
//
////SCENES
//
//struct SceneItem: LibraryDisplayItem {
//    let id = UUID()
//    var name: String
//    var imageName: String
//    
//    var note: String?
//}
//
//// Cameras & Movements
//
//struct CameraItem: LibraryDisplayItem {
//    let id = UUID()
//    var name: String
//    var imageName: String
//}
//
//struct CameraMovementItem: LibraryDisplayItem {
//    let id = UUID()
//    var name: String
//    var imageName: String
//}
//
//struct StaticShotItem: LibraryDisplayItem {
//    let id = UUID()
//    var name: String
//    var imageName: String
//}
//
////Characters
//
//struct CharacterItem: LibraryDisplayItem {
//    let id = UUID()
//    var name: String
//    var imageName: String
//}
//
////Props
//
//struct PropItem: LibraryDisplayItem {
//    let id = UUID()
//    var name: String
//    var imageName: String
//}
//
////Lights
//
//struct LightItem: LibraryDisplayItem {
//    let id = UUID()
//    var name: String
//    var imageName: String
//}
//
//// Backgrounds
//
//struct BackgroundItem: LibraryDisplayItem {
//    let id = UUID()
//    var name: String
//    var imageName: String
//}
