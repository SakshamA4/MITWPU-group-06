//
//  CinemaCameraDatabase.swift
//  FilmsPage
//
//  Static database of professional cinema camera bodies with
//  physically accurate sensor dimensions, resolutions, and
//  color science profiles.
//
//  All sensor dimensions sourced from manufacturer specifications.
//  These presets drive the virtual camera simulation system.
//

import Foundation

// MARK: - CinemaCameraDatabase

/// Central registry of all available cinema camera body presets.
/// Organised by brand for UI picker navigation.
struct CinemaCameraDatabase {

    // MARK: - All Cameras

    /// Complete flat list of every camera in the database.
    static let allCameras: [CinemaCameraBody] = [
        // ARRI
        arriAlexaMiniLF,
        arriAlexa35,
        arriAlexaMini,
        arriAmira,
        // RED
        redKomodo,
        redVRaptor,
        redVRaptorXL,
        redKomodoX,
        // Sony
        sonyVenice2,
        sonyVenice,
        sonyFX9,
        sonyFX6,
        // Blackmagic
        blackmagicUrsaMiniPro12K,
        blackmagicUrsaMiniProG2,
        blackmagicPocketCinema6KPro,
        // Canon
        canonC500MarkII,
        canonC300MarkIII,
        canonC70,
        // Panavision
        panavisionDXL2,
        panavisionMillenniumDXL,
    ]

    /// Cameras grouped by brand, in display order.
    static let camerasByBrand: [(brand: CinemaCameraBrand, cameras: [CinemaCameraBody])] = [
        (.arri,       allCameras.filter { $0.brand == .arri }),
        (.red,        allCameras.filter { $0.brand == .red }),
        (.sony,       allCameras.filter { $0.brand == .sony }),
        (.blackmagic, allCameras.filter { $0.brand == .blackmagic }),
        (.canon,      allCameras.filter { $0.brand == .canon }),
        (.panavision, allCameras.filter { $0.brand == .panavision }),
    ]

    /// Find a camera by its unique ID.
    static func camera(byID id: String) -> CinemaCameraBody? {
        allCameras.first { $0.id == id }
    }

    /// Default camera for new cinema cameras.
    static var defaultCamera: CinemaCameraBody { arriAlexaMiniLF }

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - ARRI
    // ═══════════════════════════════════════════════════════════════════════

    static let arriAlexaMiniLF = CinemaCameraBody(
        id: "arri_alexa_mini_lf",
        brand: .arri,
        modelName: "Alexa Mini LF",
        sensor: CinemaSensor(
            id: "arri_lf_sensor",
            format: .largeFormat,
            sensorWidthMM: 36.70,
            sensorHeightMM: 25.54
        ),
        nativeResolution: CinemaResolution(width: 4448, height: 3096),
        openGateWidthMM: 36.70,
        openGateHeightMM: 25.54,
        dynamicRangeStops: 16.0,
        colorScience: ColorScienceProfile(
            name: "ARRI LogC4",
            logCurve: "LogC4",
            gamut: "ARRI Wide Gamut 4",
            warmthBias: 0.15,
            skinToneRendering: 0.95
        ),
        maxFPS: 40,
        shortDescription: "Large format cinema. Unmatched skin tones.",
        iconSystemName: "camera.fill"
    )

    static let arriAlexa35 = CinemaCameraBody(
        id: "arri_alexa_35",
        brand: .arri,
        modelName: "Alexa 35",
        sensor: CinemaSensor(
            id: "arri_a35_sensor",
            format: .super35,
            sensorWidthMM: 27.99,
            sensorHeightMM: 19.22
        ),
        nativeResolution: CinemaResolution(width: 4608, height: 3164),
        openGateWidthMM: 27.99,
        openGateHeightMM: 19.22,
        dynamicRangeStops: 17.0,
        colorScience: ColorScienceProfile(
            name: "ARRI LogC4",
            logCurve: "LogC4",
            gamut: "ARRI Wide Gamut 4",
            warmthBias: 0.12,
            skinToneRendering: 0.98
        ),
        maxFPS: 120,
        shortDescription: "Next-gen Super 35. 17 stops of dynamic range.",
        iconSystemName: "camera.fill"
    )

