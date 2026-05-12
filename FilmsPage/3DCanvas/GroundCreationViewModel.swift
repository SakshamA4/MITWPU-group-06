//
//  GroundCreationViewModel.swift
//  FilmsPage
//
//  ObservableObject driving the ground creation sheet.
//  Manages size, material config, and communicates
//  the final configuration back via a closure.
//

import SwiftUI
import Combine

// MARK: - GroundCreationViewModel

final class GroundCreationViewModel: ObservableObject {

    // MARK: - Dimensions

    @Published var size: Float = 4.0

    // MARK: - Material

    @Published var selectedPresetID: String = "concrete"
    @Published var selectedCategory: TextureCategory = .natural
    @Published var roughness: Float = 0.85
    @Published var metallic: Float = 0.0
    @Published var opacity: Float = 1.0
    @Published var tilingScale: Float = 1.0
    @Published var tintColor: Color = .white
    @Published var reflectionIntensity: Float = 0.05

    /// Confirmation callback. Passes (size, materialConfig).
    var onConfirm: ((Float, CinematicMaterialConfig) -> Void)?

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
        TexturePresetLibrary.groundPresets
    }

    var categories: [TextureCategory] {
        TexturePresetLibrary.groundCategories
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
        onConfirm?(size, materialConfig)
    }

    func cancel() {
        onCancel?()
    }
}
