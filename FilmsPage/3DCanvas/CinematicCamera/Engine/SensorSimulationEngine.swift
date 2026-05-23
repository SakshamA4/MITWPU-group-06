//
//  SensorSimulationEngine.swift
//  FilmsPage
//
//  Physically accurate FOV and crop factor calculation engine.
//  Uses real trigonometric formulas to simulate how different
//  cinema sensors frame a scene with a given focal length.
//
//  Reference sensor: Full Frame 35mm still = 36.0 × 24.0mm
//

import Foundation
import CoreGraphics

// MARK: - SensorSimulationEngine

/// Calculates physically accurate field-of-view, crop factors,
/// and framing rects for cinema sensor + lens combinations.
final class SensorSimulationEngine {

    static let shared = SensorSimulationEngine()
    private init() {}

    // ── Reference Constants ────────────────────────────────────────────────

    /// Full Frame 35mm still sensor (reference for crop factor)
    static let referenceWidthMM: Float = 36.0
    static let referenceHeightMM: Float = 24.0
    static let referenceDiagonalMM: Float = sqrt(36.0 * 36.0 + 24.0 * 24.0)

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - FOV Calculations
    // ═══════════════════════════════════════════════════════════════════════

    /// Horizontal field of view in degrees.
    /// Formula: FOV = 2 × atan(sensorWidth / (2 × focalLength))
    func horizontalFOV(sensorWidthMM: Float, focalLengthMM: Float) -> Float {
        let clamped = max(1.0, focalLengthMM)
        let radians = 2.0 * atan(sensorWidthMM / (2.0 * clamped))
        return radians * (180.0 / .pi)
    }

    /// Vertical field of view in degrees.
    func verticalFOV(sensorHeightMM: Float, focalLengthMM: Float) -> Float {
        let clamped = max(1.0, focalLengthMM)
        let radians = 2.0 * atan(sensorHeightMM / (2.0 * clamped))
        return radians * (180.0 / .pi)
    }

    /// Diagonal field of view in degrees.
    func diagonalFOV(sensor: CinemaSensor, focalLengthMM: Float) -> Float {
        let clamped = max(1.0, focalLengthMM)
        let radians = 2.0 * atan(sensor.diagonalMM / (2.0 * clamped))
        return radians * (180.0 / .pi)
    }

    /// Calculate FOV for a complete sensor + lens combination.
    /// Returns (horizontalFOV, verticalFOV) in degrees.
    func calculateFOV(sensor: CinemaSensor, focalLengthMM: Float) -> (horizontal: Float, vertical: Float) {
        let h = horizontalFOV(sensorWidthMM: sensor.sensorWidthMM, focalLengthMM: focalLengthMM)
        let v = verticalFOV(sensorHeightMM: sensor.sensorHeightMM, focalLengthMM: focalLengthMM)
        return (h, v)
    }

