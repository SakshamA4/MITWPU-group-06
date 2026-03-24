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
    case character, prop, camera, light, background, wall, sky

    var title: String {
        switch self {
        case .character: return "Character"
        case .prop: return "Prop"
        case .camera: return "Camera"
        case .light: return "Light"
        case .background: return "Background"
        case .wall: return "Wall"
        case .sky: return "Sky"
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
        case .sky: return "cloud.sun.fill"
        }
    }

    var items: [SpawnItem] {
        switch self {

       case .character:
           return CharacterService.shared.getCharacters().map { SpawnItem(character: $0) }

       case .prop:
            return PropService.shared.getProps().map { SpawnItem(prop: $0) }

        case .camera:
                    // 1. Get the 'Cameras' section from your global data store
                    guard let cameraSection = CameraLibraryDataStore.sections.first(where: { $0.type == .cameras }) else {
                        return []
                    }
            let playableCameras = cameraSection.items.filter { $0.modelFileName != nil }

                        // 3. Convert them to SpawnItems
                        return playableCameras.map { SpawnItem(camera: $0) }

            // In DataStore.swift

                    case .light:
                        // 1. Access the items directly (since there are no sections)
                        let allLights = LightsDataStore.items
                        
                        // 2. Filter for items that actually have a 3D model
                        // This ensures only "Spotlight" shows up, and the text-only ones are hidden
                        let playableLights = allLights.filter { $0.modelFileName != nil }

                        // 3. Convert them to SpawnItems
                        return playableLights.map { SpawnItem(light: $0) }


        case .background:
                // CONNECT: Map global background items to SpawnItems
                return BackgroundStore.shared.items.map { SpawnItem(background: $0) }
            
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
            
        case .sky:
            return [
//                SpawnItem(
//                    title: "Daylight Sky",
//                    imageName: "cloud.sun",
//                    modelFileName: "sky_day"
//                ),
//                SpawnItem(
//                    title: "Sunset Sky",
//                    imageName: "sunset",
//                    modelFileName: "sky_sunset"
//                ),
//                SpawnItem(
//                    title: "Midnight Sky",
//                    imageName: "moon.stars",
//                    modelFileName: "sky_night"
//                ),
                SpawnItem(
                    title: "Blue Sky",
                    imageName: "Blue_sky",
                    modelFileName: "Blue_sky"
                ),
                SpawnItem(
                    title: "Starry Night",
                    imageName: "Nighty_night",
                    modelFileName: "Nighty_night"
                ),
                SpawnItem(
                    title: "Evening Hue",
                    imageName: "Evening_sky",
                    modelFileName: "Evening_sky"
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
        case .sky: return "Sky"
        }
    }
}

