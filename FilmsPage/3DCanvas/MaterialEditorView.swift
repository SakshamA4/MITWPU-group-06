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
                ModalStyle.background
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
        .preferredColorScheme(.dark)
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
            sectionHeader("Texture")

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
        }
    }

    // MARK: - Properties

    private var propertiesSection: some View {
        VStack(alignment: .leading, spacing: ModalStyle.interSliderSpacing) {
            sectionHeader("Surface")

            VStack(spacing: 14) {
                LabeledSliderView(label: "Roughness", value: $viewModel.roughness,
                          range: 0...1, unit: "")
                LabeledSliderView(label: "Metallic", value: $viewModel.metallic,
                          range: 0...1, unit: "")
                LabeledSliderView(label: "Opacity", value: $viewModel.opacity,
                          range: 0.05...1, unit: "")
                LabeledSliderView(label: "Tiling", value: $viewModel.tilingScale,
                          range: 0.25...4.0, unit: "×")
                LabeledSliderView(label: "Reflection", value: $viewModel.reflectionIntensity,
                          range: 0...1, unit: "")
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Tint

    private var tintSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Tint Color")

            ColorPicker("Surface Tint", selection: $viewModel.tintColor, supportsOpacity: false)
                .padding(.horizontal, 4)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(ModalStyle.sectionLabelFont)
                .kerning(ModalStyle.sectionLabelKerning)
                .foregroundColor(ModalStyle.sectionLabelColor)
                .padding(.top, ModalStyle.sectionSpacingTop)
        }
    }
}

import RealityKit
