//
//  CameraMotionPreset.swift
//  FilmsPage
//
//  Procedural camera motion preset definitions for cinematic
//  virtual camera simulation. Each style defines the physical
//  characteristics of a camera operator/platform combination.
//

import Foundation

// MARK: - Camera Motion Style

/// Cinematic camera motion styles that simulate real-world camera
/// platforms and operator techniques via procedural noise synthesis.
enum CameraMotionStyle: String, Codable, CaseIterable, Identifiable {
    case tripod         = "Tripod"
    case handheld       = "Handheld"
    case shoulderRig    = "Shoulder Rig"
    case steadicam      = "Steadicam"
    case dolly          = "Dolly"
    case crane          = "Crane"
    case drone          = "Drone"
    case documentary    = "Documentary"
    case actionCam      = "Action Cam"
    case idleMicroMotion = "Idle Micro Motion"

    var id: String { rawValue }

    /// SF Symbol icon for UI
    var iconSystemName: String {
        switch self {
        case .tripod:          return "triangle.bottomhalf.filled"
        case .handheld:        return "hand.raised"
        case .shoulderRig:     return "figure.arms.open"
        case .steadicam:       return "figure.walk"
        case .dolly:           return "arrow.left.and.right.circle"
        case .crane:           return "arrow.up.right"
        case .drone:           return "airplane"
        case .documentary:     return "video"
        case .actionCam:       return "bolt.circle"
        case .idleMicroMotion: return "waveform.path.ecg"
        }
    }

    /// Short description for UI
    var description: String {
        switch self {
        case .tripod:          return "Locked off — minimal micro-vibration"
        case .handheld:        return "Operator breathing and body sway"
        case .shoulderRig:     return "Heavy, weighted shoulder movement"
        case .steadicam:       return "Smooth floating with subtle drift"
        case .dolly:           return "Mechanical smoothness on rails"
        case .crane:           return "Slow arc with height variation"
        case .drone:           return "GPS stabilised with wind drift"
        case .documentary:     return "Reactive, slightly unstable"
        case .actionCam:       return "Aggressive shake and roll"
        case .idleMicroMotion: return "Barely perceptible — living camera"
        }
    }

    /// The default motion parameters for this style
    var defaultParameters: MotionParameters {
        switch self {
        case .tripod:
            return MotionParameters(
                positionAmplitude: SIMD3(0.0002, 0.0001, 0.0001),
                rotationAmplitude: SIMD3(0.0003, 0.0002, 0.0001),
                frequency: 0.8, damping: 0.95, inertia: 0.98,
                noiseScale: 1.0, rollAmount: 0.0001,
                breathingCycle: 0.0, stepBounce: 0.0
            )
        case .handheld:
            return MotionParameters(
                positionAmplitude: SIMD3(0.004, 0.006, 0.002),
                rotationAmplitude: SIMD3(0.008, 0.005, 0.003),
                frequency: 2.5, damping: 0.70, inertia: 0.85,
                noiseScale: 1.2, rollAmount: 0.004,
                breathingCycle: 0.25, stepBounce: 0.0
            )
        case .shoulderRig:
            return MotionParameters(
                positionAmplitude: SIMD3(0.003, 0.008, 0.002),
                rotationAmplitude: SIMD3(0.005, 0.003, 0.004),
                frequency: 1.8, damping: 0.75, inertia: 0.90,
                noiseScale: 1.0, rollAmount: 0.006,
                breathingCycle: 0.20, stepBounce: 0.15
            )
        case .steadicam:
            return MotionParameters(
                positionAmplitude: SIMD3(0.001, 0.002, 0.001),
                rotationAmplitude: SIMD3(0.002, 0.001, 0.001),
                frequency: 0.6, damping: 0.92, inertia: 0.96,
                noiseScale: 0.8, rollAmount: 0.001,
                breathingCycle: 0.0, stepBounce: 0.08
            )
        case .dolly:
            return MotionParameters(
                positionAmplitude: SIMD3(0.0005, 0.0003, 0.0002),
                rotationAmplitude: SIMD3(0.0005, 0.0003, 0.0002),
                frequency: 1.2, damping: 0.90, inertia: 0.95,
                noiseScale: 0.5, rollAmount: 0.0002,
                breathingCycle: 0.0, stepBounce: 0.0
            )
        case .crane:
            return MotionParameters(
                positionAmplitude: SIMD3(0.0008, 0.001, 0.0005),
                rotationAmplitude: SIMD3(0.001, 0.0008, 0.0004),
                frequency: 0.4, damping: 0.88, inertia: 0.94,
                noiseScale: 0.6, rollAmount: 0.0003,
                breathingCycle: 0.0, stepBounce: 0.0
            )
        case .drone:
            return MotionParameters(
                positionAmplitude: SIMD3(0.003, 0.001, 0.003),
                rotationAmplitude: SIMD3(0.002, 0.003, 0.002),
                frequency: 1.5, damping: 0.80, inertia: 0.88,
                noiseScale: 1.5, rollAmount: 0.003,
                breathingCycle: 0.0, stepBounce: 0.0
            )
        case .documentary:
            return MotionParameters(
                positionAmplitude: SIMD3(0.005, 0.007, 0.003),
                rotationAmplitude: SIMD3(0.010, 0.006, 0.004),
                frequency: 2.0, damping: 0.65, inertia: 0.80,
                noiseScale: 1.3, rollAmount: 0.005,
                breathingCycle: 0.30, stepBounce: 0.0
            )
        case .actionCam:
            return MotionParameters(
                positionAmplitude: SIMD3(0.012, 0.015, 0.010),
                rotationAmplitude: SIMD3(0.020, 0.015, 0.012),
                frequency: 4.0, damping: 0.50, inertia: 0.70,
                noiseScale: 2.0, rollAmount: 0.015,
                breathingCycle: 0.0, stepBounce: 0.25
            )
        case .idleMicroMotion:
            return MotionParameters(
                positionAmplitude: SIMD3(0.0003, 0.0002, 0.0001),
                rotationAmplitude: SIMD3(0.0005, 0.0003, 0.0002),
                frequency: 0.3, damping: 0.97, inertia: 0.99,
                noiseScale: 0.5, rollAmount: 0.0001,
                breathingCycle: 0.05, stepBounce: 0.0
            )
        }
    }

