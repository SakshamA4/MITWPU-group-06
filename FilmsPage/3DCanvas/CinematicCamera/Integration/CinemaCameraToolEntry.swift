//
//  CinemaCameraToolEntry.swift
//  FilmsPage
//
//  Exposes the cinematic camera system in the app's tool palette
//  and object library. Provides the entry point for spawning cinema
//  cameras from the add-object menu with preset configurations.
//

import UIKit
import RealityKit

// MARK: - Cinema Camera Preset

/// Pre-configured cinema camera setups for quick spawning.
struct CinemaCameraPreset: Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let iconSystemName: String
    let body: CinemaCameraBody
    let lens: CinemaLensFamily
    let focalLength: Float
    let look: CinematicLook?
    let motionStyle: CameraMotionStyle
    let aspectRatio: CinemaAspectRatioPreset
}

// MARK: - Preset Library

enum CinemaCameraPresetLibrary {
    
    /// All available cinema camera presets for the tool palette.
    static var allPresets: [CinemaCameraPreset] {
        let cameras = CinemaCameraDatabase.allCameras
        let lenses = CinemaLensDatabase.allFamilies
        let looks = CinematicLookDatabase.allLooks
        
        // Safe lookups with fallbacks
        func camera(_ name: String) -> CinemaCameraBody {
            cameras.first { $0.modelName.contains(name) } ?? cameras[0]
        }
        func lens(_ name: String) -> CinemaLensFamily {
            lenses.first { $0.displayName.contains(name) } ?? lenses[0]
        }
        func look(_ name: String) -> CinematicLook? {
            looks.first { $0.name.contains(name) }
        }
        
        return [
            CinemaCameraPreset(
                id: "preset_cinematic_standard",
                name: "Cinematic Standard",
                subtitle: "ARRI Alexa Mini LF • Cooke S4/i 35mm",
                iconSystemName: "film",
                body: camera("Alexa Mini LF"),
                lens: lens("Cooke"),
                focalLength: 35,
                look: look("Kodak"),
                motionStyle: .tripod,
                aspectRatio: .anamorphicScope
            ),
            CinemaCameraPreset(
                id: "preset_documentary",
                name: "Documentary",
                subtitle: "Sony FX6 • Zeiss CP.3 50mm",
                iconSystemName: "video",
                body: camera("FX6"),
                lens: lens("Zeiss"),
                focalLength: 50,
                look: look("Clean"),
                motionStyle: .handheld,
                aspectRatio: .hdWidescreen
            ),
            CinemaCameraPreset(
                id: "preset_anamorphic",
                name: "Anamorphic Wide",
                subtitle: "ARRI Alexa 35 • Atlas Orion 40mm",
                iconSystemName: "rectangle.expand.vertical",
                body: camera("Alexa 35"),
                lens: lens("Atlas"),
                focalLength: 40,
                look: look("Fuji"),
                motionStyle: .dolly,
                aspectRatio: .anamorphicScope
            ),
            CinemaCameraPreset(
                id: "preset_indie",
                name: "Indie Film",
                subtitle: "Blackmagic 6K • Vintage 28mm",
                iconSystemName: "camera",
                body: camera("Pocket"),
                lens: lens("Canon"),
                focalLength: 28,
                look: look("Vintage"),
                motionStyle: .shoulderRig,
                aspectRatio: .flat
            ),
            CinemaCameraPreset(
                id: "preset_commercial",
                name: "Commercial",
                subtitle: "RED V-Raptor • ARRI Signature 85mm",
                iconSystemName: "sparkles.tv",
                body: camera("V-RAPTOR"),
                lens: lens("Signature"),
                focalLength: 85,
                look: look("Commercial"),
                motionStyle: .steadicam,
                aspectRatio: .hdWidescreen
            ),
            CinemaCameraPreset(
                id: "preset_custom",
                name: "Custom Camera",
                subtitle: "Choose your own setup",
                iconSystemName: "slider.horizontal.3",
                body: cameras[0],
                lens: lenses[0],
                focalLength: 50,
                look: nil,
                motionStyle: .tripod,
                aspectRatio: .hdWidescreen
            )
        ]
    }
}

// MARK: - Tool Palette Entry

/// Provides the data needed to register cinema cameras in
/// the app's add-object tool palette / library panel.
struct CinemaCameraToolEntry {
    
    /// Section title for the tool palette
    static let sectionTitle = "Cinema Camera"
    
    /// Section icon
    static let sectionIcon = "video.fill"
    
    /// Returns tool palette items for all cinema presets.
    static var paletteItems: [(title: String, subtitle: String, icon: String, id: String)] {
        CinemaCameraPresetLibrary.allPresets.map { preset in
            (title: preset.name,
             subtitle: preset.subtitle,
             icon: preset.iconSystemName,
             id: preset.id)
        }
    }
    
    /// Spawns a cinema camera from a preset ID via CanvasViewController.
    static func spawn(presetID: String, in viewController: CanvasViewController) {
        guard let preset = CinemaCameraPresetLibrary.allPresets.first(where: { $0.id == presetID }) else {
            return
        }
        
        if preset.id == "preset_custom" {
            // Present the full camera body picker for custom setup
            let picker = CinemaCameraBodyPicker()
            picker.onCameraSelected = { body in
                picker.dismiss(animated: true) {
                    viewController.spawnCinemaCamera(
                        body: body,
                        lens: CinemaLensDatabase.defaultFamily,
                        focalLength: 50,
                        look: CinematicLookDatabase.allLooks.first
                    )
                }
            }
            viewController.present(picker, animated: true)
        } else {
            viewController.spawnCinemaCamera(
                body: preset.body,
                lens: preset.lens,
                focalLength: preset.focalLength,
                look: preset.look,
                motionStyle: preset.motionStyle,
                aspectRatio: preset.aspectRatio
            )
        }
    }
}
