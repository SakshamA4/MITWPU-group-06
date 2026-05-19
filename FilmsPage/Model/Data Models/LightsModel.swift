import Foundation
import UIKit

// MARK: - Light Kind

/// The kind of RealityKit light this fixture uses.
enum LightKind: String, Codable, CaseIterable {
    case spot    // SpotLight — directional cone (Spotlight model)
    case panel   // SpotLight with wide cone simulating soft wash (LED Panel model)
    case point   // PointLight — omnidirectional (Lantern model)
}

// MARK: - Procedural Light Kind

/// Identifies lights built from RealityKit primitive geometry (no .usdz file).
enum ProceduralLightKind: String, Codable, CaseIterable {
    case practicalLantern
    case fluorescentTube
    case skyPanel
}

// MARK: - Gobo Pattern

/// Shadow-casting pattern projected by a spotlight via a cookie mesh.
enum GoboPattern: String, Codable, CaseIterable {
    case none
    case venetianBlinds
    case windowFrame
    case leaves
    case dots

    var textureName: String? {
        switch self {
        case .none:            return nil
        case .venetianBlinds:  return "gobo_blinds"
        case .windowFrame:     return "gobo_window"
        case .leaves:          return "gobo_leaves"
        case .dots:            return "gobo_dots"
        }
    }

    var displayName: String {
        switch self {
        case .none:            return "None"
        case .venetianBlinds:  return "Blinds"
        case .windowFrame:     return "Window"
        case .leaves:          return "Leaves"
        case .dots:            return "Dots"
        }
    }
}

// MARK: - Reflector Type

/// Named presets that set inner/outer angle pairs to simulate real-world reflectors.
enum ReflectorType: String, Codable, CaseIterable {
    case standard     // default focused spot
    case parabolic    // very tight, theatrical
    case openFace     // wide flood, no reflector feel
    case fresnel      // soft edge, classic film look

    var innerAngle: Float {
        switch self {
        case .standard:  return 10
        case .parabolic: return 5
        case .openFace:  return 45
        case .fresnel:   return 20
        }
    }
    var outerAngle: Float {
        switch self {
        case .standard:  return 30
        case .parabolic: return 15
        case .openFace:  return 80
        case .fresnel:   return 45
        }
    }

    var displayName: String {
        switch self {
        case .standard:  return "Standard"
        case .parabolic: return "Parabolic"
        case .openFace:  return "Open Face"
        case .fresnel:   return "Fresnel"
        }
    }
}

// MARK: - Light Config

/// All mutable light properties in one value type.
/// This is the config that travels from data → spawn → UI → persistence.
struct LightConfig {
    var intensity: Float                 // lumens — RealityKit's actual unit
    var colorTemperatureKelvin: Float    // 2700 = tungsten, 5600 = daylight, 7000 = cool
    var innerAngleDeg: Float             // SpotLight only — ignored for point
    var outerAngleDeg: Float             // SpotLight only — ignored for point
    var attenuationRadius: Float         // metres — how far light reaches before zero
    var shadowEnabled: Bool              // SpotLight only — PointLight cannot cast shadows in RealityKit
    var modelScale: Float                // the scale this model is spawned at (e.g. 0.01)
                                         // used to derive child counter-scale = 1.0 / modelScale
    var reflectorType: ReflectorType = .standard
    var activeGobo: GoboPattern = .none
    var diffuserAmount: Float = 0.0      // 0.0 = hard edge, 1.0 = full silk diffusion
}

// MARK: - Light Item

struct LightItem {
    let name: String
    let imageName: String
    let description: String
    var modelFileName: String?
    var lightKind: LightKind = .spot
    var isProcedural: Bool = false
    var proceduralKind: ProceduralLightKind?
    var defaultConfig: LightConfig = LightConfig(
        intensity: 200_000,
        colorTemperatureKelvin: 5600,
        innerAngleDeg: 10,
        outerAngleDeg: 30,
        attenuationRadius: 10,
        shadowEnabled: false,
        modelScale: 0.01
    )
}

// MARK: - Light Data Store

struct LightsDataStore {

