//
//  CinemaLens.swift
//  FilmsPage
//
//  Professional cinema lens family and optical profile model definitions.
//  Used by the cinematic virtual camera system to simulate real-world
//  lens optical characteristics including distortion, vignette,
//  chromatic aberration, breathing, and flare behavior.
//
//  Optical profile values are normalised 0–1 for shader consumption.
//  Distortion coefficients use the Brown–Conrady radial model.
//

import Foundation

// MARK: - Cinema Lens Brand

/// Major cinema lens manufacturers.
enum CinemaLensBrand: String, Codable, CaseIterable, Identifiable {
    case cooke       = "Cooke"
    case arri        = "ARRI/ZEISS"
    case zeiss       = "Zeiss"
    case leica       = "Leica"
    case canon       = "Canon"
    case panavision  = "Panavision"
    case hawk        = "Hawk"
    case sigma       = "Sigma"
    case masterPrime = "Master Prime"
    case vintage     = "Vintage"

    var id: String { rawValue }

    /// Display name for UI
    var displayName: String { rawValue }

    /// Brand accent color (RGB, 0–1) for UI tinting
    var accentColorRGB: (r: Float, g: Float, b: Float) {
        switch self {
        case .cooke:       return (0.85, 0.65, 0.20)  // Cooke gold
        case .arri:        return (0.00, 0.47, 0.75)  // ARRI blue
        case .zeiss:       return (0.10, 0.30, 0.65)  // Zeiss blue
        case .leica:       return (0.80, 0.10, 0.10)  // Leica red
        case .canon:       return (0.75, 0.06, 0.06)  // Canon red
        case .panavision:  return (0.15, 0.35, 0.60)  // Panavision blue
        case .hawk:        return (0.90, 0.45, 0.10)  // Hawk orange
        case .sigma:       return (0.20, 0.20, 0.20)  // Sigma dark
        case .masterPrime: return (0.10, 0.30, 0.65)  // Zeiss family
        case .vintage:     return (0.60, 0.50, 0.35)  // Warm vintage
        }
    }

    /// Short description of the brand's optical character
    var character: String {
        switch self {
        case .cooke:       return "Warm, organic, flattering"
        case .arri:        return "Clean, precise, cinematic"
        case .zeiss:       return "Sharp, clinical, modern"
        case .leica:       return "Elegant, smooth, refined"
        case .canon:       return "Classic, warm, vintage character"
        case .panavision:  return "Hollywood standard, anamorphic heritage"
        case .hawk:        return "Anamorphic, flare-rich, widescreen"
        case .sigma:       return "Modern, sharp, versatile"
        case .masterPrime: return "Ultra sharp, ultra fast, precise"
        case .vintage:     return "Imperfect, characterful, soulful"
        }
    }
}

// MARK: - Anamorphic Mode

/// Defines whether a lens is spherical or anamorphic.
enum AnamorphicMode: Codable, Hashable {
    /// Standard spherical lens — no squeeze
    case spherical

    /// Anamorphic lens with a horizontal squeeze ratio.
    /// Common values: 2.0x (classic), 1.33x (modern), 1.8x
    case anamorphic(squeeze: Float)

    /// The squeeze ratio. 1.0 for spherical, >1.0 for anamorphic.
    var squeezeRatio: Float {
        switch self {
        case .spherical: return 1.0
        case .anamorphic(let squeeze): return squeeze
        }
    }

    /// Whether this mode is anamorphic
    var isAnamorphic: Bool {
        switch self {
        case .spherical: return false
        case .anamorphic: return true
        }
    }

    /// Display label for UI
    var displayLabel: String {
        switch self {
        case .spherical: return "Spherical"
        case .anamorphic(let squeeze): return String(format: "%.1fx Anamorphic", squeeze)
        }
    }
}

// MARK: - Lens Optical Profile

/// Defines the optical rendering characteristics of a cinema lens.
/// All values are normalised (0.0–1.0) unless otherwise noted.
/// These values drive the Metal shader pipeline for realtime simulation.
struct LensOpticalProfile: Codable, Hashable {

    // ── Distortion ─────────────────────────────────────────────────────────

    /// Radial distortion coefficient K1 (Brown–Conrady model).
    /// Positive = barrel distortion, Negative = pincushion.
    /// Range: -0.3 to 0.3. Most cine lenses: 0.01–0.05
    var distortionK1: Float = 0.0

    /// Radial distortion coefficient K2 (higher-order).
    /// Range: -0.1 to 0.1
    var distortionK2: Float = 0.0

    // ── Vignette ───────────────────────────────────────────────────────────

    /// Optical vignette intensity. 0 = none, 1 = heavy darkening at edges.
    /// Most cine lenses: 0.1–0.4
    var vignetteStrength: Float = 0.15

    /// How far from centre the vignette begins. 0 = from centre, 1 = only corners.
    var vignetteFalloffStart: Float = 0.6

    // ── Edge Quality ───────────────────────────────────────────────────────

