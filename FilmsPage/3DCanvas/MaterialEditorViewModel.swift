//
//  MaterialEditorViewModel.swift
//  FilmsPage
//
//  ObservableObject for the post-creation material editor sheet.
//  Holds a reference to the target ModelEntity and applies changes
//  live via CinematicMaterialManager.
//

import SwiftUI
import RealityKit
import Combine

// MARK: - MaterialEditorViewModel

@MainActor
final class MaterialEditorViewModel: ObservableObject {

    // MARK: - Material Properties

    @Published var selectedPresetID: String = "concrete"
    @Published var selectedCategory: TextureCategory = .stone
    @Published var roughness: Float = 0.7
    @Published var metallic: Float = 0.0
    @Published var opacity: Float = 1.0
    @Published var tilingScale: Float = 1.0
    @Published var tintColor: Color = .white
    @Published var reflectionIntensity: Float = 0.0

    // MARK: - Entity reference

    private weak var targetEntity: ModelEntity?
    private var isWall: Bool = true
    private var cancellables = Set<AnyCancellable>()

    /// Debounce timer for throttling material updates.
    private var updateWorkItem: DispatchWorkItem?

    /// Dismissal callback.
    var onDismiss: (() -> Void)?

    // MARK: - Init

    init() {
        // Observe all published properties for live updates
        setupLiveUpdates()
    }

    // MARK: - Configuration

    /// Call this to bind the editor to a specific entity.
    func configure(entity: ModelEntity, isWall: Bool) {
        self.targetEntity = entity
        self.isWall = isWall

        // Read existing material config if available
        if isWall, let comp = entity.components[CanvasViewController.WallComponent.self],
           let config = comp.materialConfig {
            loadFromConfig(config)
        } else if !isWall, let comp = entity.components[CanvasViewController.GroundComponent.self],
                  let config = comp.materialConfig {
            loadFromConfig(config)
        } else {
            // Legacy entity — use defaults based on current color
            if isWall, let comp = entity.components[CanvasViewController.WallComponent.self] {
                tintColor = Color(comp.uiColor)
            } else if let comp = entity.components[CanvasViewController.GroundComponent.self] {
                tintColor = Color(comp.uiColor)
            }
        }
    }

    private func loadFromConfig(_ config: CinematicMaterialConfig) {
        selectedPresetID = config.presetID
        roughness = config.roughness
        metallic = config.metallic
        opacity = config.opacity
        tilingScale = config.tilingScale
        reflectionIntensity = config.reflectionIntensity
        tintColor = Color(UIColor(red: CGFloat(config.tintR), green: CGFloat(config.tintG),
                                  blue: CGFloat(config.tintB), alpha: CGFloat(config.tintA)))

        // Set category based on preset
        if let preset = TexturePresetLibrary.preset(for: config.presetID) {
            selectedCategory = preset.category
        }
    }

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
        isWall ? TexturePresetLibrary.wallPresets : TexturePresetLibrary.groundPresets
    }

    var categories: [TextureCategory] {
        isWall ? TexturePresetLibrary.wallCategories : TexturePresetLibrary.groundCategories
    }

    // MARK: - Preset Selection

    func selectPreset(_ preset: TexturePreset) {
        selectedPresetID = preset.id
        roughness = preset.defaultRoughness
        metallic = preset.defaultMetallic
        opacity = preset.defaultOpacity
        reflectionIntensity = preset.defaultReflection

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    // MARK: - Live Update

    private func setupLiveUpdates() {
        // Combine all published properties into a single stream, debounced
        let properties = Publishers.CombineLatest4(
            $selectedPresetID, $roughness, $metallic, $opacity
        )
        let properties2 = Publishers.CombineLatest3(
            $tilingScale, $tintColor, $reflectionIntensity
        )

        Publishers.CombineLatest(properties, properties2)
            .debounce(for: .milliseconds(33), scheduler: RunLoop.main) // ~30fps
            .sink { [weak self] _ in
                self?.applyToEntity()
            }
            .store(in: &cancellables)
    }

    private func applyToEntity() {
        guard let entity = targetEntity else { return }
        let config = materialConfig

        // Update the component
        if isWall {
            if var comp = entity.components[CanvasViewController.WallComponent.self] {
                comp.materialConfig = config
                comp.uiColor = config.tintColor
                entity.components.set(comp)
            }
        } else {
            if var comp = entity.components[CanvasViewController.GroundComponent.self] {
                comp.materialConfig = config
                comp.uiColor = config.tintColor
                entity.components.set(comp)
            }
        }

        // Apply material asynchronously
        Task { @MainActor in
            await CinematicMaterialManager.shared.applyMaterial(config, to: entity)
        }
    }

    func dismiss() {
        onDismiss?()
    }
}
