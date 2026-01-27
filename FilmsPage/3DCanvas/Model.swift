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
}
