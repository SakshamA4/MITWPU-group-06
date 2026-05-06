//
//  GroundCreationView.swift
//  FilmsPage
//
//  SwiftUI view presented as a sheet when the user taps "Add Ground".
//  Professional creation flow with live preview, environment texture
//  selection, and PBR parameter controls.
//

import SwiftUI

// MARK: - GroundCreationView

struct GroundCreationView: View {
    @StateObject var viewModel = GroundCreationViewModel()
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {

                        // MARK: - Live Preview
                        previewSection

                        // MARK: - Size
                        sizeSection

                        // MARK: - Texture Selection
                        textureSection

                        // MARK: - Material Properties
                        propertiesSection

                        // MARK: - Tint Color
                        tintSection

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationTitle("New Ground")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.cancel() }
                        .foregroundColor(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { viewModel.confirm() }) {
                        Text("Create")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Preview

    private var previewSection: some View {
        VStack(spacing: 4) {
            MaterialPreviewCard(
                config: viewModel.materialConfig,
                isWall: false,
                label: "Live Preview"
            )
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Size

    private var sizeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Size", icon: "arrow.up.left.and.arrow.down.right")

            VStack(spacing: 14) {
                SliderRow(label: "Ground Size", value: $viewModel.size,
                          range: 1...20, unit: "m")
            }
            .sectionCard()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Texture

    private var textureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Environment", icon: "globe.americas.fill")

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

            // Selected preset badge
            if let preset = TexturePresetLibrary.preset(for: viewModel.selectedPresetID) {
                HStack {
                    Image(systemName: preset.icon)
                        .foregroundColor(.green)
                    Text(preset.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .transition(.opacity)
            }
        }
    }

    // MARK: - Properties

    private var propertiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Surface Properties", icon: "slider.horizontal.3")

            VStack(spacing: 14) {
                SliderRow(label: "Roughness", value: $viewModel.roughness,
                          range: 0...1, unit: "")
                SliderRow(label: "Metallic", value: $viewModel.metallic,
                          range: 0...1, unit: "")
                SliderRow(label: "Tiling Scale", value: $viewModel.tilingScale,
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
                .foregroundColor(.green)
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
}