    static let arriAlexaMini = CinemaCameraBody(
        id: "arri_alexa_mini",
        brand: .arri,
        modelName: "Alexa Mini",
        sensor: CinemaSensor(
            id: "arri_mini_sensor",
            format: .super35,
            sensorWidthMM: 28.25,
            sensorHeightMM: 18.17
        ),
        nativeResolution: CinemaResolution(width: 3424, height: 2202),
        openGateWidthMM: 28.25,
        openGateHeightMM: 18.17,
        dynamicRangeStops: 14.0,
        colorScience: ColorScienceProfile(
            name: "ARRI LogC3",
            logCurve: "LogC3",
            gamut: "ARRI Wide Gamut 3",
            warmthBias: 0.18,
            skinToneRendering: 0.92
        ),
        maxFPS: 200,
        shortDescription: "The industry workhorse. Compact and reliable.",
        iconSystemName: "camera.fill"
    )

    static let arriAmira = CinemaCameraBody(
        id: "arri_amira",
        brand: .arri,
        modelName: "Amira",
        sensor: CinemaSensor(
            id: "arri_amira_sensor",
            format: .super35,
            sensorWidthMM: 23.76,
            sensorHeightMM: 13.37
        ),
        nativeResolution: CinemaResolution(width: 3200, height: 1800),
        openGateWidthMM: 23.76,
        openGateHeightMM: 13.37,
        dynamicRangeStops: 14.0,
        colorScience: ColorScienceProfile(
            name: "ARRI LogC3",
            logCurve: "LogC3",
            gamut: "ARRI Wide Gamut 3",
            warmthBias: 0.15,
            skinToneRendering: 0.90
        ),
        maxFPS: 200,
        shortDescription: "Documentary & ENG cinema camera.",
        iconSystemName: "camera.fill"
    )

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - RED
    // ═══════════════════════════════════════════════════════════════════════

    static let redKomodo = CinemaCameraBody(
        id: "red_komodo",
        brand: .red,
        modelName: "Komodo 6K",
        sensor: CinemaSensor(
            id: "red_komodo_sensor",
            format: .super35,
            sensorWidthMM: 27.03,
            sensorHeightMM: 14.26
        ),
        nativeResolution: CinemaResolution(width: 6144, height: 3240),
        openGateWidthMM: 27.03,
        openGateHeightMM: 14.26,
        dynamicRangeStops: 16.0,
        colorScience: ColorScienceProfile(
            name: "IPP2",
            logCurve: "Log3G10",
            gamut: "REDWideGamutRGB",
            warmthBias: -0.05,
            skinToneRendering: 0.78
        ),
        maxFPS: 40,
        shortDescription: "Compact 6K cinema. Global shutter.",
        iconSystemName: "camera.fill"
    )

    static let redVRaptor = CinemaCameraBody(
        id: "red_v_raptor",
        brand: .red,
        modelName: "V-Raptor 8K",
        sensor: CinemaSensor(
            id: "red_vraptor_sensor",
            format: .vistaVision,
            sensorWidthMM: 40.96,
            sensorHeightMM: 21.60
        ),
        nativeResolution: CinemaResolution(width: 8192, height: 4320),
        openGateWidthMM: 40.96,
        openGateHeightMM: 21.60,
        dynamicRangeStops: 17.0,
        colorScience: ColorScienceProfile(
            name: "IPP2",
            logCurve: "Log3G10",
            gamut: "REDWideGamutRGB",
            warmthBias: -0.08,
            skinToneRendering: 0.82
        ),
        maxFPS: 120,
        shortDescription: "8K VistaVision. Maximum resolution.",
        iconSystemName: "camera.fill"
    )

    static let redVRaptorXL = CinemaCameraBody(
        id: "red_v_raptor_xl",
        brand: .red,
        modelName: "V-Raptor XL 8K",
        sensor: CinemaSensor(
            id: "red_vraptor_xl_sensor",
            format: .vistaVision,
            sensorWidthMM: 40.96,
            sensorHeightMM: 21.60
        ),
        nativeResolution: CinemaResolution(width: 8192, height: 4320),
        openGateWidthMM: 40.96,
        openGateHeightMM: 21.60,
        dynamicRangeStops: 17.0,
        colorScience: ColorScienceProfile(
            name: "IPP2",
            logCurve: "Log3G10",
            gamut: "REDWideGamutRGB",
            warmthBias: -0.08,
            skinToneRendering: 0.82
        ),
        maxFPS: 150,
        shortDescription: "Studio 8K VistaVision. Extended I/O.",
        iconSystemName: "camera.fill"
    )