    private(set) static var items: [LightItem] = [
        LightItem(
            name: "LED Panel",
            imageName: "LED Panel_img",
            description: "Soft, even light source ideal for key or fill.",
            modelFileName: "LED Panel",
            lightKind: .panel,
            defaultConfig: LightConfig(
                intensity: 400_000,
                colorTemperatureKelvin: 5600,
                innerAngleDeg: 50,
                outerAngleDeg: 100,
                attenuationRadius: 6,
                shadowEnabled: false,
                modelScale: 0.01
            )
        ),
        LightItem(
            name: "Lantern",
            imageName: "Lantern_img",
            description: "Soft omnidirectional light often used as a hanging practical.",
            modelFileName: "Lantern 2",
            lightKind: .point,
            defaultConfig: LightConfig(
                intensity: 500_000,
                colorTemperatureKelvin: 2700,
                innerAngleDeg: 0,
                outerAngleDeg: 0,
                attenuationRadius: 6,
                shadowEnabled: false,
                modelScale: 0.0025
            )
        ),
        LightItem(
            name: "Spotlight",
            imageName: "Spotlight_img 1",
            description: "Narrow beam for highlighting specific areas or subjects.",
            modelFileName: "Spotlight",
            lightKind: .spot,
            defaultConfig: LightConfig(
                intensity: 300_000,
                colorTemperatureKelvin: 5600,
                innerAngleDeg: 15,
                outerAngleDeg: 35,
                attenuationRadius: 4,
                shadowEnabled: false,
                modelScale: 0.01
            )
        ),

        // ── Procedural lights (no .usdz — geometry built from RealityKit primitives) ──

        LightItem(
            name: "Practical Lantern",
            imageName: "practical lantern",
            description: "Round paper lantern practical — soft omnidirectional warm glow.",
            modelFileName: nil,
            lightKind: .point,
            isProcedural: true,
            proceduralKind: .practicalLantern,
            defaultConfig: LightConfig(
                intensity: 150_000,
                colorTemperatureKelvin: 2700,
                innerAngleDeg: 0,
                outerAngleDeg: 0,
                attenuationRadius: 4,
                shadowEnabled: false,
                modelScale: 1.0
            )
        ),
        LightItem(
            name: "Fluorescent Tube",
            imageName: "Fluorescent tube",
            description: "Long horizontal strip light — soft cool linear wash.",
            modelFileName: nil,
            lightKind: .panel,
            isProcedural: true,
            proceduralKind: .fluorescentTube,
            defaultConfig: LightConfig(
                intensity: 200_000,
                colorTemperatureKelvin: 6500,
                innerAngleDeg: 60,
                outerAngleDeg: 110,
                attenuationRadius: 5,
                shadowEnabled: false,
                modelScale: 1.0
            )
        ),
        LightItem(
            name: "Sky Panel",
            imageName: "sky panel",
            description: "Large flat rectangular soft panel — powerful wide soft wash.",
            modelFileName: nil,
            lightKind: .panel,
            isProcedural: true,
            proceduralKind: .skyPanel,
            defaultConfig: LightConfig(
                intensity: 500_000,
                colorTemperatureKelvin: 5600,
                innerAngleDeg: 50,
                outerAngleDeg: 100,
                attenuationRadius: 8,
                shadowEnabled: false,
                modelScale: 1.0
            )
        )
    ]

    // Optional: add new lights later
    static func addLight(name: String, imageName: String, description: String) {
        let newLight = LightItem(name: name, imageName: imageName, description: description)
        items.append(newLight)
    }

    /// Look up a light item by its model file name (e.g. "Spotlight", "LED Panel", "Lantern 2").
    /// Used by the router and persistence fallback path.
    static func find(byModelFileName name: String) -> LightItem? {
        items.first { $0.modelFileName == name }
    }

    /// Look up a procedural light item by its kind.
    /// Used by persistence restore path and spawn routing.
    static func find(byProceduralKind kind: ProceduralLightKind) -> LightItem? {
        items.first { $0.proceduralKind == kind }
    }
}

// MARK: - Diffuser Helper

/// Applies diffusion by adjusting the inner/outer angle ratio.
/// diffuserAmount 0.0 → hard edge (inner close to outer)
/// diffuserAmount 1.0 → full silk (inner = 10% of outer — very soft gradual falloff)
func applyDiffuser(to config: inout LightConfigComponent) {
    let hardInner = config.outerAngleDeg - 5.0
    let softInner = config.outerAngleDeg * 0.1
    config.innerAngleDeg = hardInner + (softInner - hardInner) * config.diffuserAmount
    config.innerAngleDeg = max(1.0, config.innerAngleDeg)
}

// MARK: - UIColor Kelvin Extension

extension UIColor {
    /// Converts a colour temperature in Kelvin to an approximate RGB UIColor.
    /// Algorithm: Tanner Helland (2012), verified accurate 1000K–40000K.
    static func fromKelvin(_ kelvin: Float) -> UIColor {
        let temp = Double(kelvin) / 100.0
        let r, g, b: Double

        // Red
        if temp <= 66 {
            r = 255
        } else {
            r = min(max(329.698727446 * pow(temp - 60, -0.1332047592), 0), 255)
        }

        // Green
        if temp <= 66 {
            g = min(max(99.4708025861 * log(temp) - 161.1195681661, 0), 255)
        } else {
            g = min(max(288.1221695283 * pow(temp - 60, -0.0755148492), 0), 255)
        }

        // Blue
        if temp >= 66 {
            b = 255
        } else if temp <= 19 {
            b = 0
        } else {
            b = min(max(138.5177312231 * log(temp - 10) - 305.0447927307, 0), 255)
        }

        return UIColor(
            red: CGFloat(r / 255),
            green: CGFloat(g / 255),
            blue: CGFloat(b / 255),
            alpha: 1.0
        )
    }
}
