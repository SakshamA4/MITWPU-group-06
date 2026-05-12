//
//  CinematicMaterialManager.swift
//  FilmsPage
//
//  Singleton that builds RealityKit PhysicallyBasedMaterial from a
//  CinematicMaterialConfig. Handles texture creation, caching,
//  and live parameter updates.
//

import RealityKit
import UIKit

// MARK: - CinematicMaterialManager

@MainActor
final class CinematicMaterialManager {

    static let shared = CinematicMaterialManager()

    /// Cache of TextureResource objects keyed by presetID+tint for reuse.
    private var textureResourceCache: [String: TextureResource] = [:]

    private init() {}

    // MARK: - Build Material (async)

    /// Creates a `PhysicallyBasedMaterial` from the given config.
    /// Uses cached TextureResources when available.
    func buildMaterial(from config: CinematicMaterialConfig) async throws -> RealityKit.Material {
        // Glass / transparent special handling
        if config.presetID == "glass" || config.opacity < 0.95 {
            return try await buildGlassMaterial(from: config)
        }

        var material = PhysicallyBasedMaterial()

        // Base color texture
        let texture = try await textureResource(for: config)
        material.baseColor = .init(tint: config.tintColor, texture: .init(texture))

        // PBR parameters
        material.roughness = .init(floatLiteral: config.roughness)
        material.metallic  = .init(floatLiteral: config.metallic)

        // Opacity (only if not fully opaque)
        if config.opacity < 0.99 {
            material.blending = .transparent(opacity: .init(floatLiteral: config.opacity))
        }

        return material
    }

    /// Builds a transparent glass material.
    private func buildGlassMaterial(from config: CinematicMaterialConfig) async throws -> RealityKit.Material {
        var material = PhysicallyBasedMaterial()

        // Glass texture
        let texture = try await textureResource(for: config)
        material.baseColor = .init(
            tint: config.tintColor.withAlphaComponent(CGFloat(config.opacity)),
            texture: .init(texture)
        )

        material.roughness = .init(floatLiteral: config.roughness)
        material.metallic  = .init(floatLiteral: config.metallic)
        material.blending  = .transparent(opacity: .init(floatLiteral: config.opacity))

        return material
    }

    // MARK: - Build Material (sync fallback)

    /// Creates a SimpleMaterial as a synchronous fallback when async isn't possible.
    /// Used during restore when TextureResource creation may fail.
    func buildSimpleMaterial(from config: CinematicMaterialConfig) -> RealityKit.Material {
        // SimpleMaterial handles transparency via the color's alpha channel.
        let color = config.opacity < 0.95
            ? config.tintColor.withAlphaComponent(CGFloat(config.opacity))
            : config.tintColor
        return SimpleMaterial(color: color,
                              roughness: MaterialScalarParameter(floatLiteral: config.roughness),
                              isMetallic: config.metallic > 0.5)
    }

    // MARK: - Apply Material to Entity

    /// Applies a material config to an existing ModelEntity.
    /// Async — rebuilds the full PBR material and swaps it.
    func applyMaterial(_ config: CinematicMaterialConfig, to entity: ModelEntity) async {
        do {
            let material = try await buildMaterial(from: config)
            entity.model?.materials = [material]
        } catch {
            print("⚠️ CinematicMaterialManager: Failed to apply material — \(error)")
            // Fallback to simple material
            entity.model?.materials = [buildSimpleMaterial(from: config)]
        }
    }

    // MARK: - Texture Resource Cache

    private func textureResource(for config: CinematicMaterialConfig) async throws -> TextureResource {
        let cacheKey = "\(config.presetID)_\(config.tintColor.cgColor.components?.description ?? "")"

        if let cached = textureResourceCache[cacheKey] {
            return cached
        }

        let image = ProceduralTextureGenerator.shared.texture(
            for: config.presetID,
            tint: config.tintColor
        )

        let cgImage = image.sRGBCGImage()
        let resource = try await TextureResource(
            image: cgImage,
            options: .init(semantic: .color)
        )

        textureResourceCache[cacheKey] = resource
        return resource
    }

    // MARK: - Cache Management

    /// Clears texture resource cache (for memory pressure).
    func clearCache() {
        textureResourceCache.removeAll()
        ProceduralTextureGenerator.shared.clearCache()
    }

    /// Evicts a specific texture from cache.
    func evictTexture(for presetID: String) {
        textureResourceCache = textureResourceCache.filter { !$0.key.hasPrefix(presetID) }
    }
}
