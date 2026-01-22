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
            return [
                SpawnItem(
                    title: "Woman 1",
                    imageName: "woman1_img",
                    modelFileName: "woman1",
                    poses: ["woman1", "Woman1MegLay", "Woman1Sit", "Woman1MegOnCall"]
                ),
                SpawnItem(
                    title: "Man",
                    imageName: "man1_img",
                    modelFileName: "man1",
                    poses: ["man1","Man1LyingIdle", "Man1SittingIdle", "Man1OnCall"]
                )
            ]

        case .prop:
            return [
                SpawnItem(
                    title: "Chair",
                    imageName: "chair_img",
                    modelFileName: "chair"
                ),
                SpawnItem(
                    title: "Table",
                    imageName: "Table_img",
                    modelFileName: "Table"
                ),
                SpawnItem(
                    title: "Wardrobe",
                    imageName: "wardrobe_img",
                    modelFileName: "wardrobe"
                ),
                SpawnItem(
                    title: "Lamp",
                    imageName: "lamp_img",
                    modelFileName: "lamp"
                ),
                SpawnItem(
                    title: "Robot",
                    imageName: "robot_img",
                    modelFileName: "Robot"
                ),
                SpawnItem(
                    title: "Flower Vase",
                    imageName: "flowerVase_img",
                    modelFileName: "flowerVase"
                ),
                SpawnItem(
                    title: "Plant",
                    imageName: "Plant_img",
                    modelFileName: "Plant"
                ),
                
                SpawnItem(
                    title: "Ball",
                    imageName: "ball_img",
                    modelFileName: "ball"
                )
            ]

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

