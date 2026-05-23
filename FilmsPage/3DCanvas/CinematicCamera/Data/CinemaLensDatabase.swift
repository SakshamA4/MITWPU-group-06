//
//  CinemaLensDatabase.swift
//  FilmsPage
//
//  Static database of professional cinema lens family presets.
//  Each family includes optical profiles and available focal lengths.
//

import Foundation

// MARK: - CinemaLensDatabase

struct CinemaLensDatabase {

    static let allFamilies: [CinemaLensFamily] = [
        cookeS4, arriSignaturePrime, zeissSupremePrime, leicaSummiluxC,
        canonK35, panavisionCSeries, hawkVLite, masterPrime, sigmaCine, vintageSoviet
    ]

    static func family(byID id: String) -> CinemaLensFamily? {
        allFamilies.first { $0.id == id }
    }

    static var defaultFamily: CinemaLensFamily { cookeS4 }

    // MARK: - Helpers

    private static func primes(_ mms: [(Float, Float)], override: LensOpticalProfile? = nil) -> [CinemaFocalLength] {
        mms.map { CinemaFocalLength(focalLengthMM: $0.0, opticalOverride: override, maxAperture: $0.1) }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Cooke S4/i
    // ═══════════════════════════════════════════════════════════════════════

    static let cookeS4 = CinemaLensFamily(
        id: "cooke_s4", brand: .cooke, familyName: "S4/i",
        anamorphicMode: .spherical,
        baseProfile: LensOpticalProfile(
            distortionK1: 0.02, distortionK2: 0.005,
            vignetteStrength: 0.25, vignetteFalloffStart: 0.55,
            edgeSoftness: 0.18, sharpnessCharacter: 0.72,
            chromaticAberration: 0.04, breathingAmount: 0.04,
            flareIntensity: 0.20, flareWarmth: 0.70,
            bloomStrength: 0.15, halationStrength: 0.10
        ),
        focalLengths: primes([(18,2.0),(25,1.4),(32,1.4),(40,1.4),(50,1.4),(75,1.4),(100,1.4),(135,2.0)]),
        character: "Warm, organic, flattering skin tones — the Cooke Look",
        isZoom: false
    )

    // MARK: - ARRI Signature Prime

    static let arriSignaturePrime = CinemaLensFamily(
        id: "arri_signature", brand: .arri, familyName: "Signature Prime",
        anamorphicMode: .spherical,
        baseProfile: LensOpticalProfile(
            distortionK1: 0.008, distortionK2: 0.002,
            vignetteStrength: 0.12, vignetteFalloffStart: 0.65,
            edgeSoftness: 0.08, sharpnessCharacter: 0.88,
            chromaticAberration: 0.02, breathingAmount: 0.02,
            flareIntensity: 0.18, flareWarmth: 0.55,
            bloomStrength: 0.08, halationStrength: 0.04
        ),
        focalLengths: primes([(12,2.8),(15,2.8),(18,1.8),(21,1.8),(25,1.8),(29,1.8),(35,1.8),(40,1.8),(47,1.8),(58,1.8),(75,1.8),(95,1.8),(125,1.8),(150,2.0),(200,2.8)]),
        character: "Clean, modern, precise with beautiful flares",
        isZoom: false
    )

    // MARK: - Zeiss Supreme Prime

    static let zeissSupremePrime = CinemaLensFamily(
        id: "zeiss_supreme", brand: .zeiss, familyName: "Supreme Prime",
        anamorphicMode: .spherical,
        baseProfile: LensOpticalProfile(
            distortionK1: 0.005, distortionK2: 0.001,
            vignetteStrength: 0.10, vignetteFalloffStart: 0.70,
            edgeSoftness: 0.05, sharpnessCharacter: 0.95,
            chromaticAberration: 0.015, breathingAmount: 0.015,
            flareIntensity: 0.10, flareWarmth: 0.45,
            bloomStrength: 0.05, halationStrength: 0.02
        ),
        focalLengths: primes([(15,2.1),(18,1.5),(21,1.5),(25,1.5),(29,1.5),(35,1.5),(50,1.5),(65,1.5),(85,1.5),(100,1.5),(135,1.5),(150,2.1),(200,2.1)]),
        character: "Ultra-sharp, clinical, scientific precision",
        isZoom: false
    )

    // MARK: - Leica Summilux-C

    static let leicaSummiluxC = CinemaLensFamily(
        id: "leica_summilux_c", brand: .leica, familyName: "Summilux-C",
        anamorphicMode: .spherical,
        baseProfile: LensOpticalProfile(
            distortionK1: 0.01, distortionK2: 0.003,
            vignetteStrength: 0.18, vignetteFalloffStart: 0.60,
            edgeSoftness: 0.12, sharpnessCharacter: 0.85,
            chromaticAberration: 0.025, breathingAmount: 0.025,
            flareIntensity: 0.12, flareWarmth: 0.50,
            bloomStrength: 0.10, halationStrength: 0.06
        ),
        focalLengths: primes([(16,1.4),(18,1.4),(21,1.4),(25,1.4),(29,1.4),(35,1.4),(40,1.4),(50,1.4),(65,1.4),(75,1.4),(100,1.4),(135,2.0)]),
        character: "Elegant, smooth, refined — Leica rendering",
        isZoom: false
    )

    // MARK: - Canon K35

    static let canonK35 = CinemaLensFamily(
        id: "canon_k35", brand: .canon, familyName: "K35",
        anamorphicMode: .spherical,
        baseProfile: LensOpticalProfile(
            distortionK1: 0.04, distortionK2: 0.01,
            vignetteStrength: 0.35, vignetteFalloffStart: 0.45,
            edgeSoftness: 0.30, sharpnessCharacter: 0.60,
            chromaticAberration: 0.08, breathingAmount: 0.08,
            flareIntensity: 0.35, flareWarmth: 0.75,
            bloomStrength: 0.25, halationStrength: 0.18
        ),
        focalLengths: primes([(18,1.5),(24,1.4),(35,1.4),(55,1.2),(85,1.3)]),
        character: "Vintage warmth, heavy flare, cinematic imperfection",
        isZoom: false
    )

    // MARK: - Panavision C-Series

    static let panavisionCSeries = CinemaLensFamily(
        id: "panavision_c_series", brand: .panavision, familyName: "C-Series Anamorphic",
        anamorphicMode: .anamorphic(squeeze: 2.0),
        baseProfile: LensOpticalProfile(
            distortionK1: 0.03, distortionK2: 0.008,
            vignetteStrength: 0.22, vignetteFalloffStart: 0.50,
            edgeSoftness: 0.20, sharpnessCharacter: 0.70,
            chromaticAberration: 0.06, breathingAmount: 0.05,
            flareIntensity: 0.30, flareWarmth: 0.65,
            bloomStrength: 0.18, halationStrength: 0.12,
            anamorphicFlareStreak: 0.65, anamorphicBokehOval: 0.80
        ),
        focalLengths: primes([(35,2.8),(40,2.8),(50,2.3),(65,2.3),(75,2.3),(100,2.8),(135,2.8),(180,3.5)]),
        character: "Classic Hollywood anamorphic — blue streak flares",
        isZoom: false
    )

    // MARK: - Hawk V-Lite Anamorphic

    static let hawkVLite = CinemaLensFamily(
        id: "hawk_v_lite", brand: .hawk, familyName: "V-Lite 2x Anamorphic",
        anamorphicMode: .anamorphic(squeeze: 2.0),
        baseProfile: LensOpticalProfile(
            distortionK1: 0.035, distortionK2: 0.01,
            vignetteStrength: 0.20, vignetteFalloffStart: 0.50,
            edgeSoftness: 0.15, sharpnessCharacter: 0.75,
            chromaticAberration: 0.05, breathingAmount: 0.04,
            flareIntensity: 0.28, flareWarmth: 0.60,
            bloomStrength: 0.15, halationStrength: 0.10,
            anamorphicFlareStreak: 0.55, anamorphicBokehOval: 0.75
        ),
        focalLengths: primes([(28,2.2),(35,2.2),(45,2.2),(55,2.2),(65,2.2),(80,2.2),(110,2.2),(140,2.8)]),
        character: "Modern anamorphic with controlled flare and bokeh",
        isZoom: false
    )

    // MARK: - Master Prime

    static let masterPrime = CinemaLensFamily(
        id: "master_prime", brand: .masterPrime, familyName: "Master Prime",
        anamorphicMode: .spherical,
        baseProfile: LensOpticalProfile(
            distortionK1: 0.003, distortionK2: 0.001,
            vignetteStrength: 0.08, vignetteFalloffStart: 0.75,
            edgeSoftness: 0.03, sharpnessCharacter: 0.98,
            chromaticAberration: 0.01, breathingAmount: 0.01,
            flareIntensity: 0.05, flareWarmth: 0.45,
            bloomStrength: 0.03, halationStrength: 0.01
        ),
        focalLengths: primes([(12,1.3),(14,1.3),(16,1.3),(18,1.3),(21,1.3),(25,1.3),(27,1.3),(32,1.3),(35,1.3),(40,1.3),(50,1.3),(65,1.3),(75,1.3),(100,1.3),(135,1.3),(150,2.0)]),
        character: "Ultra-sharp, ultra-fast — clinical precision",
        isZoom: false
    )

    // MARK: - Sigma Cine

    static let sigmaCine = CinemaLensFamily(
        id: "sigma_cine", brand: .sigma, familyName: "Cine FF High Speed",
        anamorphicMode: .spherical,
        baseProfile: LensOpticalProfile(
            distortionK1: 0.012, distortionK2: 0.003,
            vignetteStrength: 0.14, vignetteFalloffStart: 0.60,
            edgeSoftness: 0.08, sharpnessCharacter: 0.90,
            chromaticAberration: 0.03, breathingAmount: 0.03,
            flareIntensity: 0.08, flareWarmth: 0.50,
            bloomStrength: 0.06, halationStrength: 0.03
        ),
        focalLengths: primes([(14,2.0),(20,1.4),(24,1.4),(28,1.4),(35,1.4),(40,1.4),(50,1.4),(85,1.4),(105,1.4),(135,2.0)]),
        character: "Modern, sharp, excellent value — Art series DNA",
        isZoom: false
    )

    // MARK: - Vintage Soviet (Helios 44 family)

    static let vintageSoviet = CinemaLensFamily(
        id: "vintage_soviet", brand: .vintage, familyName: "Helios / Soviet Primes",
        anamorphicMode: .spherical,
        baseProfile: LensOpticalProfile(
            distortionK1: 0.06, distortionK2: 0.02,
            vignetteStrength: 0.45, vignetteFalloffStart: 0.35,
            edgeSoftness: 0.45, sharpnessCharacter: 0.45,
            chromaticAberration: 0.12, breathingAmount: 0.15,
            flareIntensity: 0.45, flareWarmth: 0.80,
            bloomStrength: 0.35, halationStrength: 0.25
        ),
        focalLengths: primes([(20,3.5),(28,2.8),(35,2.4),(44,2.0),(58,2.0),(85,2.0),(135,3.5)]),
        character: "Swirly bokeh, heavy flare, dreamy imperfection",
        isZoom: false
    )
}
