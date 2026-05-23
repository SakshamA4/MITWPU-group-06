//
//  LensSimulationEngine.swift
//  FilmsPage
//
//  CPU-side lens optical simulation calculations.
//  Provides math for distortion, vignette, chromatic aberration,
//  and breathing. These functions are used both for CPU fallback
//  and to generate parameters for the Metal shader pipeline.
//

import Foundation
import simd

// MARK: - LensSimulationEngine

/// Calculates lens optical effects using physically-inspired math.
/// Used to prepare shader uniforms and for CPU-side fallback rendering.
final class LensSimulationEngine {

    static let shared = LensSimulationEngine()
    private init() {}

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Barrel / Pincushion Distortion
    // ═══════════════════════════════════════════════════════════════════════

    /// Applies Brown–Conrady radial distortion to a normalised UV coordinate.
    ///
    /// - Parameters:
    ///   - uv: Normalised coordinate (0–1), with (0.5, 0.5) as centre
    ///   - k1: First radial distortion coefficient (+ = barrel, - = pincushion)
    ///   - k2: Second radial distortion coefficient (higher-order)
    /// - Returns: Distorted UV coordinate
    func applyRadialDistortion(uv: SIMD2<Float>, k1: Float, k2: Float) -> SIMD2<Float> {
        // Centre-relative coordinates
        let centered = uv - SIMD2<Float>(0.5, 0.5)
        let r2 = simd_dot(centered, centered)
        let r4 = r2 * r2

        // Distortion factor
        let factor = 1.0 + k1 * r2 + k2 * r4

        // Apply and re-centre
        return centered * factor + SIMD2<Float>(0.5, 0.5)
    }

