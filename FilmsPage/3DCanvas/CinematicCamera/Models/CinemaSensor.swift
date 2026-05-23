//
//  CinemaSensor.swift
//  FilmsPage
//
//  Professional cinema sensor and camera body model definitions.
//  Used by the cinematic virtual camera system to simulate real-world
//  cinema camera characteristics including sensor size, crop factor,
//  dynamic range, and color science.
//
//  All sensor dimensions use millimetres (mm) as the standard unit.
//  Reference: Full Frame 35mm = 36.0 × 24.0mm
//

import Foundation

// MARK: - Cinema Sensor Format

/// Standard cinema sensor format categories.
/// Each format defines a family of sensor sizes used across the industry.
enum CinemaSensorFormat: String, Codable, CaseIterable, Identifiable {
    case super35          = "Super 35"
    case fullFrame        = "Full Frame"
    case largeFormat      = "Large Format"
    case vistaVision      = "VistaVision"
    case imax             = "IMAX"
    case super16          = "Super 16"
    case microFourThirds  = "Micro 4/3"
    case super35Cropped   = "Super 35 (Cropped)"
    case aps_c            = "APS-C"

    var id: String { rawValue }

    /// Human-readable description of the sensor format.
    var formatDescription: String {
        switch self {
        case .super35:         return "Industry standard for cinema production"
        case .fullFrame:       return "35mm still photography equivalent"
        case .largeFormat:     return "Larger than Full Frame — cinematic depth"
        case .vistaVision:     return "Horizontal 35mm — wide format"
        case .imax:            return "Large format immersive cinema"
        case .super16:         return "16mm cinema — documentary / indie"
        case .microFourThirds: return "Compact cinema — Micro Four Thirds"
        case .super35Cropped:  return "Cropped Super 35 mode"
        case .aps_c:           return "APS-C sized sensor"
        }
    }
}

// MARK: - Color Science Profile

/// Describes the color science rendering personality of a camera system.
/// Used to inform the cinematic look pipeline about the camera's native
/// color response characteristics.
struct ColorScienceProfile: Codable, Hashable {
    /// Name of the color science (e.g. "ARRI LogC4", "REDWideGamutRGB")
    let name: String

    /// Log encoding curve name (e.g. "LogC4", "Log3G10", "S-Log3")
    let logCurve: String

    /// Color gamut name (e.g. "ARRI Wide Gamut 4", "REDWideGamutRGB", "S-Gamut3.Cine")
    let gamut: String

    /// Subjective warmth tendency: -1.0 (cool) to 1.0 (warm)
    let warmthBias: Float

    /// Skin tone rendering quality: 0.0 (clinical) to 1.0 (flattering)
    let skinToneRendering: Float
}

// MARK: - Cinema Sensor

/// Represents a physical cinema camera sensor with its optical and electronic
/// characteristics. All dimensions are in millimetres.
struct CinemaSensor: Codable, Hashable, Identifiable {
    let id: String

    /// Sensor format category
    let format: CinemaSensorFormat

    /// Active sensor width in millimetres
    let sensorWidthMM: Float

    /// Active sensor height in millimetres
    let sensorHeightMM: Float

    /// Crop factor relative to Full Frame (36 × 24mm)
    /// Calculated as: 36.0 / sensorWidthMM (horizontal crop)
    var cropFactor: Float {
        return 36.0 / sensorWidthMM
    }

    /// Native sensor aspect ratio (width / height)
    var nativeAspectRatio: Float {
        return sensorWidthMM / sensorHeightMM
    }

    /// Sensor diagonal in millimetres
    var diagonalMM: Float {
        return sqrt(sensorWidthMM * sensorWidthMM + sensorHeightMM * sensorHeightMM)
    }

    /// Sensor area in square millimetres
    var areaMM2: Float {
        return sensorWidthMM * sensorHeightMM
    }
}

// MARK: - Cinema Camera Body

/// Represents a complete cinema camera body with its sensor, resolution,
/// and metadata. This is the top-level model for camera selection.
struct CinemaCameraBody: Codable, Hashable, Identifiable {
    let id: String

    /// Camera brand
    let brand: CinemaCameraBrand

    /// Camera model name (e.g. "Alexa Mini LF")
    let modelName: String

    /// Full display name (e.g. "ARRI Alexa Mini LF")
    var displayName: String {
        return "\(brand.displayName) \(modelName)"
    }

    /// The camera's sensor
    let sensor: CinemaSensor

    /// Native recording resolution
    let nativeResolution: CinemaResolution

    /// Open gate sensor dimensions (may differ from active area)
    let openGateWidthMM: Float
    let openGateHeightMM: Float

    /// Maximum dynamic range in stops
    let dynamicRangeStops: Float

    /// Native color science profile
    let colorScience: ColorScienceProfile

    /// Maximum recording frame rate at native resolution
    let maxFPS: Int

    /// Short description for UI tooltips
    let shortDescription: String

    /// SF Symbol name for UI (fallback icon)
    let iconSystemName: String
}

// MARK: - Cinema Camera Brand

/// Major cinema camera manufacturers.
enum CinemaCameraBrand: String, Codable, CaseIterable, Identifiable {
    case arri       = "ARRI"
    case red        = "RED"
    case sony       = "Sony"
    case blackmagic = "Blackmagic"
    case canon      = "Canon"
    case panavision = "Panavision"

    var id: String { rawValue }

    /// Display name for UI
    var displayName: String { rawValue }

    /// Brand accent color (RGB, 0–1)
    var accentColorRGB: (r: Float, g: Float, b: Float) {
        switch self {
        case .arri:       return (0.00, 0.47, 0.75)  // ARRI blue
        case .red:        return (0.80, 0.12, 0.12)   // RED red
        case .sony:       return (0.00, 0.00, 0.00)   // Sony black
        case .blackmagic: return (0.20, 0.20, 0.20)   // Blackmagic dark
        case .canon:      return (0.75, 0.06, 0.06)   // Canon red
        case .panavision: return (0.15, 0.35, 0.60)   // Panavision blue
        }
    }

    /// Brand tagline for the picker UI
    var tagline: String {
        switch self {
        case .arri:       return "The filmmaker's camera"
        case .red:        return "Shoot everything in RED"
        case .sony:       return "Beyond definition"
        case .blackmagic: return "Hollywood in your hands"
        case .canon:      return "Delighting you always"
        case .panavision: return "The art of filmmaking"
        }
    }
}

// MARK: - Cinema Resolution

/// Native recording resolution of a cinema camera.
struct CinemaResolution: Codable, Hashable {
    let width: Int
    let height: Int

    /// Human-readable label (e.g. "6K", "4.6K", "8K")
    var label: String {
        let k = Float(width) / 1000.0
        if k == Float(Int(k)) {
            return "\(Int(k))K"
        } else {
            return String(format: "%.1fK", k)
        }
    }

    /// Total megapixels
    var megapixels: Float {
        return Float(width * height) / 1_000_000.0
    }

    // Common cinema resolutions
    static let uhd4K    = CinemaResolution(width: 3840, height: 2160)
    static let dci4K    = CinemaResolution(width: 4096, height: 2160)
    static let sixK     = CinemaResolution(width: 6144, height: 3160)
    static let eightK   = CinemaResolution(width: 8192, height: 4320)
}
