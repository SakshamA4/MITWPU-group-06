//
//  CinematicMaterialConfig.swift
//  FilmsPage
//
//  Codable model for all cinematic material properties.
//  Used by WallComponent and GroundComponent to drive PBR rendering.
//

import UIKit

// MARK: - CinematicMaterialConfig

struct CinematicMaterialConfig: Codable, Equatable, Hashable {

    /// Identifier linking to a `TexturePreset.id` (e.g. "concrete", "brick").
    var presetID: String = "concrete"

    /// PBR roughness: 0 = mirror, 1 = fully rough.
    var roughness: Float = 0.7

    /// PBR metallic: 0 = dielectric, 1 = metal.
    var metallic: Float = 0.0

    /// Surface opacity: 0 = invisible, 1 = fully opaque.
    var opacity: Float = 1.0

    /// Texture tiling multiplier. 1 = 1:1 mapping, 2 = texture repeats 2× per metre.
    var tilingScale: Float = 1.0

    /// Tint RGBA applied on top of the procedural texture.
    var tintR: Float = 1.0
    var tintG: Float = 1.0
    var tintB: Float = 1.0
    var tintA: Float = 1.0

    /// Environment reflection intensity: 0 = none, 1 = full mirror.
    var reflectionIntensity: Float = 0.0

    // MARK: - Convenience

    var tintColor: UIColor {
        get { UIColor(red: CGFloat(tintR), green: CGFloat(tintG), blue: CGFloat(tintB), alpha: CGFloat(tintA)) }
        set {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            newValue.getRed(&r, green: &g, blue: &b, alpha: &a)
            tintR = Float(r); tintG = Float(g); tintB = Float(b); tintA = Float(a)
        }
    }

    /// Returns a config initialised from a `TexturePreset`'s defaults.
    static func from(preset: TexturePreset) -> CinematicMaterialConfig {
        CinematicMaterialConfig(
            presetID:             preset.id,
            roughness:            preset.defaultRoughness,
            metallic:             preset.defaultMetallic,
            opacity:              preset.defaultOpacity,
            tilingScale:          1.0,
            tintR: 1, tintG: 1, tintB: 1, tintA: 1,
            reflectionIntensity:  preset.defaultReflection
        )
    }
}