    /// Inverse distortion lookup — finds the source UV for a given output UV.
    /// Uses Newton's method for 4 iterations (sufficient for cinema-range distortion).
    func inverseRadialDistortion(uv: SIMD2<Float>, k1: Float, k2: Float) -> SIMD2<Float> {
        var guess = uv
        for _ in 0..<4 {
            let distorted = applyRadialDistortion(uv: guess, k1: k1, k2: k2)
            let error = distorted - uv
            guess = guess - error
        }
        return guess
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Anamorphic Stretch
    // ═══════════════════════════════════════════════════════════════════════

    /// Applies anamorphic horizontal squeeze/stretch to a UV coordinate.
    ///
    /// - Parameters:
    ///   - uv: Normalised coordinate (0–1)
    ///   - squeezeRatio: Anamorphic squeeze (2.0 = classic 2x anamorphic)
    /// - Returns: Stretched UV for sampling
    func applyAnamorphicStretch(uv: SIMD2<Float>, squeezeRatio: Float) -> SIMD2<Float> {
        guard squeezeRatio > 1.0 else { return uv }
        let centered = uv - SIMD2<Float>(0.5, 0.5)
        let stretched = SIMD2<Float>(centered.x * squeezeRatio, centered.y)
        return stretched + SIMD2<Float>(0.5, 0.5)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Vignette
    // ═══════════════════════════════════════════════════════════════════════

    /// Calculates vignette darkening factor at a given UV position.
    ///
    /// - Parameters:
    ///   - uv: Normalised coordinate (0–1)
    ///   - strength: Vignette intensity (0 = none, 1 = heavy)
    ///   - falloffStart: Where vignette begins (0 = from centre, 1 = only corners)
    /// - Returns: Brightness multiplier (1.0 = no darkening, 0.0 = black)
    func calculateVignette(
        uv: SIMD2<Float>,
        strength: Float,
        falloffStart: Float
    ) -> Float {
        guard strength > 0.001 else { return 1.0 }

        let centered = uv - SIMD2<Float>(0.5, 0.5)
        let dist = simd_length(centered) * 2.0  // 0 at centre, ~1.414 at corners

        // Smooth falloff curve
        let normalized = max(0.0, (dist - falloffStart) / max(0.001, 1.0 - falloffStart))
        let falloff = normalized * normalized  // Quadratic falloff

        return max(0.0, 1.0 - falloff * strength)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Chromatic Aberration
    // ═══════════════════════════════════════════════════════════════════════

    /// Calculates per-channel UV offsets for lateral chromatic aberration.
    /// Red shifts outward, blue shifts inward (typical for most lenses).
    ///
    /// - Parameters:
    ///   - uv: Normalised coordinate (0–1)
    ///   - amount: CA intensity (0 = none, 1 = heavy)
    /// - Returns: Three UV coordinates for (R, G, B) channel sampling
    func calculateChromaticAberration(
        uv: SIMD2<Float>,
        amount: Float
    ) -> (r: SIMD2<Float>, g: SIMD2<Float>, b: SIMD2<Float>) {
        guard amount > 0.001 else { return (uv, uv, uv) }

        let centered = uv - SIMD2<Float>(0.5, 0.5)
        let dist = simd_length(centered)

        // CA increases toward edges (proportional to distance squared)
        let caScale = amount * 0.02 * dist * dist

        let direction = dist > 0.001 ? simd_normalize(centered) : SIMD2<Float>(0, 0)

        // Red shifts outward, blue shifts inward, green stays
        let rUV = uv + direction * caScale
        let gUV = uv
        let bUV = uv - direction * caScale

        return (rUV, gUV, bUV)
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Edge Softness
    // ═══════════════════════════════════════════════════════════════════════

    /// Calculates a blur radius multiplier for edge softness simulation.
    /// Centre of frame = sharp, edges = progressively softer.
    ///
    /// - Parameters:
    ///   - uv: Normalised coordinate (0–1)
    ///   - edgeSoftness: Softness amount (0 = sharp to edges, 1 = very soft)
    /// - Returns: Blur kernel radius in pixels (0 = no blur)
    func calculateEdgeBlurRadius(
        uv: SIMD2<Float>,
        edgeSoftness: Float,
        maxRadiusPx: Float = 4.0
    ) -> Float {
        guard edgeSoftness > 0.001 else { return 0.0 }

        let centered = uv - SIMD2<Float>(0.5, 0.5)
        let dist = simd_length(centered) * 2.0  // 0–1.414

        // Cubic falloff — sharp centre, soft edges
        let normalized = min(1.0, dist)
        let softness = normalized * normalized * normalized

        return softness * edgeSoftness * maxRadiusPx
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Shader Uniform Generation
    // ═══════════════════════════════════════════════════════════════════════

    /// Generates a complete set of shader-ready parameters from a lens profile.
    /// This is the main interface between the model layer and the Metal pipeline.
    func generateShaderUniforms(
        profile: LensOpticalProfile,
        anamorphicMode: AnamorphicMode,
        breathingMode: CineBreathingMode,
        focusDistance: Float
    ) -> LensShaderUniforms {
        return LensShaderUniforms(
            distortionK1: profile.distortionK1,
            distortionK2: profile.distortionK2,
            vignetteStrength: profile.vignetteStrength,
            vignetteFalloffStart: profile.vignetteFalloffStart,
            edgeSoftness: profile.edgeSoftness,
            chromaticAberration: profile.chromaticAberration,
            bloomStrength: profile.bloomStrength,
            halationStrength: profile.halationStrength,
            flareIntensity: profile.flareIntensity,
            flareWarmth: profile.flareWarmth,
            anamorphicSqueeze: anamorphicMode.squeezeRatio,
            anamorphicFlareStreak: profile.anamorphicFlareStreak,
            anamorphicBokehOval: profile.anamorphicBokehOval,
            breathingAmount: profile.breathingAmount * breathingMode.breathingMultiplier,
            focusDistance: focusDistance
        )
    }
}

// MARK: - Lens Shader Uniforms

/// Packed uniform buffer for the Metal lens simulation shader.
/// Matches the layout expected by CinematicLensShader.metal.
struct LensShaderUniforms {
    var distortionK1: Float
    var distortionK2: Float
    var vignetteStrength: Float
    var vignetteFalloffStart: Float
    var edgeSoftness: Float
    var chromaticAberration: Float
    var bloomStrength: Float
    var halationStrength: Float
    var flareIntensity: Float
    var flareWarmth: Float
    var anamorphicSqueeze: Float
    var anamorphicFlareStreak: Float
    var anamorphicBokehOval: Float
    var breathingAmount: Float
    var focusDistance: Float

    /// Identity uniforms — no optical effects
    static let identity = LensShaderUniforms(
        distortionK1: 0, distortionK2: 0,
        vignetteStrength: 0, vignetteFalloffStart: 1,
        edgeSoftness: 0, chromaticAberration: 0,
        bloomStrength: 0, halationStrength: 0,
        flareIntensity: 0, flareWarmth: 0.5,
        anamorphicSqueeze: 1, anamorphicFlareStreak: 0,
        anamorphicBokehOval: 0, breathingAmount: 0,
        focusDistance: 5.0
    )
}
