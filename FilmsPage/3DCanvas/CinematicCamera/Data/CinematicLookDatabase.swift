//
//  CinematicLookDatabase.swift
//  FilmsPage
//
//  Built-in cinematic look presets. Each look defines a creative
//  color grading personality that layers on top of the technical
//  camera/lens simulation.
//

import Foundation

// MARK: - CinematicLookDatabase

struct CinematicLookDatabase {

    // MARK: - All Looks

    static let allLooks: [CinematicLook] = [
        cleanDigital, cookeWarm, zeissClinical, arriNatural,
        kodak5219, kodak5207, fujiEterna, vintage70s,
        bleachBypass, tealOrange, moonlight, desertHeat,
        highContrastBW, softBW,
    ]

    /// Looks grouped by category for the picker UI.
    static let looksByCategory: [(category: CinematicLookCategory, looks: [CinematicLook])] = [
        (.digital,   allLooks.filter { $0.category == .digital }),
        (.filmStock, allLooks.filter { $0.category == .filmStock }),
        (.vintage,   allLooks.filter { $0.category == .vintage }),
        (.stylised,  allLooks.filter { $0.category == .stylised }),
    ]

    static func look(byID id: String) -> CinematicLook? {
        allLooks.first { $0.id == id }
    }

    static var defaultLook: CinematicLook { cleanDigital }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Digital Looks
    // ═══════════════════════════════════════════════════════════════════════

    static let cleanDigital = CinematicLook(
        id: "clean_digital", name: "Clean Digital",
        category: .digital, character: "Neutral, modern, what-you-see-is-what-you-get",
        warmth: 0.0, tint: 0.0, saturation: 1.0, vibrance: 0.0,
        contrast: 1.0, highlightRolloff: 0.3, shadowLift: 0.0, midtoneShift: 0.0,
        bloomIntensity: 0.0, halationIntensity: 0.0,
        grainIntensity: 0.0, grainSize: 0.5
    )

    static let arriNatural = CinematicLook(
        id: "arri_natural", name: "ARRI Natural",
        category: .digital, character: "Clean with subtle warmth — ARRI's default Rec.709",
        warmth: 0.08, tint: 0.0, saturation: 0.95, vibrance: 0.05,
        contrast: 1.05, highlightRolloff: 0.55, shadowLift: 0.02, midtoneShift: 0.0,
        bloomIntensity: 0.03, halationIntensity: 0.02,
        grainIntensity: 0.02, grainSize: 0.3
    )

    static let zeissClinical = CinematicLook(
        id: "zeiss_clinical", name: "Zeiss Clinical",
        category: .digital, character: "Cool, sharp, scientific precision",
        warmth: -0.08, tint: 0.0, saturation: 0.90, vibrance: 0.0,
        contrast: 1.15, highlightRolloff: 0.25, shadowLift: 0.0, midtoneShift: 0.0,
        bloomIntensity: 0.0, halationIntensity: 0.0,
        grainIntensity: 0.01, grainSize: 0.2
    )

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Film Stock Looks
    // ═══════════════════════════════════════════════════════════════════════

    static let cookeWarm = CinematicLook(
        id: "cooke_warm", name: "Cooke Warm",
        category: .filmStock, character: "Warm, organic, flattering — classic film feel",
        warmth: 0.20, tint: 0.02, saturation: 0.92, vibrance: 0.08,
        contrast: 1.08, highlightRolloff: 0.65, shadowLift: 0.04, midtoneShift: 0.02,
        bloomIntensity: 0.12, halationIntensity: 0.10,
        grainIntensity: 0.08, grainSize: 0.45,
        shadowTintR: 0.05, shadowTintG: 0.02, shadowTintB: 0.0,
        highlightTintR: 0.08, highlightTintG: 0.06, highlightTintB: 0.02
    )

    static let kodak5219 = CinematicLook(
        id: "kodak_5219", name: "Kodak 5219",
        category: .filmStock, character: "Kodak Vision3 500T — warm tungsten, rich shadows",
        warmth: 0.15, tint: 0.0, saturation: 0.95, vibrance: 0.10,
        contrast: 1.12, highlightRolloff: 0.70, shadowLift: 0.03, midtoneShift: 0.0,
        bloomIntensity: 0.08, halationIntensity: 0.12,
        grainIntensity: 0.12, grainSize: 0.50,
        shadowTintR: 0.03, shadowTintG: 0.01, shadowTintB: 0.0,
        highlightTintR: 0.06, highlightTintG: 0.04, highlightTintB: 0.01
    )

    static let kodak5207 = CinematicLook(
        id: "kodak_5207", name: "Kodak 5207",
        category: .filmStock, character: "Kodak Vision3 250D — daylight, natural color",
        warmth: 0.05, tint: -0.02, saturation: 1.05, vibrance: 0.12,
        contrast: 1.08, highlightRolloff: 0.60, shadowLift: 0.02, midtoneShift: 0.0,
        bloomIntensity: 0.05, halationIntensity: 0.08,
        grainIntensity: 0.06, grainSize: 0.35,
        shadowTintR: 0.01, shadowTintG: 0.02, shadowTintB: 0.01,
        highlightTintR: 0.03, highlightTintG: 0.04, highlightTintB: 0.02
    )

