//
//  Model.swift
//  3DCanvas
//
//  Created by SDC-USER on 12/01/26.
//

import UIKit
import RealityKit

// MARK: - LightConfigComponent (ECS)

/// Central ECS component for light properties.
/// Stored on the model entity at spawn time via `entity.components.set(config)`.
/// Single source of truth — spawn reads from it, UI reads from it, persistence reads from it.
struct LightConfigComponent: Component, Codable {
    var lightKind: LightKind
    var intensity: Float
    var colorTemperatureKelvin: Float
    var innerAngleDeg: Float            // 0 if not applicable (point light)
    var outerAngleDeg: Float            // 0 if not applicable (point light)
    var attenuationRadius: Float
    var shadowEnabled: Bool
    var modelScale: Float               // stored so attachLight() can derive counter-scale
    var reflectorType: ReflectorType = .standard
    var activeGobo: GoboPattern = .none
    var diffuserAmount: Float = 0.0     // 0.0 = hard edge, 1.0 = full silk
    var proceduralKind: ProceduralLightKind?  // non-nil for procedural lights

    // Derived — not stored
    var uiColor: UIColor { .fromKelvin(colorTemperatureKelvin) }
    var counterScale: Float { 1.0 / modelScale }  // child entities must be scaled by this

    static func from(_ config: LightConfig, kind: LightKind, proceduralKind: ProceduralLightKind? = nil) -> LightConfigComponent {
        LightConfigComponent(
            lightKind: kind,
            intensity: config.intensity,
            colorTemperatureKelvin: config.colorTemperatureKelvin,
            innerAngleDeg: config.innerAngleDeg,
            outerAngleDeg: config.outerAngleDeg,
            attenuationRadius: config.attenuationRadius,
            shadowEnabled: config.shadowEnabled,
            modelScale: config.modelScale,
            reflectorType: config.reflectorType,
            activeGobo: config.activeGobo,
            diffuserAmount: config.diffuserAmount,
            proceduralKind: proceduralKind
        )
    }

    // Codable — exclude computed properties, use defaults for new optional fields
    enum CodingKeys: String, CodingKey {
        case lightKind, intensity, colorTemperatureKelvin
        case innerAngleDeg, outerAngleDeg, attenuationRadius
        case shadowEnabled, modelScale
        case reflectorType, activeGobo, diffuserAmount
        case proceduralKind
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lightKind              = try c.decode(LightKind.self, forKey: .lightKind)
        intensity              = try c.decode(Float.self, forKey: .intensity)
        colorTemperatureKelvin = try c.decode(Float.self, forKey: .colorTemperatureKelvin)
        innerAngleDeg          = try c.decode(Float.self, forKey: .innerAngleDeg)
        outerAngleDeg          = try c.decode(Float.self, forKey: .outerAngleDeg)
        attenuationRadius      = try c.decode(Float.self, forKey: .attenuationRadius)
        shadowEnabled          = try c.decode(Bool.self, forKey: .shadowEnabled)
        modelScale             = try c.decode(Float.self, forKey: .modelScale)
        // New fields — backward compatible with older saves (default if missing)
        reflectorType  = try c.decodeIfPresent(ReflectorType.self, forKey: .reflectorType) ?? .standard
        activeGobo     = try c.decodeIfPresent(GoboPattern.self, forKey: .activeGobo) ?? .none
        diffuserAmount = try c.decodeIfPresent(Float.self, forKey: .diffuserAmount) ?? 0.0
        proceduralKind = try c.decodeIfPresent(ProceduralLightKind.self, forKey: .proceduralKind)
    }

    init(lightKind: LightKind, intensity: Float, colorTemperatureKelvin: Float,
         innerAngleDeg: Float, outerAngleDeg: Float, attenuationRadius: Float,
         shadowEnabled: Bool, modelScale: Float,
         reflectorType: ReflectorType = .standard,
         activeGobo: GoboPattern = .none,
         diffuserAmount: Float = 0.0,
         proceduralKind: ProceduralLightKind? = nil) {
        self.lightKind = lightKind
        self.intensity = intensity
        self.colorTemperatureKelvin = colorTemperatureKelvin
        self.innerAngleDeg = innerAngleDeg
        self.outerAngleDeg = outerAngleDeg
        self.attenuationRadius = attenuationRadius
        self.shadowEnabled = shadowEnabled
        self.modelScale = modelScale
        self.reflectorType = reflectorType
        self.activeGobo = activeGobo
        self.diffuserAmount = diffuserAmount
        self.proceduralKind = proceduralKind
    }
}

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
    var customImage: UIImage?
    var poses: [SpawnPose]?
    var detailText: String?
    var selectedPose: String?
    var proceduralKind: ProceduralLightKind?
    var customModelURL: URL?
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
                title: pose.name,
                imageName: pose.imageName,
                modelFileName: pose.modelFilename ?? ""
            )
        }
        let defaultModel = character.pose.first?.modelFilename ?? character.imageName
        self.init(
            title: character.name,
            imageName: character.imageName,
            modelFileName: defaultModel,
            isBackground: false,
            UUId: character.id,
            poses: poseItems
        )
    }

    init(prop: PropItem) {
        self.init(
            title: prop.name,
            imageName: prop.imageName,
            modelFileName: prop.modelFileName ?? "",
            isBackground: false,
            UUId: prop.id ?? UUID(),
            detailText: prop.description,
            customModelURL: prop.localModelURL
        )
    }

    init(camera: CameraLibraryItem) {
        self.init(
            title: camera.name,
            imageName: camera.imageName,
            modelFileName: camera.modelFileName ?? "",
            isBackground: false,
            UUId: camera.id,
            detailText: camera.description
        )
    }

    init(light: LightItem) {
        self.init(
            title: light.name,
            imageName: light.imageName,
            modelFileName: light.modelFileName ?? "",
            isBackground: false,
            detailText: light.description,
            proceduralKind: light.proceduralKind
        )
    }

    init(background: BackgroundItem) {
        self.init(
            title: background.title,
            imageName: background.imageName,
            modelFileName: "plane",
            isBackground: true,
            UUId: background.id,
            customImage: background.customImage
        )
    }
}

// MARK: - FilmCharacter init

extension SpawnItem {

    init(filmCharacter: FilmCharacter, template: CharacterItem) {
        let poseItems = template.pose.map { pose in
            SpawnPose(
                title: pose.name,
                imageName: pose.imageName,
                modelFileName: pose.modelFilename ?? ""
            )
        }
        let selectedPoseModel =
            template.pose.first { $0.id == filmCharacter.selectedPoseId }?.modelFilename
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
