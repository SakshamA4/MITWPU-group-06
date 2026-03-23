//
//  Model.swift
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

// MARK: - BackgroundStore

class BackgroundStore {
    static let shared = BackgroundStore()

    var items: [BackgroundItem] = BackgroundData.allBackgrounds

    var onBackgroundSelected: ((BackgroundItem) -> Void)?
    var onImageSelected: ((UIImage) -> Void)?

    func selectBackground(_ item: BackgroundItem) {
        onBackgroundSelected?(item)
    }

    func addBackground(_ item: BackgroundItem) {
        items.insert(item, at: 0)
    }
}

// MARK: - SpawnItem convenience initialisers

extension SpawnItem {

    init(character: CharacterItem) {
        let poseItems = character.pose.map { pose in
            SpawnPose(
                title:         pose.name,
                imageName:     pose.imageName,
                modelFileName: pose.modelFilename ?? ""
            )
        }
        let defaultModel = character.pose.first?.modelFilename ?? character.imageName
        self.init(
            title:     character.name,
            imageName: character.imageName,
            modelFileName: defaultModel,
            isBackground:  false,
            UUId:          character.id,
            poses:         poseItems
        )
    }

    init(prop: PropItem) {
        self.init(
            title:         prop.name,
            imageName:     prop.imageName,
            modelFileName: prop.modelFileName ?? "",
            isBackground:  false,
            UUId:          prop.id ?? UUID(),
            detailText:    prop.description
        )
    }

    init(camera: CameraLibraryItem) {
        self.init(
            title:         camera.name,
            imageName:     camera.imageName,
            modelFileName: camera.modelFileName ?? "",
            isBackground:  false,
            UUId:          camera.id,
            detailText:    camera.description
        )
    }

    init(light: LightItem) {
        self.init(
            title:         light.name,
            imageName:     light.imageName,
            modelFileName: light.modelFileName ?? "",
            isBackground:  false,
            detailText:    light.description
        )
    }

    init(background: BackgroundItem) {
        self.init(
            title:         background.title,
            imageName:     background.imageName,
            modelFileName: "plane",
            isBackground:  true,
            UUId:          background.id,
            customImage:   background.customImage
        )
    }
}

// MARK: - FilmCharacter init

extension SpawnItem {

    init(filmCharacter: FilmCharacter, template: CharacterItem) {
        let poseItems = template.pose.map { pose in
            SpawnPose(
                title:         pose.name,
                imageName:     pose.imageName,
                modelFileName: pose.modelFilename ?? ""
            )
        }
        let selectedPoseModel =
            template.pose.first { $0.id == filmCharacter.selectedPoseId }?.modelFilename
            ?? template.pose.first?.modelFilename
            ?? ""

        self.init(
            title:         filmCharacter.nameOverride ?? template.name,
            imageName:     template.imageName,
            modelFileName: selectedPoseModel,
            isBackground:  false,
            UUId:          filmCharacter.id,
            poses:         poseItems
        )
    }
}