    static let fujiEterna = CinematicLook(
        id: "fuji_eterna", name: "Fuji Eterna",
        category: .filmStock, character: "Cool, desaturated, elegant — Japanese cinema",
        warmth: -0.10, tint: 0.03, saturation: 0.82, vibrance: 0.0,
        contrast: 1.02, highlightRolloff: 0.55, shadowLift: 0.06, midtoneShift: -0.02,
        bloomIntensity: 0.06, halationIntensity: 0.05,
        grainIntensity: 0.10, grainSize: 0.40,
        shadowTintR: 0.0, shadowTintG: 0.02, shadowTintB: 0.05,
        highlightTintR: 0.02, highlightTintG: 0.03, highlightTintB: 0.04
    )

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Vintage Looks
    // ═══════════════════════════════════════════════════════════════════════

    static let vintage70s = CinematicLook(
        id: "vintage_70s", name: "70s Cinema",
        category: .vintage, character: "Heavy halation, warm grain, faded — 1970s film",
        warmth: 0.25, tint: 0.05, saturation: 0.78, vibrance: 0.0,
        contrast: 0.92, highlightRolloff: 0.80, shadowLift: 0.10, midtoneShift: 0.03,
        bloomIntensity: 0.22, halationIntensity: 0.25,
        grainIntensity: 0.20, grainSize: 0.65,
        shadowTintR: 0.06, shadowTintG: 0.03, shadowTintB: 0.0,
        highlightTintR: 0.10, highlightTintG: 0.07, highlightTintB: 0.02
    )

    static let bleachBypass = CinematicLook(
        id: "bleach_bypass", name: "Bleach Bypass",
        category: .vintage, character: "Desaturated, high contrast, gritty — Saving Private Ryan",
        warmth: -0.05, tint: 0.0, saturation: 0.55, vibrance: -0.10,
        contrast: 1.35, highlightRolloff: 0.20, shadowLift: 0.0, midtoneShift: 0.0,
        bloomIntensity: 0.05, halationIntensity: 0.03,
        grainIntensity: 0.15, grainSize: 0.55
    )

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Stylised Looks
    // ═══════════════════════════════════════════════════════════════════════

    static let tealOrange = CinematicLook(
        id: "teal_orange", name: "Teal & Orange",
        category: .stylised, character: "Blockbuster complementary color — Michael Bay",
        warmth: 0.10, tint: 0.0, saturation: 1.15, vibrance: 0.15,
        contrast: 1.18, highlightRolloff: 0.40, shadowLift: 0.02, midtoneShift: 0.0,
        bloomIntensity: 0.05, halationIntensity: 0.03,
        grainIntensity: 0.03, grainSize: 0.3,
        shadowTintR: 0.0, shadowTintG: 0.06, shadowTintB: 0.10,
        highlightTintR: 0.10, highlightTintG: 0.06, highlightTintB: 0.0
    )

    static let moonlight = CinematicLook(
        id: "moonlight", name: "Moonlight",
        category: .stylised, character: "Cool blue night, lifted shadows — moonlit scenes",
        warmth: -0.25, tint: 0.05, saturation: 0.70, vibrance: 0.0,
        contrast: 0.95, highlightRolloff: 0.50, shadowLift: 0.12, midtoneShift: -0.05,
        bloomIntensity: 0.15, halationIntensity: 0.08,
        grainIntensity: 0.08, grainSize: 0.45,
        shadowTintR: 0.02, shadowTintG: 0.04, shadowTintB: 0.12,
        highlightTintR: 0.04, highlightTintG: 0.06, highlightTintB: 0.10
    )

    static let desertHeat = CinematicLook(
        id: "desert_heat", name: "Desert Heat",
        category: .stylised, character: "Amber warmth, crushed blacks — Dune / Mad Max",
        warmth: 0.35, tint: -0.03, saturation: 0.88, vibrance: 0.05,
        contrast: 1.20, highlightRolloff: 0.35, shadowLift: 0.0, midtoneShift: 0.03,
        bloomIntensity: 0.10, halationIntensity: 0.08,
        grainIntensity: 0.06, grainSize: 0.40,
        shadowTintR: 0.08, shadowTintG: 0.04, shadowTintB: 0.0,
        highlightTintR: 0.12, highlightTintG: 0.08, highlightTintB: 0.0
    )

    static let highContrastBW = CinematicLook(
        id: "high_contrast_bw", name: "High Contrast B&W",
        category: .stylised, character: "Punchy monochrome — noir, dramatic",
        warmth: 0.0, tint: 0.0, saturation: 0.0, vibrance: 0.0,
        contrast: 1.40, highlightRolloff: 0.20, shadowLift: 0.0, midtoneShift: 0.0,
        bloomIntensity: 0.08, halationIntensity: 0.05,
        grainIntensity: 0.12, grainSize: 0.50
    )

    static let softBW = CinematicLook(
        id: "soft_bw", name: "Soft B&W",
        category: .stylised, character: "Gentle monochrome — lifted, dreamy, elegant",
        warmth: 0.05, tint: 0.0, saturation: 0.0, vibrance: 0.0,
        contrast: 0.85, highlightRolloff: 0.70, shadowLift: 0.08, midtoneShift: 0.0,
        bloomIntensity: 0.15, halationIntensity: 0.10,
        grainIntensity: 0.08, grainSize: 0.40
    )
}
