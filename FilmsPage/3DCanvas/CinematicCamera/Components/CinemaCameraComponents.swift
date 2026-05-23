//
//  CinemaCameraComponents.swift
//  FilmsPage
//
//  RealityKit ECS components that attach cinematic camera metadata
//  to virtual camera entities. Each component links to a model from
//  the Models/ layer and is persisted via ScenePersistence.
//

import RealityKit
import Foundation

// MARK: - CineSensorComponent

/// Attaches a cinema camera body (sensor) to a virtual camera entity.
/// Drives FOV calculations and crop factor simulation.
struct CineSensorComponent: Component, Codable {

    /// ID referencing a CinemaCameraBody in the database
    var cameraBodyID: String

    /// Resolved camera body (transient — rebuilt from ID on load)
    var resolvedBody: CinemaCameraBody? {
        CinemaCameraDatabase.camera(byID: cameraBodyID)
    }

    init(cameraBodyID: String = CinemaCameraDatabase.defaultCamera.id) {
        self.cameraBodyID = cameraBodyID
    }
}

// MARK: - CineLensComponent

/// Attaches a cinema lens family and selected focal length to a camera.
/// Drives optical simulation (distortion, vignette, CA, breathing).
struct CineLensComponent: Component, Codable {

    /// ID referencing a CinemaLensFamily in the database
    var lensFamilyID: String

    /// Currently selected focal length in millimetres
    var selectedFocalLengthMM: Float

    /// Focus breathing mode
    var breathingMode: CineBreathingMode

    /// Resolved lens family (transient)
    var resolvedFamily: CinemaLensFamily? {
        CinemaLensDatabase.family(byID: lensFamilyID)
    }

    /// Resolved optical profile for the current focal length
    var resolvedProfile: LensOpticalProfile {
        resolvedFamily?.opticalProfile(forFocalLength: selectedFocalLengthMM)
            ?? LensOpticalProfile()
    }

    init(
        lensFamilyID: String = CinemaLensDatabase.defaultFamily.id,
        selectedFocalLengthMM: Float = 50.0,
        breathingMode: CineBreathingMode = .cinematic
    ) {
        self.lensFamilyID = lensFamilyID
        self.selectedFocalLengthMM = selectedFocalLengthMM
        self.breathingMode = breathingMode
    }
}

// MARK: - CineBreathingMode

/// Controls how visible focus breathing is in the simulation.
enum CineBreathingMode: String, Codable, CaseIterable, Identifiable {
    case subtle    = "Subtle"
    case realistic = "Realistic"
    case cinematic = "Cinematic"

    var id: String { rawValue }

    /// Multiplier applied to the lens profile's breathing amount.
    /// Subtle dampens it, Cinematic exaggerates for readability.
    var breathingMultiplier: Float {
        switch self {
        case .subtle:    return 0.3
        case .realistic: return 1.0
        case .cinematic: return 2.0
        }
    }

    var description: String {
        switch self {
        case .subtle:    return "Barely visible — professional cine lens feel"
        case .realistic: return "Physically accurate breathing behavior"
        case .cinematic: return "Enhanced for visual readability on screens"
        }
    }
}

// MARK: - CineLookComponent

/// Attaches a cinematic look (color grading preset) to a camera.
/// Drives the creative grading pipeline (color, contrast, grain, bloom).
struct CineLookComponent: Component, Codable {

    /// ID referencing a CinematicLook in the database, or a custom LUT
    var lookID: String

    /// Look application intensity (0.0 = bypass, 1.0 = full)
    var intensity: Float

    /// Optional custom LUT file ID (overrides the preset look)
    var customLUTFileID: String?

    /// Custom LUT intensity (separate from look intensity)
    var lutIntensity: Float

    /// Resolved look preset (transient)
    var resolvedLook: CinematicLook? {
        CinematicLookDatabase.look(byID: lookID)
    }

    init(
        lookID: String = CinematicLookDatabase.defaultLook.id,
        intensity: Float = 1.0,
        customLUTFileID: String? = nil,
        lutIntensity: Float = 1.0
    ) {
        self.lookID = lookID
        self.intensity = intensity
        self.customLUTFileID = customLUTFileID
        self.lutIntensity = lutIntensity
    }
}

// MARK: - CineMotionComponent

/// Attaches a procedural camera motion style to a camera.
/// Drives the CameraMotionEngine for realistic micro-movement.
struct CineMotionComponent: Component, Codable {

    /// Selected motion style
    var motionStyle: CameraMotionStyle

    /// Whether motion is currently active
    var isActive: Bool

    /// User-adjustable intensity multiplier (0.0–2.0)
    var intensityMultiplier: Float

    /// Random seed for deterministic motion (same seed = same motion)
    var seed: UInt64

    /// Resolved motion parameters with intensity applied
    var resolvedParameters: MotionParameters {
        var params = motionStyle.defaultParameters
        params.intensityMultiplier = intensityMultiplier
        return params
    }

    init(
        motionStyle: CameraMotionStyle = .tripod,
        isActive: Bool = false,
        intensityMultiplier: Float = 1.0,
        seed: UInt64 = UInt64.random(in: 0...UInt64.max)
    ) {
        self.motionStyle = motionStyle
        self.isActive = isActive
        self.intensityMultiplier = intensityMultiplier
        self.seed = seed
    }
}

// MARK: - CineAspectRatioComponent

/// Attaches a cinema-standard aspect ratio to a camera.
/// Drives the letterbox overlay and frame guide rendering.
struct CineAspectRatioComponent: Component, Codable {

    /// Selected cinema aspect ratio preset
    var preset: CinemaAspectRatioPreset

    init(preset: CinemaAspectRatioPreset = .hdWidescreen) {
        self.preset = preset
    }
}

// MARK: - CineFrameGuideComponent

/// Attaches frame guide configuration to a camera.
/// Drives the frame guide overlay renderer.
struct CineFrameGuideComponent: Component, Codable {

    /// Frame guide configuration
    var config: FrameGuideConfig

    init(config: FrameGuideConfig = .clean) {
        self.config = config
    }
}

// MARK: - CinematicCameraTag

/// Marker component to distinguish cinema cameras from basic scene cameras.
/// Entities with this component use the full cinematic rendering pipeline.
struct CinematicCameraTag: Component, Codable {
    /// Creation timestamp for ordering
    let createdAt: Date

    init() {
        self.createdAt = Date()
    }
}