    static let redKomodoX = CinemaCameraBody(
        id: "red_komodo_x",
        brand: .red,
        modelName: "Komodo-X 6K",
        sensor: CinemaSensor(
            id: "red_komodo_x_sensor",
            format: .super35,
            sensorWidthMM: 29.90,
            sensorHeightMM: 15.77
        ),
        nativeResolution: CinemaResolution(width: 6144, height: 3240),
        openGateWidthMM: 29.90,
        openGateHeightMM: 15.77,
        dynamicRangeStops: 16.5,
        colorScience: ColorScienceProfile(
            name: "IPP2",
            logCurve: "Log3G10",
            gamut: "REDWideGamutRGB",
            warmthBias: -0.05,
            skinToneRendering: 0.80
        ),
        maxFPS: 80,
        shortDescription: "Upgraded Komodo. Enhanced dynamic range.",
        iconSystemName: "camera.fill"
    )

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Sony
    // ═══════════════════════════════════════════════════════════════════════

    static let sonyVenice2 = CinemaCameraBody(
        id: "sony_venice_2",
        brand: .sony,
        modelName: "Venice 2",
        sensor: CinemaSensor(
            id: "sony_venice2_sensor",
            format: .fullFrame,
            sensorWidthMM: 36.20,
            sensorHeightMM: 24.10
        ),
        nativeResolution: CinemaResolution(width: 8640, height: 5760),
        openGateWidthMM: 36.20,
        openGateHeightMM: 24.10,
        dynamicRangeStops: 16.0,
        colorScience: ColorScienceProfile(
            name: "S-Cinetone",
            logCurve: "S-Log3",
            gamut: "S-Gamut3.Cine",
            warmthBias: 0.05,
            skinToneRendering: 0.88
        ),
        maxFPS: 120,
        shortDescription: "8.6K full frame. Dual base ISO.",
        iconSystemName: "camera.fill"
    )

    static let sonyVenice = CinemaCameraBody(
        id: "sony_venice",
        brand: .sony,
        modelName: "Venice",
        sensor: CinemaSensor(
            id: "sony_venice_sensor",
            format: .fullFrame,
            sensorWidthMM: 36.20,
            sensorHeightMM: 24.10
        ),
        nativeResolution: CinemaResolution(width: 6048, height: 4032),
        openGateWidthMM: 36.20,
        openGateHeightMM: 24.10,
        dynamicRangeStops: 15.0,
        colorScience: ColorScienceProfile(
            name: "S-Cinetone",
            logCurve: "S-Log3",
            gamut: "S-Gamut3.Cine",
            warmthBias: 0.05,
            skinToneRendering: 0.85
        ),
        maxFPS: 60,
        shortDescription: "Full frame cinema. Beautiful color.",
        iconSystemName: "camera.fill"
    )

    static let sonyFX9 = CinemaCameraBody(
        id: "sony_fx9",
        brand: .sony,
        modelName: "FX9",
        sensor: CinemaSensor(
            id: "sony_fx9_sensor",
            format: .fullFrame,
            sensorWidthMM: 35.70,
            sensorHeightMM: 18.80
        ),
        nativeResolution: CinemaResolution(width: 6048, height: 3024),
        openGateWidthMM: 35.70,
        openGateHeightMM: 18.80,
        dynamicRangeStops: 15.0,
        colorScience: ColorScienceProfile(
            name: "S-Cinetone",
            logCurve: "S-Log3",
            gamut: "S-Gamut3.Cine",
            warmthBias: 0.08,
            skinToneRendering: 0.86
        ),
        maxFPS: 120,
        shortDescription: "Documentary full frame. Fast AF.",
        iconSystemName: "camera.fill"
    )

