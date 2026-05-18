//
//  CameraFocusComponent.swift
//  3DCanvas
//
//  ECS component storing per-camera focus & lens settings.
//  Persisted via ScenePersistence so values survive save/load.
//

import RealityKit

// MARK: - CameraFocusComponent

struct CameraFocusComponent: Component, Codable {

    // ── Focus Mode ──────────────────────────────────────────────────────
    enum FocusMode: String, Codable {
        case off          // No depth-of-field — everything sharp
        case autoFocus    // Tap-to-focus; stores focusPoint
        case manualFocus  // Two sliders: aperture + distance
    }

    var mode: FocusMode = .off

    /// Normalised screen-space focus point (0…1, 0…1). Used by AF mode.
    var focusPointX: Float = 0.5
    var focusPointY: Float = 0.5

    /// Aperture (f-stop). Controls blur amount in MF mode.
    /// Range: f/1.4 (very shallow DoF) → f/22 (deep focus).
    var aperture: Float = 5.6

    /// Focus distance in metres. Controls what distance is sharp in MF mode.
    /// Range: 0.5m → 20m.
    var focusDistance: Float = 5.0

    // ── Lens / Grid settings (persisted per-camera) ────────────────────

    /// Focal length in millimetres. Drives PerspectiveCamera.fieldOfViewInDegrees.
    /// Range: 10mm (ultra-wide) → 200mm (telephoto).
    var focalLengthMM: Float = 35.0

    /// Active composition grid type.
    var gridType: GridType = .none
}

// MARK: - GridType

enum GridType: String, Codable, CaseIterable {
    case none           // Clean frame
    case ruleOfThirds   // 3×3
    case fourByFour     // 4×4
    case diagonal       // Corner-to-corner X
    case diagonalThirds // Diagonal + thirds overlay
    case centerCross    // Single H + V through centre
}

// MARK: - FOV ↔ Focal Length Conversion

/// Full-frame sensor width (36mm, industry standard).
private let sensorWidthMM: Float = 36.0

/// Converts a focal length (mm) to a vertical FOV in degrees.
/// Uses the standard photographic formula:
///   FOV = 2 × atan( sensorWidth / (2 × focalLength) )
func focalLengthToFOV(_ mm: Float) -> Float {
    let clamped = max(10, min(200, mm))
    let radians = 2.0 * atan(sensorWidthMM / (2.0 * clamped))
    return radians * (180.0 / .pi)
}

/// Converts a FOV in degrees back to focal length (mm).
func fovToFocalLength(_ fovDegrees: Float) -> Float {
    let radians = fovDegrees * (.pi / 180.0)
    let mm = sensorWidthMM / (2.0 * tan(radians / 2.0))
    return max(10, min(200, mm))
}
