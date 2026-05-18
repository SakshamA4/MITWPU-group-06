//
//  WallCreationViewModel.swift
//  FilmsPage
//
//  ObservableObject driving the wall creation sheet.
//  Manages dimensions, material config, and communicates
//  the final configuration back via a closure.
//

import SwiftUI
import Combine

// MARK: - WallCreationViewModel

final class WallCreationViewModel: ObservableObject {

    // MARK: - Dimensions

    @Published var width: Float = 1.5
    @Published var height: Float = 1.2
    @Published var thickness: Float = 0.05

    // MARK: - Ratio Lock

    @Published var ratioLocked: Bool = false
    @Published var ratioWidth: String = ""
    @Published var ratioHeight: String = ""

    // MARK: - Material

    @Published var selectedPresetID: String = "concrete"
    @Published var selectedCategory: TextureCategory = .stone
    @Published var roughness: Float = 0.85
    @Published var metallic: Float = 0.0
    @Published var opacity: Float = 1.0
    @Published var tilingScale: Float = 1.0
    @Published var tintColor: Color = .white
    @Published var reflectionIntensity: Float = 0.05

    /// Confirmation callback. Passes (width, height, thickness, materialConfig, aspectRatio).
    var onConfirm: ((Float, Float, Float, CinematicMaterialConfig, CGSize?) -> Void)?

    /// Cancellation callback.
    var onCancel: (() -> Void)?

    // MARK: - Computed

    var materialConfig: CinematicMaterialConfig {
        var config = CinematicMaterialConfig()
        config.presetID = selectedPresetID
        config.roughness = roughness
        config.metallic = metallic
        config.opacity = opacity
        config.tilingScale = tilingScale
        config.reflectionIntensity = reflectionIntensity

        let uiColor = UIColor(tintColor)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        config.tintR = Float(r); config.tintG = Float(g)
        config.tintB = Float(b); config.tintA = Float(a)
        return config
    }

    var availablePresets: [TexturePreset] {
        TexturePresetLibrary.wallPresets
    }

    var categories: [TextureCategory] {
        TexturePresetLibrary.wallCategories
    }

    // MARK: - Actions

    func selectPreset(_ preset: TexturePreset) {
        selectedPresetID = preset.id
        roughness = preset.defaultRoughness
        metallic = preset.defaultMetallic
        opacity = preset.defaultOpacity
        reflectionIntensity = preset.defaultReflection

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    func confirm() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        var aspectRatio: CGSize?
        if ratioLocked,
           let rw = Float(ratioWidth), let rh = Float(ratioHeight),
           rw > 0, rh > 0 {
            aspectRatio = CGSize(width: CGFloat(rw), height: CGFloat(rh))
        }

        onConfirm?(width, height, thickness, materialConfig, aspectRatio)
    }

    func cancel() {
        onCancel?()
    }
}