    static let sonyFX6 = CinemaCameraBody(
        id: "sony_fx6",
        brand: .sony,
        modelName: "FX6",
        sensor: CinemaSensor(
            id: "sony_fx6_sensor",
            format: .fullFrame,
            sensorWidthMM: 35.70,
            sensorHeightMM: 18.80
        ),
        nativeResolution: .uhd4K,
        openGateWidthMM: 35.70,
        openGateHeightMM: 18.80,
        dynamicRangeStops: 15.0,
        colorScience: ColorScienceProfile(
            name: "S-Cinetone",
            logCurve: "S-Log3",
            gamut: "S-Gamut3.Cine",
            warmthBias: 0.08,
            skinToneRendering: 0.84
        ),
        maxFPS: 120,
        shortDescription: "Compact full frame cinema.",
        iconSystemName: "camera.fill"
    )

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Blackmagic
    // ═══════════════════════════════════════════════════════════════════════

    static let blackmagicUrsaMiniPro12K = CinemaCameraBody(
        id: "bmd_ursa_mini_pro_12k",
        brand: .blackmagic,
        modelName: "URSA Mini Pro 12K",
        sensor: CinemaSensor(
            id: "bmd_12k_sensor",
            format: .super35,
            sensorWidthMM: 27.03,
            sensorHeightMM: 14.25
        ),
        nativeResolution: CinemaResolution(width: 12288, height: 6480),
        openGateWidthMM: 27.03,
        openGateHeightMM: 14.25,
        dynamicRangeStops: 14.0,
        colorScience: ColorScienceProfile(
            name: "Blackmagic Gen 5",
            logCurve: "BMDFilm Gen5",
            gamut: "Blackmagic Wide Gamut",
            warmthBias: 0.0,
            skinToneRendering: 0.75
        ),
        maxFPS: 60,
        shortDescription: "12K resolution. Maximum detail.",
        iconSystemName: "camera.fill"
    )

    static let blackmagicUrsaMiniProG2 = CinemaCameraBody(
        id: "bmd_ursa_mini_pro_g2",
        brand: .blackmagic,
        modelName: "URSA Mini Pro G2",
        sensor: CinemaSensor(
            id: "bmd_g2_sensor",
            format: .super35,
            sensorWidthMM: 25.34,
            sensorHeightMM: 14.25
        ),
        nativeResolution: CinemaResolution(width: 4608, height: 2592),
        openGateWidthMM: 25.34,
        openGateHeightMM: 14.25,
        dynamicRangeStops: 15.0,
        colorScience: ColorScienceProfile(
            name: "Blackmagic Gen 4",
            logCurve: "BMDFilm",
            gamut: "Blackmagic Design",
            warmthBias: 0.0,
            skinToneRendering: 0.72
        ),
        maxFPS: 300,
        shortDescription: "Versatile Super 35. High frame rate.",
        iconSystemName: "camera.fill"
    )

    static let blackmagicPocketCinema6KPro = CinemaCameraBody(
        id: "bmd_pocket_6k_pro",
        brand: .blackmagic,
        modelName: "Pocket Cinema 6K Pro",
        sensor: CinemaSensor(
            id: "bmd_pocket_6k_sensor",
            format: .super35,
            sensorWidthMM: 23.10,
            sensorHeightMM: 12.99
        ),
        nativeResolution: CinemaResolution(width: 6144, height: 3456),
        openGateWidthMM: 23.10,
        openGateHeightMM: 12.99,
        dynamicRangeStops: 13.0,
        colorScience: ColorScienceProfile(
            name: "Blackmagic Gen 5",
            logCurve: "BMDFilm Gen5",
            gamut: "Blackmagic Wide Gamut",
            warmthBias: 0.0,
            skinToneRendering: 0.70
        ),
        maxFPS: 60,
        shortDescription: "Affordable 6K cinema. EF mount.",
        iconSystemName: "camera.fill"
    )

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Canon
    // ═══════════════════════════════════════════════════════════════════════

