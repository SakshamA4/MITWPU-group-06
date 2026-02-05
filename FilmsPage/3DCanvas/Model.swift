//
//  spawnItem.swift
//  3DCanvas
//
//  Created by SDC-USER on 12/01/26.
//

import UIKit

struct SpawnPose {
    let title: String
    let imageName: String
    let modelFileName: String
}

struct SpawnItem {
    var title: String
    let imageName: String?
    var modelFileName: String
    var isBackground: Bool = false
    var UUId: UUID = UUID()
    var customImage: UIImage? = nil
    
    var poses: [SpawnPose]? = nil
    var detailText: String? = nil
    var selectedPose: String? = nil
}

class BackgroundStore {
    static let shared = BackgroundStore()
    
    // 1. The Single Source of Truth
    var items: [BackgroundItem] = BackgroundData.allBackgrounds
    
    // 2. Selection Handling
    var onBackgroundSelected: ((BackgroundItem) -> Void)?
    
    func selectBackground(_ item: BackgroundItem) {
        // Notify listeners (e.g., the Canvas)
        onBackgroundSelected?(item)
    }
    
    func addBackground(_ item: BackgroundItem) {
        // Insert at the top
        items.insert(item, at: 0)
    }
}

// In DataStore.swift

extension SpawnItem {
    // Your existing Character init...
    init(character: CharacterItem) {
        // Map the full character data to our new SpawnPose struct
        let poseItems = character.pose.map { pose in
            SpawnPose(
                title: pose.name,
                imageName: pose.imageName,       // Passes "Woman1Sit_img"
                modelFileName: pose.modelFilename ?? "" // Passes "Woman1Sit"
            )
        }
        
        let defaultModel = character.pose.first?.modelFilename ?? character.imageName
        
        self.init(
            title: character.name,
            imageName: character.imageName,
            modelFileName: defaultModel,
            isBackground: false,
            UUId: character.id,
            poses: poseItems // Pass the rich data here
        )
    }
    
    // NEW: Prop init
    init(prop: PropItem) {
        self.init(
            title: prop.name,
            imageName: prop.imageName,
            modelFileName: prop.modelFileName ?? "", // Handle optional
            isBackground: false,
            UUId: prop.id ?? UUID(),
            detailText: prop.description
        )
    }
    
    init(camera: CameraLibraryItem) {
        self.init(
            title: camera.name,
            imageName: camera.imageName,
            // Fallback to empty string if no model is defined
            modelFileName: camera.modelFileName ?? "",
            isBackground: false,
            // FIX: Pass the persistent ID from the camera item
            UUId: camera.id,
            // Use the description from the camera library
            detailText: camera.description
        )
    }
    
    init(light: LightItem) {
        self.init(
            title: light.name,
            imageName: light.imageName,
            // Use the modelFileName if it exists, otherwise empty string
            modelFileName: light.modelFileName ?? "",
            isBackground: false,
            detailText: light.description
        )
    }
    
    init(background: BackgroundItem) {
            self.init(
                title: background.title,
                imageName: background.imageName,
                modelFileName: "plane", // Assuming you use a generic plane for backgrounds
                isBackground: true,     // Crucial flag
                UUId: background.id,
                customImage: background.customImage
            )
        }
}


extension SpawnItem {

    init(
        filmCharacter: FilmCharacter,
        template: CharacterItem
    ) {

        let poseItems = template.pose.map { pose in
            SpawnPose(
                title: pose.name,
                imageName: pose.imageName,
                modelFileName: pose.modelFilename ?? ""
            )
        }

        let selectedPoseModel =
            template.pose.first {
                $0.id == filmCharacter.selectedPoseId
            }?.modelFilename
            ?? template.pose.first?.modelFilename
            ?? ""

        self.init(
            title: filmCharacter.nameOverride ?? template.name,
            imageName: template.imageName,
            modelFileName: selectedPoseModel,
            isBackground: false,
            UUId: filmCharacter.id,
            poses: poseItems
        )
    }
}
