//
//  GripEquipmentModel.swift
//  3DCanvas
//
//  Additive-only: Defines SceneReflectorType and DiffuserType enums,
//  ECS marker components, and procedural entity builder functions
//  for grip equipment (reflectors, diffusers) placed as scene props.
//

import Foundation
import UIKit
import RealityKit

// MARK: - Scene Reflector Type
//
// NOTE: This is separate from `ReflectorType` in LightsModel.swift,
// which controls spotlight beam-angle presets (Standard, Parabolic, etc.).
// SceneReflectorType represents a physical reflector *prop* in the scene.

enum SceneReflectorType: String, CaseIterable, Codable {
    case flatSilver  = "flatSilver"
    case flatWhite   = "flatWhite"
    case flatGold    = "flatGold"
    case flag        = "flag"
    case convex      = "convex"

    var displayName: String {
        switch self {
        case .flatSilver: return "Flat Silver"
        case .flatWhite:  return "Flat White"
        case .flatGold:   return "Flat Gold"
        case .flag:       return "Flag (Black)"
        case .convex:     return "Convex Silver"
        }
    }

    /// Icon displayed in the Grip picker card.
    var iconName: String {
        switch self {
        case .flatSilver: return "rectangle.fill"
        case .flatWhite:  return "rectangle"
        case .flatGold:   return "rectangle.fill"
        case .flag:       return "rectangle.fill"
        case .convex:     return "rectangle.inset.filled"
        }
    }

    /// Swatch color for the Grip picker card.
    var swatchColor: UIColor {
        switch self {
        case .flatSilver: return UIColor(white: 0.85, alpha: 1.0)
        case .flatWhite:  return .white
        case .flatGold:   return UIColor(red: 1.0, green: 0.78, blue: 0.3, alpha: 1.0)
        case .flag:       return .black
        case .convex:     return UIColor(white: 0.85, alpha: 1.0)
        }
    }

    /// Plane dimensions in metres (width × depth).
    var planeSize: (width: Float, depth: Float) {
        switch self {
        case .flatSilver, .flatWhite, .flatGold, .flag:
            return (1.0, 1.5)    // ~100 × 150 cm standard reflector
        case .convex:
            return (1.2, 1.8)    // 120 × 180 cm oversize
        }
    }

    /// Material properties for the reflector surface.
    var materialConfig: (metallic: Float, roughness: Float, color: UIColor) {
        switch self {
        case .flatSilver: return (1.0, 0.1, .white)
        case .flatWhite:  return (0.0, 0.95, .white)
        case .flatGold:   return (1.0, 0.15, UIColor(red: 1.0, green: 0.78, blue: 0.3, alpha: 1.0))
        case .flag:       return (0.0, 1.0, .black)
        case .convex:     return (1.0, 0.1, .white)
        }
    }
}

// MARK: - Diffuser Type

enum DiffuserType: String, CaseIterable, Codable {
    case silk       = "silk"
    case lightGrid  = "lightGrid"
    case heavyFrost = "heavyFrost"
    case butterfly  = "butterfly"

    var displayName: String {
        switch self {
        case .silk:       return "Silk"
        case .lightGrid:  return "Light Grid"
        case .heavyFrost: return "Heavy Frost"
        case .butterfly:  return "Butterfly (6×6)"
        }
    }

    /// Icon for Grip picker card.
    var iconName: String {
        switch self {
        case .silk:       return "square.dashed"
        case .lightGrid:  return "grid"
        case .heavyFrost: return "square.fill"
        case .butterfly:  return "square.split.2x2"
        }
    }

    /// Swatch color for Grip picker card.
    var swatchColor: UIColor {
        return UIColor.white.withAlphaComponent(0.5)
    }

    /// Plane dimensions in metres (width × depth).
    var planeSize: (width: Float, depth: Float) {
        switch self {
        case .silk, .lightGrid, .heavyFrost:
            return (1.2, 1.2)    // 4×4 frame
        case .butterfly:
            return (1.8, 1.8)    // 6×6 frame
        }
    }
}

// MARK: - ECS Marker Components

/// Marks an entity as a scene reflector prop.
struct SceneReflectorComponent: Component {
    let type: SceneReflectorType
}

/// Marks an entity as a diffuser prop.
struct DiffuserComponent: Component {
    let type: DiffuserType
}

// MARK: - Entity Builders

