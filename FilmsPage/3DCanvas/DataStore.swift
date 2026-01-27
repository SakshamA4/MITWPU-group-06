//
//  DataStore.swift
//  3DCanvas
//
//  Created by SDC-USER on 12/01/26.
//

import Foundation
import UIKit
import RealityKit

// MARK: - Original Color Component
// This stays the same as your original code to track the base color
struct OriginalColorComponent: Component {
    let color: UIColor
}

struct CategoryComponent: Component {
    let toolType: ToolType
}

enum ToolType: CaseIterable {
    case character, prop, camera, light, background, wall

    var title: String {
        switch self {
        case .character: return "Character"
        case .prop: return "Prop"
        case .camera: return "Camera"
        case .light: return "Light"
        case .background: return "Background"
        case .wall: return "Wall"
        }
    }
    
    var icon: String {
        switch self {
        case .character: return "person.fill"
        case .prop: return "cube.fill"
        case .camera: return "camera.fill"
        case .light: return "lightbulb.fill"
        case .background: return "photo.fill"
        case .wall: return "square.split.2x2"
        }
    }

    var items: [SpawnItem] {
        switch self {

       case .character:
           return CharacterService.shared.getCharacters().map { SpawnItem(character: $0) }

       case .prop:
            return PropService.shared.getProps().map { SpawnItem(prop: $0) }

        case .camera:
            return [
                SpawnItem(
                    title: "DSLR Camera",
                    imageName: "DSLR_img",
                    modelFileName: "cam1"
                )
            ]

        case .light:
            return [
                SpawnItem(
                    title: "Spotlight",
                    imageName: "spotlight_img",
                    modelFileName: "Spotlight"
                )
            ]


        case .background:
            return [

            ]
            
        case .wall:
            return [
                SpawnItem(
                    title: "Wall",
                    imageName: "wall_img",
                    modelFileName: "cube"
                ),
                SpawnItem(
                    title: "Ground",
                    imageName: "ground_img",
                    modelFileName: "ground"
                )

            ]
        }
    }
}

extension ToolType {
    var hierarchyTitle: String {
        switch self {
        case .character: return "Characters"
        case .prop: return "Props"
        case .camera: return "Cameras"
        case .light: return "Lighting"
        case .background: return "Background"
        case .wall: return "Wall"
        }
    }
}

