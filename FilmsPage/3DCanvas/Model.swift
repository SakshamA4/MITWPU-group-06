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
    let imageName: String      // for UI
    var modelFileName: String  // for RealityKit
    var isBackground: Bool = false
    var UUId: UUID = UUID()
    
    var poses: [SpawnPose]? = nil
    var detailText: String? = nil
    var selectedPose: String? = nil
}

class BackgroundStore {
    static let shared = BackgroundStore()
    

        var images: [UIImage] = []

        var currentSelectedImage: UIImage?
        var onImageSelected: ((UIImage) -> Void)?

        func selectImage(_ image: UIImage) {
            onImageSelected?(image)
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
                UUId: character.id ?? UUID(),
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
                // Fallback to empty string if no model is defined, preventing crashes
                modelFileName: camera.modelFileName ?? "",
                isBackground: false,
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