/// Builds a procedural reflector entity (flat plane with appropriate material).
func buildReflectorEntity(type: SceneReflectorType) -> ModelEntity {
    let size = type.planeSize
    let config = type.materialConfig

    let material = SimpleMaterial(
        color: config.color,
        roughness: .float(config.roughness),
        isMetallic: config.metallic > 0.5
    )

    let mesh = MeshResource.generatePlane(width: size.width, depth: size.depth)
    let entity = ModelEntity(mesh: mesh, materials: [material])

    // Stand the reflector upright (default plane is in XZ; rotate to XY facing forward)
    entity.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])

    // Add a thin frame border for visual definition
    let frameMat = SimpleMaterial(color: UIColor(white: 0.3, alpha: 1.0), roughness: 0.5, isMetallic: true)
    let frameThickness: Float = 0.02
    let frameDepth: Float = 0.03

    // Top bar
    let topBar = ModelEntity(
        mesh: .generateBox(width: size.width + frameThickness * 2, height: frameThickness, depth: frameDepth),
        materials: [frameMat]
    )
    topBar.position = [0, size.depth / 2 + frameThickness / 2, 0]
    entity.addChild(topBar)

    // Bottom bar
    let bottomBar = ModelEntity(
        mesh: .generateBox(width: size.width + frameThickness * 2, height: frameThickness, depth: frameDepth),
        materials: [frameMat]
    )
    bottomBar.position = [0, -(size.depth / 2 + frameThickness / 2), 0]
    entity.addChild(bottomBar)

    // Left bar
    let leftBar = ModelEntity(
        mesh: .generateBox(width: frameThickness, height: size.depth, depth: frameDepth),
        materials: [frameMat]
    )
    leftBar.position = [-(size.width / 2 + frameThickness / 2), 0, 0]
    entity.addChild(leftBar)

    // Right bar
    let rightBar = ModelEntity(
        mesh: .generateBox(width: frameThickness, height: size.depth, depth: frameDepth),
        materials: [frameMat]
    )
    rightBar.position = [size.width / 2 + frameThickness / 2, 0, 0]
    entity.addChild(rightBar)

    // Scale down to scene-friendly size
    entity.scale = SIMD3<Float>(repeating: 0.25)

    entity.components.set(SceneReflectorComponent(type: type))

    return entity
}

/// Builds a procedural diffuser entity (translucent flat plane).
func buildDiffuserEntity(type: DiffuserType) -> ModelEntity {
    let size = type.planeSize

    var material = PhysicallyBasedMaterial()
    material.baseColor = .init(tint: UIColor.white.withAlphaComponent(0.35))
    material.roughness = .init(floatLiteral: 1.0)
    material.metallic  = .init(floatLiteral: 0.0)
    material.blending  = .transparent(opacity: .init(floatLiteral: 0.35))

    let mesh = MeshResource.generatePlane(width: size.width, depth: size.depth)
    let entity = ModelEntity(mesh: mesh, materials: [material])

    // Stand upright (XZ plane → XY plane)
    entity.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])

    // Frame — lightweight aluminium tubing look
    let frameMat = SimpleMaterial(color: UIColor(white: 0.6, alpha: 1.0), roughness: 0.3, isMetallic: true)
    let frameThickness: Float = 0.015
    let frameDepth: Float = 0.025

    let topBar = ModelEntity(
        mesh: .generateBox(width: size.width + frameThickness * 2, height: frameThickness, depth: frameDepth),
        materials: [frameMat]
    )
    topBar.position = [0, size.depth / 2 + frameThickness / 2, 0]
    entity.addChild(topBar)

    let bottomBar = ModelEntity(
        mesh: .generateBox(width: size.width + frameThickness * 2, height: frameThickness, depth: frameDepth),
        materials: [frameMat]
    )
    bottomBar.position = [0, -(size.depth / 2 + frameThickness / 2), 0]
    entity.addChild(bottomBar)

    let leftBar = ModelEntity(
        mesh: .generateBox(width: frameThickness, height: size.depth, depth: frameDepth),
        materials: [frameMat]
    )
    leftBar.position = [-(size.width / 2 + frameThickness / 2), 0, 0]
    entity.addChild(leftBar)

    let rightBar = ModelEntity(
        mesh: .generateBox(width: frameThickness, height: size.depth, depth: frameDepth),
        materials: [frameMat]
    )
    rightBar.position = [size.width / 2 + frameThickness / 2, 0, 0]
    entity.addChild(rightBar)

    // Scale down
    entity.scale = SIMD3<Float>(repeating: 0.25)

    entity.components.set(DiffuserComponent(type: type))

    return entity
}
