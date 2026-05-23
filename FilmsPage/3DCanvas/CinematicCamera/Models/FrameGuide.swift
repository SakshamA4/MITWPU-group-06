//
//  FrameGuide.swift
//  FilmsPage
//
//  Frame guide overlay types and configuration for the cinematic
//  camera viewport. Extends the existing GridType system with
//  professional cinema-standard guides.
//

import Foundation
import UIKit

// MARK: - Frame Guide Type

/// Professional frame guide overlays for cinematic composition.
/// These extend beyond the existing GridType to include cinema-standard
/// composition and safety guides.
enum FrameGuideType: String, Codable, CaseIterable, Identifiable {
    case thirds        = "Rule of Thirds"
    case centerCross   = "Center Cross"
    case diagonal      = "Diagonal"
    case goldenRatio   = "Golden Ratio"
    case goldenSpiral  = "Golden Spiral"
    case actionSafe    = "Action Safe"
    case titleSafe     = "Title Safe"
    case crosshair     = "Crosshair"
    case horizon       = "Horizon"
    case fibonacci     = "Fibonacci"

    var id: String { rawValue }

    /// SF Symbol icon for the picker UI
    var iconSystemName: String {
        switch self {
        case .thirds:      return "square.grid.3x3"
        case .centerCross: return "plus"
        case .diagonal:    return "arrow.up.right.and.arrow.down.left"
        case .goldenRatio: return "seal"
        case .goldenSpiral:return "hurricane"
        case .actionSafe:  return "rectangle.inset.filled"
        case .titleSafe:   return "textformat.size"
        case .crosshair:   return "scope"
        case .horizon:     return "minus"
        case .fibonacci:   return "circle.grid.cross"
        }
    }

    /// Short description for tooltips
    var description: String {
        switch self {
        case .thirds:       return "Classic 3×3 composition grid"
        case .centerCross:  return "Vertical and horizontal center lines"
        case .diagonal:     return "Corner-to-corner diagonal lines"
        case .goldenRatio:  return "φ ratio grid (1:1.618)"
        case .goldenSpiral: return "Fibonacci spiral overlay"
        case .actionSafe:   return "Broadcast action-safe boundary"
        case .titleSafe:    return "Broadcast title-safe boundary"
        case .crosshair:    return "Precise center point marker"
        case .horizon:      return "Horizontal level reference"
        case .fibonacci:    return "Fibonacci sequence grid"
        }
    }

    /// Whether this guide type uses a dashed line style
    var isDashed: Bool {
        switch self {
        case .actionSafe, .titleSafe: return true
        default: return false
        }
    }

    /// Line opacity for this guide type (some should be more subtle)
    var defaultOpacity: Float {
        switch self {
        case .thirds, .goldenRatio, .fibonacci: return 0.35
        case .centerCross, .crosshair:          return 0.30
        case .diagonal:                         return 0.25
        case .actionSafe, .titleSafe:           return 0.40
        case .goldenSpiral:                     return 0.30
        case .horizon:                          return 0.25
        }
    }
}

// MARK: - Frame Guide Configuration

/// Per-camera frame guide configuration. Stored as an ECS component
/// to persist guide visibility per virtual camera.
struct FrameGuideConfig: Codable, Hashable {

    /// Which guides are currently active/visible
    var activeGuides: Set<FrameGuideType> = []

    /// Global opacity multiplier for all guides (0.0–1.0)
    var globalOpacity: Float = 0.5

    /// Guide line color (RGBA)
    var guideColorR: Float = 1.0
    var guideColorG: Float = 1.0
    var guideColorB: Float = 1.0
    var guideColorA: Float = 0.4

    /// Guide line width in points
    var lineWidth: Float = 0.5

    /// Whether to show the letterbox/pillarbox bars
    var showLetterbox: Bool = true

    /// Letterbox bar opacity (0.0–1.0)
    var letterboxOpacity: Float = 1.0

    // MARK: - Convenience

    /// Guide line UIColor
    var guideColor: UIColor {
        get {
            UIColor(red: CGFloat(guideColorR), green: CGFloat(guideColorG),
                    blue: CGFloat(guideColorB), alpha: CGFloat(guideColorA * globalOpacity))
        }
        set {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            newValue.getRed(&r, green: &g, blue: &b, alpha: &a)
            guideColorR = Float(r); guideColorG = Float(g)
            guideColorB = Float(b); guideColorA = Float(a)
        }
    }

    /// Whether any guide is currently active
    var hasActiveGuides: Bool { !activeGuides.isEmpty }

    /// Toggle a specific guide on/off
    mutating func toggleGuide(_ guide: FrameGuideType) {
        if activeGuides.contains(guide) {
            activeGuides.remove(guide)
        } else {
            activeGuides.insert(guide)
        }
    }

    /// Remove all active guides
    mutating func clearAllGuides() {
        activeGuides.removeAll()
    }

    // MARK: - Presets

    /// Clean — no guides
    static let clean = FrameGuideConfig()

    /// Director — thirds + center cross
    static let director: FrameGuideConfig = {
        var config = FrameGuideConfig()
        config.activeGuides = [.thirds, .centerCross]
        return config
    }()

    /// Broadcast — safe areas + thirds
    static let broadcast: FrameGuideConfig = {
        var config = FrameGuideConfig()
        config.activeGuides = [.thirds, .actionSafe, .titleSafe]
        return config
    }()

    /// Composition — golden ratio + center
    static let composition: FrameGuideConfig = {
        var config = FrameGuideConfig()
        config.activeGuides = [.goldenRatio, .crosshair]
        return config
    }()
}

// MARK: - Golden Ratio Constant

/// The golden ratio φ = (1 + √5) / 2 ≈ 1.618033988749895
let kGoldenRatio: Float = 1.618033988749895