    static let canonC500MarkII = CinemaCameraBody(
        id: "canon_c500_mk2",
        brand: .canon,
        modelName: "C500 Mark II",
        sensor: CinemaSensor(
            id: "canon_c500mk2_sensor",
            format: .fullFrame,
            sensorWidthMM: 38.10,
            sensorHeightMM: 20.10
        ),
        nativeResolution: CinemaResolution(width: 5952, height: 3140),
        openGateWidthMM: 38.10,
        openGateHeightMM: 20.10,
        dynamicRangeStops: 15.0,
        colorScience: ColorScienceProfile(
            name: "Canon Cinema Gamut",
            logCurve: "Canon Log 3",
            gamut: "Cinema Gamut",
            warmthBias: 0.10,
            skinToneRendering: 0.88
        ),
        maxFPS: 60,
        shortDescription: "Full frame cinema. Excellent AF.",
        iconSystemName: "camera.fill"
    )

    static let canonC300MarkIII = CinemaCameraBody(
        id: "canon_c300_mk3",
        brand: .canon,
        modelName: "C300 Mark III",
        sensor: CinemaSensor(
            id: "canon_c300mk3_sensor",
            format: .super35,
            sensorWidthMM: 26.20,
            sensorHeightMM: 13.80
        ),
        nativeResolution: .dci4K,
        openGateWidthMM: 26.20,
        openGateHeightMM: 13.80,
        dynamicRangeStops: 16.0,
        colorScience: ColorScienceProfile(
            name: "Canon Cinema Gamut",
            logCurve: "Canon Log 3",
            gamut: "Cinema Gamut",
            warmthBias: 0.10,
            skinToneRendering: 0.86
        ),
        maxFPS: 120,
        shortDescription: "DGO sensor. Incredible dynamic range.",
        iconSystemName: "camera.fill"
    )

    static let canonC70 = CinemaCameraBody(
        id: "canon_c70",
        brand: .canon,
        modelName: "C70",
        sensor: CinemaSensor(
            id: "canon_c70_sensor",
            format: .super35,
            sensorWidthMM: 26.20,
            sensorHeightMM: 13.80
        ),
        nativeResolution: .dci4K,
        openGateWidthMM: 26.20,
        openGateHeightMM: 13.80,
        dynamicRangeStops: 16.0,
        colorScience: ColorScienceProfile(
            name: "Canon Cinema Gamut",
            logCurve: "Canon Log 3",
            gamut: "Cinema Gamut",
            warmthBias: 0.10,
            skinToneRendering: 0.84
        ),
        maxFPS: 120,
        shortDescription: "Compact DGO cinema. RF mount.",
        iconSystemName: "camera.fill"
    )

    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Panavision
    // ═══════════════════════════════════════════════════════════════════════

    static let panavisionDXL2 = CinemaCameraBody(
        id: "panavision_dxl2",
        brand: .panavision,
        modelName: "DXL2",
        sensor: CinemaSensor(
            id: "pv_dxl2_sensor",
            format: .largeFormat,
            sensorWidthMM: 40.96,
            sensorHeightMM: 21.60
        ),
        nativeResolution: CinemaResolution(width: 8192, height: 4320),
        openGateWidthMM: 40.96,
        openGateHeightMM: 21.60,
        dynamicRangeStops: 16.0,
        colorScience: ColorScienceProfile(
            name: "Light Iron Color 2",
            logCurve: "Log3G10",
            gamut: "REDWideGamutRGB",
            warmthBias: 0.10,
            skinToneRendering: 0.90
        ),
        maxFPS: 60,
        shortDescription: "8K large format. Panavision ecosystem.",
        iconSystemName: "camera.fill"
    )

    static let panavisionMillenniumDXL = CinemaCameraBody(
        id: "panavision_millennium_dxl",
        brand: .panavision,
        modelName: "Millennium DXL",
        sensor: CinemaSensor(
            id: "pv_mdxl_sensor",
            format: .largeFormat,
            sensorWidthMM: 40.96,
            sensorHeightMM: 21.60
        ),
        nativeResolution: CinemaResolution(width: 8192, height: 4320),
        openGateWidthMM: 40.96,
        openGateHeightMM: 21.60,
        dynamicRangeStops: 15.0,
        colorScience: ColorScienceProfile(
            name: "Light Iron Color",
            logCurve: "Log3G10",
            gamut: "REDWideGamutRGB",
            warmthBias: 0.08,
            skinToneRendering: 0.88
        ),
        maxFPS: 60,
        shortDescription: "Original large format Panavision.",
        iconSystemName: "camera.fill"
    )
}