    /// Intensity category for UI grouping
    var intensityCategory: MotionIntensityCategory {
        switch self {
        case .tripod, .idleMicroMotion:          return .minimal
        case .dolly, .crane, .steadicam:         return .smooth
        case .handheld, .shoulderRig, .drone:    return .organic
        case .documentary, .actionCam:           return .dynamic
        }
    }
}

// MARK: - Motion Intensity Category

/// Groups motion styles by perceived intensity for UI organisation.
enum MotionIntensityCategory: String, Codable, CaseIterable {
    case minimal  = "Minimal"
    case smooth   = "Smooth"
    case organic  = "Organic"
    case dynamic  = "Dynamic"
}

// MARK: - Motion Parameters

/// Physical parameters that define a camera motion style.
/// Used by the CameraMotionEngine for procedural noise synthesis.
struct MotionParameters: Codable, Hashable {

    /// Per-axis position shake amplitude in scene units (metres).
    /// X = lateral, Y = vertical, Z = depth.
    var positionAmplitude: SIMD3<Float>

    /// Per-axis rotation shake amplitude in radians.
    /// X = pitch, Y = yaw, Z = roll.
    var rotationAmplitude: SIMD3<Float>

    /// Base frequency of the motion noise in Hz.
    /// Higher = faster shake. Handheld ≈ 2–3 Hz, Tripod ≈ 0.5–1 Hz.
    var frequency: Float

    /// Damping factor (0–1). Higher = motion settles faster.
    /// Simulates stabilisation system responsiveness.
    var damping: Float

    /// Inertia factor (0–1). Higher = more momentum, slower direction changes.
    /// Simulates the physical mass of the camera rig.
    var inertia: Float

    /// Noise complexity scale. Higher = more random, detailed motion.
    /// 1.0 = standard Perlin, 2.0 = turbulent.
    var noiseScale: Float

    /// Roll axis contribution (0–1). Some rigs have more roll than others.
    var rollAmount: Float

    /// Breathing cycle amplitude — periodic vertical oscillation simulating
    /// operator breathing. 0 = none, 0.3 = visible.
    var breathingCycle: Float

    /// Step bounce — periodic vertical impulse simulating walking.
    /// 0 = none, 0.25 = walking operator.
    var stepBounce: Float

    /// Global intensity multiplier (user-adjustable). Default 1.0.
    var intensityMultiplier: Float = 1.0

    /// Apply the intensity multiplier to all amplitude values.
    var scaledPositionAmplitude: SIMD3<Float> {
        positionAmplitude * intensityMultiplier
    }

    var scaledRotationAmplitude: SIMD3<Float> {
        rotationAmplitude * intensityMultiplier
    }
}
