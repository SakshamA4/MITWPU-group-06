//
//  CinematicLook.swift
//  FilmsPage
//
//  Cinematic look and LUT model definitions for the color grading
//  pipeline. Separates creative grading from technical camera/lens
//  simulation. Supports both built-in looks and custom LUT import.
//

import Foundation
import UIKit

// MARK: - Cinematic Look Category

/// Categories for organising cinematic looks in the picker UI.
enum CinematicLookCategory: String, Codable, CaseIterable, Identifiable {
    case filmStock = "Film Stock"
    case digital   = "Digital"
    case vintage   = "Vintage"
    case stylised  = "Stylised"
    case custom    = "Custom LUT"

    var id: String { rawValue }

    var iconSystemName: String {
        switch self {
        case .filmStock: return "film"
        case .digital:   return "camera.aperture"
        case .vintage:   return "clock.arrow.circlepath"
        case .stylised:  return "paintbrush"
        case .custom:    return "doc.badge.plus"
        }
    }
}

// MARK: - Cinematic Look

/// A complete cinematic look preset that defines the creative color grading
/// applied on top of the technical camera/lens simulation.
///
/// The look pipeline is intentionally separate from lens optical effects:
/// - Lens simulation = physical (distortion, vignette, CA)
/// - Look pipeline = creative (color, contrast, grain, bloom)
struct CinematicLook: Codable, Hashable, Identifiable {
    let id: String

    /// Display name (e.g. "Kodak 5219", "Zeiss Clinical")
    let name: String

    /// Category for UI organisation
    let category: CinematicLookCategory

    /// Short description of the look's character
    let character: String

    // ── Color Grading ──────────────────────────────────────────────────────

    /// Global warmth shift. -1.0 = cool/blue, 0.0 = neutral, 1.0 = warm/amber
    var warmth: Float = 0.0

    /// Tint shift on the green–magenta axis. -1.0 = green, 1.0 = magenta
    var tint: Float = 0.0

    /// Saturation multiplier. 0.0 = monochrome, 1.0 = natural, 2.0 = vivid
    var saturation: Float = 1.0

    /// Vibrance — selective saturation that protects already-saturated colors.
    /// 0.0 = no boost, 1.0 = maximum boost
    var vibrance: Float = 0.0

    // ── Tonal Response ─────────────────────────────────────────────────────

    /// Contrast intensity. 0.0 = flat, 1.0 = natural, 2.0 = punchy
    var contrast: Float = 1.0

    /// Highlight rolloff — how gently highlights compress.
    /// 0.0 = hard clip, 1.0 = very soft shoulder (film-like)
    var highlightRolloff: Float = 0.5

    /// Shadow lift — raises the black point for a faded/milky look.
    /// 0.0 = true blacks, 1.0 = heavily lifted shadows
    var shadowLift: Float = 0.0

    /// Midtone exposure adjustment. -1.0 to 1.0 stops
    var midtoneShift: Float = 0.0

    // ── Film Effects ───────────────────────────────────────────────────────

    /// Bloom / glow intensity (creative, separate from lens bloom).
    /// 0.0 = none, 1.0 = heavy dreamlike bloom
    var bloomIntensity: Float = 0.0

    /// Halation intensity (warm highlight bleed, film-like).
    /// 0.0 = none, 1.0 = heavy
    var halationIntensity: Float = 0.0

    /// Film grain intensity. 0.0 = none, 1.0 = heavy visible grain
    var grainIntensity: Float = 0.0

    /// Film grain size. 0.0 = fine grain, 1.0 = coarse grain
    var grainSize: Float = 0.5

    // ── Color Tint ─────────────────────────────────────────────────────────

    /// Shadow tint color (RGBA, applied to darkest areas)
    var shadowTintR: Float = 0.0
    var shadowTintG: Float = 0.0
    var shadowTintB: Float = 0.0

    /// Highlight tint color (RGBA, applied to brightest areas)
    var highlightTintR: Float = 0.0
    var highlightTintG: Float = 0.0
    var highlightTintB: Float = 0.0

    // ── LUT Reference ──────────────────────────────────────────────────────

