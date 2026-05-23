//
//  CameraMotionEngine.swift
//  FilmsPage
//
//  Procedural camera motion synthesis using layered Perlin noise.
//  Generates physically-inspired camera shake for different
//  operator/platform combinations (handheld, steadicam, crane, etc).
//

import Foundation
import simd

// MARK: - CameraMotionEngine

/// Generates procedural camera motion offsets using layered noise.
/// Deterministic — same seed + time = same output for export consistency.
final class CameraMotionEngine {

    static let shared = CameraMotionEngine()
    private init() {}

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Public API
    // ═══════════════════════════════════════════════════════════════════════

    /// Generates position and rotation offsets for a given time.
    ///
    /// - Parameters:
    ///   - style: Camera motion style
    ///   - time: Current time in seconds
    ///   - seed: Random seed for deterministic output
    ///   - intensityMultiplier: User-adjustable intensity (default 1.0)
    /// - Returns: Position offset (metres) and rotation offset (radians)
    func generateMotionOffset(
        style: CameraMotionStyle,
        time: Float,
        seed: UInt64,
        intensityMultiplier: Float = 1.0
    ) -> MotionOffset {
        let params = style.defaultParameters
        return generateMotionOffset(
            params: params,
            time: time,
            seed: seed,
            intensityMultiplier: intensityMultiplier
        )
    }

    /// Generates motion from explicit parameters (for custom tuning).
    func generateMotionOffset(
        params: MotionParameters,
        time: Float,
        seed: UInt64,
        intensityMultiplier: Float = 1.0
    ) -> MotionOffset {
        let seedF = Float(seed % 10000) * 0.1

        // Base noise layers
        let posX = layeredNoise(time: time, freq: params.frequency, scale: params.noiseScale, seed: seedF)
        let posY = layeredNoise(time: time, freq: params.frequency * 1.1, scale: params.noiseScale, seed: seedF + 100)
        let posZ = layeredNoise(time: time, freq: params.frequency * 0.9, scale: params.noiseScale, seed: seedF + 200)

        let rotX = layeredNoise(time: time, freq: params.frequency * 1.3, scale: params.noiseScale, seed: seedF + 300)
        let rotY = layeredNoise(time: time, freq: params.frequency * 0.8, scale: params.noiseScale, seed: seedF + 400)
        let rotZ = layeredNoise(time: time, freq: params.frequency * 1.05, scale: params.noiseScale, seed: seedF + 500)

        // Apply per-axis amplitudes
        var position = SIMD3<Float>(
            posX * params.positionAmplitude.x,
            posY * params.positionAmplitude.y,
            posZ * params.positionAmplitude.z
        )

        var rotation = SIMD3<Float>(
            rotX * params.rotationAmplitude.x,
            rotY * params.rotationAmplitude.y,
            rotZ * params.rollAmount
        )

        // Add breathing cycle (periodic vertical oscillation)
        if params.breathingCycle > 0.001 {
            let breathFreq: Float = 0.25  // ~15 breaths/minute
            let breathPhase = sin(time * breathFreq * 2.0 * .pi + seedF)
            position.y += breathPhase * params.breathingCycle * 0.01
        }

        // Add step bounce (periodic vertical impulse)
        if params.stepBounce > 0.001 {
            let stepFreq: Float = 1.8  // ~1.8 steps/second (walking pace)
            let stepPhase = abs(sin(time * stepFreq * .pi + seedF * 0.5))
            let bounce = stepPhase * stepPhase * params.stepBounce * 0.008
            position.y += bounce
        }

        // Apply global intensity
        position *= intensityMultiplier
        rotation *= intensityMultiplier

        return MotionOffset(position: position, rotation: rotation)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Inertia Smoothing
    // ═══════════════════════════════════════════════════════════════════════

    /// Applies inertia smoothing between frames.
    /// Call this each frame to get smooth, physically-weighted motion.
    func applyInertia(
        current: MotionOffset,
        previous: MotionOffset,
        inertia: Float,
        damping: Float
    ) -> MotionOffset {
        let i = max(0.0, min(1.0, inertia))
        let d = max(0.0, min(1.0, damping))

        let smoothedPos = simd_mix(current.position, previous.position, SIMD3<Float>(repeating: i))
        let smoothedRot = simd_mix(current.rotation, previous.rotation, SIMD3<Float>(repeating: i))

        return MotionOffset(
            position: smoothedPos * d,
            rotation: smoothedRot * d
        )
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Noise Functions
    // ═══════════════════════════════════════════════════════════════════════

    /// Layered Perlin-style noise with 3 octaves for organic motion.
    private func layeredNoise(time: Float, freq: Float, scale: Float, seed: Float) -> Float {
        let t = time + seed

        // 3-octave noise
        let n1 = smoothNoise(t * freq * 1.0) * 1.0
        let n2 = smoothNoise(t * freq * 2.0 + 17.3) * 0.5
        let n3 = smoothNoise(t * freq * 4.0 + 31.7) * 0.25

        return (n1 + n2 + n3) * scale / 1.75  // Normalise
    }

    /// Simple smooth noise using sine combinations (cheap Perlin approximation).
    /// Avoids the need for a full Perlin noise library while maintaining
    /// organic, non-repeating characteristics.
    private func smoothNoise(_ t: Float) -> Float {
        // Combine incommensurate frequencies for pseudo-random behavior
        let a = sin(t * 1.0000)
        let b = sin(t * 2.3117 + 1.234)
        let c = sin(t * 3.7921 + 5.678)
        let d = sin(t * 0.5731 + 3.456)
        let e = sin(t * 7.1193 + 2.345)

        return (a + b * 0.7 + c * 0.5 + d * 0.3 + e * 0.15) / 2.65
    }
}

// MARK: - MotionOffset

/// Position and rotation offsets generated by the motion engine.
/// Applied additively to the camera's base transform.
struct MotionOffset {
    /// Position offset in scene units (metres)
    var position: SIMD3<Float>

    /// Rotation offset in radians (pitch, yaw, roll)
    var rotation: SIMD3<Float>

    /// Zero offset — no motion
    static let zero = MotionOffset(
        position: .zero,
        rotation: .zero
    )

    /// Convert rotation to a quaternion for application to entity transforms
    var rotationQuaternion: simd_quatf {
        let pitch = simd_quatf(angle: rotation.x, axis: SIMD3<Float>(1, 0, 0))
        let yaw   = simd_quatf(angle: rotation.y, axis: SIMD3<Float>(0, 1, 0))
        let roll  = simd_quatf(angle: rotation.z, axis: SIMD3<Float>(0, 0, 1))
        return pitch * yaw * roll
    }
}