    /// Edge softness / resolution falloff. 0 = sharp to edges, 1 = very soft edges.
    /// Vintage lenses: 0.3–0.6, Modern primes: 0.05–0.15
    var edgeSoftness: Float = 0.1

    /// Overall sharpness character. 0 = soft, 1 = razor sharp.
    /// Drives a subtle unsharp-mask or softening pass.
    var sharpnessCharacter: Float = 0.8

    // ── Chromatic Aberration ────────────────────────────────────────────────

    /// Lateral chromatic aberration intensity.
    /// 0 = none, 1 = heavy colour fringing at edges.
    /// Most cine lenses: 0.02–0.10
    var chromaticAberration: Float = 0.03

    // ── Focus Breathing ────────────────────────────────────────────────────

    /// Focus breathing amount — FOV shift when changing focus distance.
    /// 0 = no breathing, 1 = extreme breathing.
    /// Cine lenses are designed to minimise this (0.01–0.05).
    /// Vintage/photo lenses can be much higher (0.1–0.3).
    var breathingAmount: Float = 0.03

    // ── Flare & Bloom ──────────────────────────────────────────────────────

    /// Lens flare intensity when bright light sources are in frame.
    /// 0 = no flare, 1 = heavy flare. Most cine lenses: 0.1–0.4
    var flareIntensity: Float = 0.15

    /// Flare colour warmth. 0 = cool/blue, 0.5 = neutral, 1 = warm/amber.
    var flareWarmth: Float = 0.5

    /// Bloom / glow around highlights. 0 = none, 1 = heavy.
    /// Controlled separately from the look pipeline's bloom.
    var bloomStrength: Float = 0.1

    /// Halation — warm highlight bleed into surrounding areas.
    /// 0 = none, 1 = heavy. Classic film look: 0.1–0.3
    var halationStrength: Float = 0.05

    // ── Anamorphic Specifics ───────────────────────────────────────────────

    /// Anamorphic horizontal flare streak intensity.
    /// Only active when lens is anamorphic. 0 = none, 1 = heavy streaks.
    var anamorphicFlareStreak: Float = 0.0

    /// Anamorphic bokeh oval-isation. 0 = round, 1 = fully oval.
    var anamorphicBokehOval: Float = 0.0
}

// MARK: - Cinema Lens Focal Length

/// A specific focal length within a lens family, with per-focal-length
/// optical tuning. Wide angles have more distortion, telephotos less.
struct CinemaFocalLength: Codable, Hashable, Identifiable {
    var id: String { "\(focalLengthMM)mm" }

    /// Focal length in millimetres
    let focalLengthMM: Float

    /// Per-focal-length optical profile override.
    /// If nil, uses the family's base profile.
    let opticalOverride: LensOpticalProfile?

    /// Maximum aperture at this focal length (e.g. 1.4, 2.0, 2.8)
    let maxAperture: Float

    /// Display label (e.g. "50mm")
    var displayLabel: String {
        if focalLengthMM == Float(Int(focalLengthMM)) {
            return "\(Int(focalLengthMM))mm"
        }
        return String(format: "%.1fmm", focalLengthMM)
    }
}

// MARK: - Cinema Lens Family

/// Represents a complete cinema lens family (e.g. "Cooke S4/i").
/// Contains the family's base optical profile and all available focal lengths.
struct CinemaLensFamily: Codable, Hashable, Identifiable {
    let id: String

    /// Lens brand
    let brand: CinemaLensBrand

    /// Family name (e.g. "S4/i", "Signature Prime", "Supreme Prime")
    let familyName: String

    /// Full display name
    var displayName: String {
        return "\(brand.displayName) \(familyName)"
    }

    /// Anamorphic mode for this family
    let anamorphicMode: AnamorphicMode

    /// Base optical profile — applies to all focal lengths unless overridden
    let baseProfile: LensOpticalProfile

    /// Available focal lengths in this family
    let focalLengths: [CinemaFocalLength]

    /// Short description of the lens family's character
    let character: String

    /// Whether this is a zoom lens (vs prime set)
    let isZoom: Bool

    /// The optical profile for a specific focal length.
    /// Returns the per-focal-length override if available, otherwise the base profile.
    func opticalProfile(forFocalLength mm: Float) -> LensOpticalProfile {
        // Find the nearest focal length entry
        let nearest = focalLengths.min(by: { abs($0.focalLengthMM - mm) < abs($1.focalLengthMM - mm) })
        return nearest?.opticalOverride ?? baseProfile
    }

    /// The default focal length (usually 50mm or the middle of the range)
    var defaultFocalLength: CinemaFocalLength {
        // Prefer 50mm if available
        if let fifty = focalLengths.first(where: { $0.focalLengthMM == 50.0 }) {
            return fifty
        }
        // Otherwise return the middle focal length
        return focalLengths[focalLengths.count / 2]
    }

    /// Focal length range for display
    var focalLengthRange: String {
        guard let first = focalLengths.first, let last = focalLengths.last else { return "—" }
        return "\(Int(first.focalLengthMM))–\(Int(last.focalLengthMM))mm"
    }
}
