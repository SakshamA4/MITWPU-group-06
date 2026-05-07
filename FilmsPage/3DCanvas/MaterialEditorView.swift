//
//  MaterialEditorView.swift
//  FilmsPage
//
//  Post-creation material editor sheet. Shown when a user
//  long-presses a wall or ground and selects "Edit Material".
//  All changes update live in the 3D scene.
//

import SwiftUI

// MARK: - MaterialEditorView

struct MaterialEditorView: View {
    @StateObject var viewModel = MaterialEditorViewModel()
    @Environment(\.colorScheme) var colorScheme

    let entity: Any  // ModelEntity (untyped to avoid RealityKit import in SwiftUI body)
    let isWall: Bool

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {

                        // MARK: - Live Preview
                        previewSection

                        // MARK: - Texture Selection
                        textureSection

                        // MARK: - Properties
                        propertiesSection

                        // MARK: - Tint
                        tintSection

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle(isWall ? "Wall Material" : "Ground Material")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { viewModel.dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            if let modelEntity = entity as? RealityKit.ModelEntity {
                viewModel.configure(entity: modelEntity, isWall: isWall)
            }
        }
    }

    // MARK: - Preview

    private var previewSection: some View {
        MaterialPreviewCard(
            config: viewModel.materialConfig,
            isWall: isWall,
            label: "Material Preview"
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Texture

    private var textureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Texture", icon: "paintbrush.fill")

            TextureCategoryPicker(
                categories: viewModel.categories,
                allPresets: viewModel.availablePresets,
                selectedCategory: $viewModel.selectedCategory,
                selectedPresetID: Binding(
                    get: { viewModel.selectedPresetID },
                    set: { newID in
                        if let preset = TexturePresetLibrary.preset(for: newID) {
                            viewModel.selectPreset(preset)
                        }
                    }
                ),
                tint: viewModel.tintColor
            )

            if let preset = TexturePresetLibrary.preset(for: viewModel.selectedPresetID) {
                HStack {
                    Image(systemName: preset.icon)
                        .foregroundColor(.blue)
                    Text(preset.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if preset.supportsTransparency {
                        Label("Transparent", systemImage: "eye.fill")
                            .font(.caption2)
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.cyan.opacity(0.15)))
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Properties

    private var propertiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Surface", icon: "slider.horizontal.3")

            VStack(spacing: 14) {
                SliderRow(label: "Roughness", value: $viewModel.roughness,
                          range: 0...1, unit: "")
                SliderRow(label: "Metallic", value: $viewModel.metallic,
                          range: 0...1, unit: "")
                SliderRow(label: "Opacity", value: $viewModel.opacity,
                          range: 0.05...1, unit: "")
                SliderRow(label: "Tiling", value: $viewModel.tilingScale,
                          range: 0.25...4.0, unit: "×")
                SliderRow(label: "Reflection", value: $viewModel.reflectionIntensity,
                          range: 0...1, unit: "")
            }
            .sectionCard()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Tint

    private var tintSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Tint Color", icon: "paintpalette.fill")

            ColorPicker("Surface Tint", selection: $viewModel.tintColor, supportsOpacity: false)
                .padding(.horizontal, 4)
                .sectionCard()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(isWall ? .blue : .green)
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
}

import RealityKit
