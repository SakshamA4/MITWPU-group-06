import Foundation
import UIKit

// MARK: - Light Kind

/// The kind of RealityKit light this fixture uses.
enum LightKind: String, Codable, CaseIterable {
    case spot    // SpotLight — directional cone (Spotlight model)
    case panel   // SpotLight with wide cone simulating soft wash (LED Panel model)
    case point   // PointLight — omnidirectional (Lantern model)
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
}

// MARK: - Light Item

struct LightItem {
    let name: String
    let imageName: String
    let description: String
    var modelFileName: String? = nil
    var lightKind: LightKind = .spot
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
                intensity: 200_000,
                colorTemperatureKelvin: 5600,    // daylight white — matches current .white
                innerAngleDeg: 65,
                outerAngleDeg: 110,
                attenuationRadius: 10,
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
                intensity: 100_000,
                colorTemperatureKelvin: 2700,    // warm tungsten — matches current .systemYellow
                innerAngleDeg: 0,                // unused for point light
                outerAngleDeg: 0,                // unused for point light
                attenuationRadius: 5,
                shadowEnabled: false,            // PointLight cannot cast shadows in RealityKit — engine limit
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
                intensity: 200_000,
                colorTemperatureKelvin: 5600,
                innerAngleDeg: 10,
                outerAngleDeg: 30,
                attenuationRadius: 5,       // was 20 — large values corrupt shadow map in non-AR mode
                shadowEnabled: false,        // was true — shadows are opt-in to avoid scene corruption
                modelScale: 0.01
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
            red:   CGFloat(r / 255),
            green: CGFloat(g / 255),
            blue:  CGFloat(b / 255),
            alpha: 1.0
        )
    }
}
