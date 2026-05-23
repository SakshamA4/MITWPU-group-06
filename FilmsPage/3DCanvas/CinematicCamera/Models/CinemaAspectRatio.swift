//
//  CinemaAspectRatio.swift
//  FilmsPage
//
//  Professional cinema aspect ratio presets with safe area definitions.
//  Extends the existing CameraAspectRatio system with cinema-standard
//  formats used in theatrical, broadcast, and streaming delivery.
//

import Foundation
import CoreGraphics

// MARK: - Cinema Aspect Ratio Preset

/// Industry-standard cinema aspect ratios with safe area definitions.
/// These are separate from the existing CameraAspectRatio enum to provide
/// cinema-specific metadata while remaining backward-compatible.
enum CinemaAspectRatioPreset: String, Codable, CaseIterable, Identifiable {
    case anamorphicScope   = "2.39:1"
    case univisium         = "2.00:1"
    case flat              = "1.85:1"
    case hdWidescreen      = "16:9"
    case imax              = "1.43:1"
    case academy4x3        = "4:3"
    case fullFrame         = "1.33:1"
    case openGate          = "Open Gate"
    case seventyMM         = "2.20:1"
    case ultraPanavision   = "2.76:1"

    var id: String { rawValue }

    /// Width / height as a Float
    var ratio: Float {
        switch self {
        case .anamorphicScope: return 2.39
        case .univisium:       return 2.00
        case .flat:            return 1.85
        case .hdWidescreen:    return 16.0 / 9.0
        case .imax:            return 1.43
        case .academy4x3:      return 4.0 / 3.0
        case .fullFrame:       return 1.33
        case .openGate:        return 1.50   // Typical open gate
        case .seventyMM:       return 2.20
        case .ultraPanavision: return 2.76
        }
    }

    /// Human-readable display name
    var displayName: String {
        switch self {
        case .anamorphicScope: return "2.39:1 Scope"
        case .univisium:       return "2:1 Univisium"
        case .flat:            return "1.85:1 Flat"
        case .hdWidescreen:    return "16:9 HD"
        case .imax:            return "1.43:1 IMAX"
        case .academy4x3:      return "4:3 Academy"
        case .fullFrame:       return "1.33:1 Full Frame"
        case .openGate:        return "Open Gate"
        case .seventyMM:       return "2.20:1 70mm"
        case .ultraPanavision: return "2.76:1 Ultra Panavision"
        }
    }

    /// Short description for UI tooltips
    var description: String {
        switch self {
        case .anamorphicScope: return "Widescreen cinema — anamorphic projection"
        case .univisium:       return "Modern streaming — Netflix standard"
        case .flat:            return "US theatrical flat — standard widescreen"
        case .hdWidescreen:    return "HD broadcast and streaming"
        case .imax:            return "IMAX tall format — immersive"
        case .academy4x3:      return "Classic television and early cinema"
        case .fullFrame:       return "Silent era / full aperture"
        case .openGate:        return "Full sensor area — maximum resolution"
        case .seventyMM:       return "70mm film — epic scale"
        case .ultraPanavision: return "Ultra-wide 70mm — Ben-Hur, Hateful Eight"
        }
    }

    /// SF Symbol icon for UI
    var iconSystemName: String {
        switch self {
        case .anamorphicScope, .ultraPanavision, .seventyMM:
            return "rectangle.ratio.16.to.9"
        case .univisium, .flat:
            return "rectangle"
        case .hdWidescreen:
            return "tv"
        case .imax:
            return "rectangle.portrait"
        case .academy4x3, .fullFrame:
            return "rectangle.ratio.4.to.3"
        case .openGate:
            return "viewfinder"
        }
    }

    /// Safe area guides for this aspect ratio
    var safeAreas: SafeAreaGuide {
        switch self {
        case .hdWidescreen, .academy4x3:
            // Broadcast-standard safe areas
            return SafeAreaGuide(
                actionSafePercent: 0.93,
                titleSafePercent: 0.90
            )
        default:
            // Cinema projection — more relaxed safe areas
            return SafeAreaGuide(
                actionSafePercent: 0.95,
                titleSafePercent: 0.90
            )
        }
    }

    /// Convert to the existing CameraAspectRatio for backward compatibility
    var legacyAspectRatio: CameraAspectRatio {
        switch self {
        case .hdWidescreen:    return .sixteenByNine
        case .academy4x3:      return .fourByThree
        case .anamorphicScope: return .twoThirtyFiveByOne
        default:               return .sixteenByNine  // Closest fallback
        }
    }

    /// Snapshot size for preview thumbnails (same logic as CameraAspectRatio)
    var snapshotSize: CGSize {
        let baseArea: Float = 129_600
        let w = sqrt(baseArea * ratio)
        let h = w / ratio
        return CGSize(width: CGFloat(w), height: CGFloat(h))
    }

    /// Shortened label for compact UI (e.g. HUD pills)
    var shortName: String {
        switch self {
        case .anamorphicScope: return "2.39"
        case .univisium:       return "2.00"
        case .flat:            return "1.85"
        case .hdWidescreen:    return "16:9"
        case .imax:            return "1.43"
        case .academy4x3:      return "4:3"
        case .fullFrame:       return "1.33"
        case .openGate:        return "OG"
        case .seventyMM:       return "2.20"
        case .ultraPanavision: return "2.76"
        }
    }

    /// Alias used by the integration layer
    var legacyCameraAspectRatio: CameraAspectRatio {
        return legacyAspectRatio
    }

    /// Convenience alias: `.scope239` == `.anamorphicScope`
    static let scope239 = CinemaAspectRatioPreset.anamorphicScope
}

// MARK: - Safe Area Guide

/// Defines the action-safe and title-safe areas for a given aspect ratio.
/// Values are percentages of the frame (0.0–1.0) from centre outward.
struct SafeAreaGuide: Codable, Hashable {
    /// Action-safe area — all important action should be within this zone.
    /// Typically 93% for broadcast, 95% for cinema.
    let actionSafePercent: Float

    /// Title-safe area — all text/graphics should be within this zone.
    /// Typically 90% for both broadcast and cinema.
    let titleSafePercent: Float

    /// Inset from each edge for action-safe (normalised 0–1).
    var actionSafeInset: Float { (1.0 - actionSafePercent) / 2.0 }

    /// Inset from each edge for title-safe (normalised 0–1).
    var titleSafeInset: Float { (1.0 - titleSafePercent) / 2.0 }

    /// Calculate the action-safe rect within a given viewport.
    func actionSafeRect(in viewport: CGRect) -> CGRect {
        let inset = CGFloat(actionSafeInset)
        return viewport.insetBy(
            dx: viewport.width * inset,
            dy: viewport.height * inset
        )
    }

    /// Calculate the title-safe rect within a given viewport.
    func titleSafeRect(in viewport: CGRect) -> CGRect {
        let inset = CGFloat(titleSafeInset)
        return viewport.insetBy(
            dx: viewport.width * inset,
            dy: viewport.height * inset
        )
    }
}