    /// Optional reference to a LUT file for this look.
    /// If set, the LUT is applied after all parametric adjustments.
    var lutFileReference: String? = nil

    /// LUT application intensity. 0.0 = no LUT, 1.0 = full LUT
    var lutIntensity: Float = 1.0

    // ── Convenience ────────────────────────────────────────────────────────

    var shadowTintColor: UIColor {
        UIColor(red: CGFloat(shadowTintR), green: CGFloat(shadowTintG),
                blue: CGFloat(shadowTintB), alpha: 1.0)
    }

    var highlightTintColor: UIColor {
        UIColor(red: CGFloat(highlightTintR), green: CGFloat(highlightTintG),
                blue: CGFloat(highlightTintB), alpha: 1.0)
    }
}

// MARK: - LUT Format

/// Supported LUT file formats for import.
enum LUTFormat: String, Codable, CaseIterable {
    case cube = "cube"
    case threeDL = "3dl"

    var fileExtension: String { rawValue }

    var displayName: String {
        switch self {
        case .cube:    return ".cube (Adobe / Resolve)"
        case .threeDL: return ".3dl (Autodesk / Flame)"
        }
    }
}

// MARK: - LUT File

/// Represents an imported LUT file with metadata.
struct LUTFile: Codable, Hashable, Identifiable {
    let id: String

    /// User-facing name (derived from filename or user-entered)
    let name: String

    /// Original filename
    let originalFileName: String

    /// File format
    let format: LUTFormat

    /// Relative path within app documents (for persistence)
    let relativePath: String

    /// LUT grid size (e.g. 33 for a 33×33×33 LUT)
    let gridSize: Int

    /// Date imported
    let importDate: Date

    /// Optional user notes
    var notes: String = ""

    /// Application intensity (0.0–1.0)
    var intensity: Float = 1.0

    /// Category for organisation
    var category: CinematicLookCategory = .custom
}

// MARK: - LUT Data (Runtime)

/// Parsed LUT data for runtime application. Not persisted — rebuilt from
/// the LUT file on load.
struct LUTData {
    /// 3D LUT grid size (e.g. 33)
    let size: Int

    /// Flattened 3D lookup table. Length = size × size × size.
    /// Each entry is an RGB triplet (0.0–1.0).
    let table: [SIMD3<Float>]

    /// Total number of entries
    var entryCount: Int { size * size * size }

    /// Trilinear interpolation lookup.
    /// Input: RGB color (0.0–1.0). Output: graded RGB color.
    func lookup(r: Float, g: Float, b: Float) -> SIMD3<Float> {
        let s = Float(size - 1)
        let rf = min(max(r * s, 0), s)
        let gf = min(max(g * s, 0), s)
        let bf = min(max(b * s, 0), s)

        let r0 = Int(rf); let r1 = min(r0 + 1, size - 1)
        let g0 = Int(gf); let g1 = min(g0 + 1, size - 1)
        let b0 = Int(bf); let b1 = min(b0 + 1, size - 1)

        let fr = rf - Float(r0)
        let fg = gf - Float(g0)
        let fb = bf - Float(b0)

        func idx(_ ri: Int, _ gi: Int, _ bi: Int) -> Int {
            return bi * size * size + gi * size + ri
        }

        // Trilinear interpolation across 8 corners of the cube
        let c000 = table[idx(r0, g0, b0)]
        let c100 = table[idx(r1, g0, b0)]
        let c010 = table[idx(r0, g1, b0)]
        let c110 = table[idx(r1, g1, b0)]
        let c001 = table[idx(r0, g0, b1)]
        let c101 = table[idx(r1, g0, b1)]
        let c011 = table[idx(r0, g1, b1)]
        let c111 = table[idx(r1, g1, b1)]

        let c00 = c000 * (1 - fr) + c100 * fr
        let c01 = c001 * (1 - fr) + c101 * fr
        let c10 = c010 * (1 - fr) + c110 * fr
        let c11 = c011 * (1 - fr) + c111 * fr

        let c0 = c00 * (1 - fg) + c10 * fg
        let c1 = c01 * (1 - fg) + c11 * fg

        return c0 * (1 - fb) + c1 * fb
    }
}