    /// The FOV value to apply to a RealityKit PerspectiveCamera.
    /// RealityKit uses vertical FOV by default.
    func realityKitFOV(sensor: CinemaSensor, focalLengthMM: Float) -> Float {
        return verticalFOV(sensorHeightMM: sensor.sensorHeightMM, focalLengthMM: focalLengthMM)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Crop Factor
    // ═══════════════════════════════════════════════════════════════════════

    /// Crop factor relative to Full Frame (horizontal).
    func cropFactor(sensorWidthMM: Float) -> Float {
        return Self.referenceWidthMM / max(0.001, sensorWidthMM)
    }

    /// Crop factor for a sensor struct.
    func cropFactor(sensor: CinemaSensor) -> Float {
        return cropFactor(sensorWidthMM: sensor.sensorWidthMM)
    }

    /// Effective focal length after crop factor.
    /// A 50mm on Super35 (1.5x crop) looks like a 75mm on Full Frame.
    func effectiveFocalLength(actualMM: Float, cropFactor: Float) -> Float {
        return actualMM * cropFactor
    }

    /// Effective focal length for a sensor + lens combination.
    func effectiveFocalLength(sensor: CinemaSensor, actualMM: Float) -> Float {
        return actualMM * sensor.cropFactor
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Framing Rect Calculation
    // ═══════════════════════════════════════════════════════════════════════

    /// Calculates the visible framing rect within a viewport for a given
    /// sensor aspect ratio and target delivery aspect ratio.
    ///
    /// When the sensor is wider than the target, the result is letterboxed.
    /// When the sensor is taller than the target, the result is pillarboxed.
    ///
    /// - Parameters:
    ///   - sensorAspect: Native sensor width/height ratio
    ///   - targetAspect: Desired delivery aspect ratio (e.g. 2.39 for scope)
    ///   - viewportSize: The UIView/CALayer size to fit within
    /// - Returns: The CGRect within the viewport that represents the active frame
    func calculateFramingRect(
        sensorAspect: Float,
        targetAspect: Float,
        viewportSize: CGSize
    ) -> CGRect {
        let viewW = Float(viewportSize.width)
        let viewH = Float(viewportSize.height)
        guard viewW > 0, viewH > 0 else { return .zero }

        let viewAspect = viewW / viewH

        // First: fit the sensor into the viewport
        let sensorRect: CGRect
        if sensorAspect > viewAspect {
            // Sensor is wider than viewport — fit width, letterbox
            let h = viewW / sensorAspect
            sensorRect = CGRect(x: 0, y: CGFloat((viewH - h) / 2.0),
                                width: CGFloat(viewW), height: CGFloat(h))
        } else {
            // Sensor is taller than viewport — fit height, pillarbox
            let w = viewH * sensorAspect
            sensorRect = CGRect(x: CGFloat((viewW - w) / 2.0), y: 0,
                                width: CGFloat(w), height: CGFloat(viewH))
        }

        // Second: apply delivery aspect ratio crop within the sensor rect
        let sensorW = Float(sensorRect.width)
        let sensorH = Float(sensorRect.height)
        let sensorRectAspect = sensorW / sensorH

        if targetAspect > sensorRectAspect {
            // Target is wider — crop top/bottom (letterbox within sensor)
            let cropH = sensorW / targetAspect
            let insetY = (sensorH - cropH) / 2.0
            return CGRect(
                x: sensorRect.minX,
                y: sensorRect.minY + CGFloat(insetY),
                width: CGFloat(sensorW),
                height: CGFloat(cropH)
            )
        } else {
            // Target is taller — crop left/right (pillarbox within sensor)
            let cropW = sensorH * targetAspect
            let insetX = (sensorW - cropW) / 2.0
            return CGRect(
                x: sensorRect.minX + CGFloat(insetX),
                y: sensorRect.minY,
                width: CGFloat(cropW),
                height: CGFloat(sensorH)
            )
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Breathing Simulation
    // ═══════════════════════════════════════════════════════════════════════

    /// Calculates the FOV shift caused by focus breathing.
    ///
    /// - Parameters:
    ///   - baseFOV: The base FOV in degrees (at infinity focus)
    ///   - focusDistance: Current focus distance in metres
    ///   - breathingAmount: Lens breathing coefficient (0–1)
    ///   - mode: Breathing visibility mode
    /// - Returns: Adjusted FOV in degrees
    func applyBreathing(
        baseFOV: Float,
        focusDistance: Float,
        breathingAmount: Float,
        mode: CineBreathingMode
    ) -> Float {
        // Breathing effect: closer focus = wider FOV (most lenses)
        // The effect is inversely proportional to focus distance
        let minDist: Float = 0.3   // Minimum focus distance (metres)
        let maxDist: Float = 20.0
        let clampedDist = max(minDist, min(maxDist, focusDistance))

        // Normalised proximity: 1.0 at closest, 0.0 at infinity
        let proximity = 1.0 - (clampedDist - minDist) / (maxDist - minDist)

        // FOV shift in degrees
        let maxShift = breathingAmount * mode.breathingMultiplier * 8.0 // max ±8° at full
        let fovShift = proximity * maxShift

        return baseFOV + fovShift
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Convenience: Full Pipeline
    // ═══════════════════════════════════════════════════════════════════════

    /// Complete sensor simulation: given a camera body + lens + focus state,
    /// returns the final FOV to apply to the RealityKit PerspectiveCamera.
    func simulateFOV(
        cameraBody: CinemaCameraBody,
        focalLengthMM: Float,
        focusDistance: Float,
        breathingAmount: Float,
        breathingMode: CineBreathingMode
    ) -> Float {
        let baseFOV = realityKitFOV(
            sensor: cameraBody.sensor,
            focalLengthMM: focalLengthMM
        )

        return applyBreathing(
            baseFOV: baseFOV,
            focusDistance: focusDistance,
            breathingAmount: breathingAmount,
            mode: breathingMode
        )
    }

    /// Inverse: given a desired FOV, what focal length is needed on a given sensor?
    func focalLengthForFOV(verticalFOVDegrees: Float, sensorHeightMM: Float) -> Float {
        let radians = verticalFOVDegrees * (.pi / 180.0)
        return sensorHeightMM / (2.0 * tan(radians / 2.0))
    }
}
