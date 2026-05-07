//
//  TexturePreset.swift
//  FilmsPage
//
//  Defines all available texture presets with metadata, categories,
//  and default PBR values. Provides a static library for querying
//  presets by category or ID.
//

import Foundation

// MARK: - TextureCategory

enum TextureCategory: String, CaseIterable, Identifiable, Codable {
    case stone       = "Stone"
    case urban       = "Urban"
    case natural     = "Natural"
    case industrial  = "Industrial"
    case studio      = "Studio"
    case special     = "Special"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .stone:      return "mountain.2.fill"
        case .urban:      return "building.2.fill"
        case .natural:    return "leaf.fill"
        case .industrial: return "gearshape.2.fill"
        case .studio:     return "film.fill"
        case .special:    return "sparkles"
        }
    }
}

// MARK: - TexturePreset

struct TexturePreset: Identifiable, Hashable {
    let id: String
    let name: String
    let category: TextureCategory
    let icon: String
    let defaultRoughness: Float
    let defaultMetallic: Float
    let defaultOpacity: Float
    let defaultReflection: Float
    let supportsTransparency: Bool

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: TexturePreset, rhs: TexturePreset) -> Bool { lhs.id == rhs.id }
}

// MARK: - TexturePresetLibrary

struct TexturePresetLibrary {

    // MARK: All Presets

    static let all: [TexturePreset] = [
        // Stone
        TexturePreset(id: "concrete",  name: "Concrete",  category: .stone,      icon: "square.fill",           defaultRoughness: 0.85, defaultMetallic: 0.0,  defaultOpacity: 1.0, defaultReflection: 0.05, supportsTransparency: false),
        TexturePreset(id: "marble",    name: "Marble",    category: .stone,      icon: "diamond.fill",          defaultRoughness: 0.25, defaultMetallic: 0.0,  defaultOpacity: 1.0, defaultReflection: 0.4,  supportsTransparency: false),

        // Urban
        TexturePreset(id: "brick",     name: "Brick",     category: .urban,      icon: "rectangle.grid.2x2.fill", defaultRoughness: 0.9,  defaultMetallic: 0.0,  defaultOpacity: 1.0, defaultReflection: 0.02, supportsTransparency: false),
        TexturePreset(id: "asphalt",   name: "Asphalt",   category: .urban,      icon: "road.lanes",            defaultRoughness: 0.95, defaultMetallic: 0.0,  defaultOpacity: 1.0, defaultReflection: 0.08, supportsTransparency: false),

        // Natural
        TexturePreset(id: "grass",     name: "Grass",     category: .natural,    icon: "leaf.fill",             defaultRoughness: 0.95, defaultMetallic: 0.0,  defaultOpacity: 1.0, defaultReflection: 0.02, supportsTransparency: false),
        TexturePreset(id: "sand",      name: "Sand",      category: .natural,    icon: "sun.max.fill",          defaultRoughness: 0.9,  defaultMetallic: 0.0,  defaultOpacity: 1.0, defaultReflection: 0.05, supportsTransparency: false),
        TexturePreset(id: "dirt",      name: "Dirt",      category: .natural,    icon: "mountain.2.fill",       defaultRoughness: 0.95, defaultMetallic: 0.0,  defaultOpacity: 1.0, defaultReflection: 0.01, supportsTransparency: false),
        TexturePreset(id: "snow",      name: "Snow",      category: .natural,    icon: "snowflake",             defaultRoughness: 0.6,  defaultMetallic: 0.0,  defaultOpacity: 1.0, defaultReflection: 0.3,  supportsTransparency: false),

        // Industrial
        TexturePreset(id: "metal",     name: "Metal",     category: .industrial, icon: "hammer.fill",           defaultRoughness: 0.35, defaultMetallic: 0.9,  defaultOpacity: 1.0, defaultReflection: 0.6,  supportsTransparency: false),
        TexturePreset(id: "industrial",name: "Industrial", category: .industrial,icon: "gearshape.fill",        defaultRoughness: 0.7,  defaultMetallic: 0.5,  defaultOpacity: 1.0, defaultReflection: 0.2,  supportsTransparency: false),

        // Studio
        TexturePreset(id: "studioFloor", name: "Studio Floor", category: .studio, icon: "film.fill",           defaultRoughness: 0.4,  defaultMetallic: 0.0,  defaultOpacity: 1.0, defaultReflection: 0.3,  supportsTransparency: false),

        // Special
        TexturePreset(id: "glass",     name: "Glass",     category: .special,    icon: "rectangle.fill",        defaultRoughness: 0.05, defaultMetallic: 0.0,  defaultOpacity: 0.3, defaultReflection: 0.8,  supportsTransparency: true),
        TexturePreset(id: "neon",      name: "Neon",      category: .special,    icon: "bolt.fill",             defaultRoughness: 0.2,  defaultMetallic: 0.3,  defaultOpacity: 1.0, defaultReflection: 0.5,  supportsTransparency: false),
    ]

    // MARK: Lookup

    static func preset(for id: String) -> TexturePreset? {
        all.first { $0.id == id }
    }

    static func presets(in category: TextureCategory) -> [TexturePreset] {
        all.filter { $0.category == category }
    }

    // MARK: Context-specific subsets

    /// Presets appropriate for walls
    static let wallPresets: [TexturePreset] = all.filter {
        ["concrete", "brick", "marble", "metal", "glass", "industrial", "neon", "studioFloor"].contains($0.id)
    }

    /// Presets appropriate for ground/floor
    static let groundPresets: [TexturePreset] = all.filter {
        ["grass", "sand", "dirt", "asphalt", "snow", "concrete", "studioFloor"].contains($0.id)
    }

    /// Wall categories (ordered for UI)
    static let wallCategories: [TextureCategory] = [.stone, .urban, .industrial, .studio, .special]

    /// Ground categories (ordered for UI)
    static let groundCategories: [TextureCategory] = [.natural, .urban, .studio]
}
