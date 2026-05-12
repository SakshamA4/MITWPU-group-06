//
//  WallCreationView.swift
//  FilmsPage
//
//  SwiftUI view presented as a sheet when the user taps "Add Wall".
//  Professional Apple-native creation experience with live preview,
//  texture selection, and PBR parameter controls.
//

import SwiftUI

private enum Layout {
    static let previewTopInset: CGFloat = 20
    static let previewToFirstSectionSpacing: CGFloat = 24
    static let interSectionSpacing: CGFloat = 28
    static let separatorTopSpacing: CGFloat = 24
    static let separatorBottomSpacing: CGFloat = 16
    static let interSliderSpacing: CGFloat = 16
    static let horizontalInset: CGFloat = 16
    static let internalPadding: CGFloat = 14
    static let cornerRadius: CGFloat = 14
    static let separatorHeight: CGFloat = 0.5
}

// MARK: - WallCreationView

struct WallCreationView: View {
    @StateObject var viewModel = WallCreationViewModel()
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                ModalStyle.background
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: Layout.interSectionSpacing) {

                        // MARK: - Live Preview
                        previewSection
                            .padding(.top, Layout.previewTopInset)
                            .padding(.bottom, Layout.previewToFirstSectionSpacing - Layout.interSectionSpacing)

                        // MARK: - Dimensions
                        dimensionsSection

                        // MARK: - Texture Selection
                        textureSection

                        // MARK: - Material Properties
                        propertiesSection

                        // MARK: - Tint Color
                        tintSection

                        // Bottom padding for safe area
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("New Wall")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { viewModel.cancel() }) {
                        Text("Cancel")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundColor(Color(UIColor.secondaryLabel))
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { viewModel.confirm() }) {
                        Text("Create")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .navigationViewStyle(.stack)
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(spacing: 4) {
            MaterialPreviewCard(
                config: viewModel.materialConfig,
                isWall: true,
                label: "Live Preview"
            )
            .padding(.horizontal, Layout.horizontalInset)
        }
    }

    // MARK: - Dimensions Section

    private var dimensionsSection: some View {
        VStack(alignment: .leading, spacing: Layout.separatorBottomSpacing) {
            sectionHeader("Dimensions", showSeparator: false)

            VStack(spacing: ModalStyle.interSliderSpacing) {
                LabeledSliderView(label: "Width", value: $viewModel.width,
                          range: 0.5...6.0, unit: "m")
                LabeledSliderView(label: "Height", value: $viewModel.height,
                          range: 0.3...4.0, unit: "m")
                LabeledSliderView(label: "Thickness", value: $viewModel.thickness,
                          range: 0.02...0.3, unit: "m")
            }
        }
        .padding(.horizontal, Layout.horizontalInset)
    }

    // MARK: - Texture Section

    private var textureSection: some View {
        VStack(alignment: .leading, spacing: Layout.separatorBottomSpacing) {
            sectionHeader("Material", showSeparator: true)

            VStack(spacing: 0) {
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
        .padding(.horizontal, Layout.horizontalInset)
    }

    // MARK: - Properties Section

    private var propertiesSection: some View {
        VStack(alignment: .leading, spacing: Layout.separatorBottomSpacing) {
            sectionHeader("Properties", showSeparator: true)

            VStack(spacing: Layout.interSliderSpacing) {
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
        .padding(.horizontal, Layout.horizontalInset)
    }

    // MARK: - Tint Section

    private var tintSection: some View {
        VStack(alignment: .leading, spacing: Layout.separatorBottomSpacing) {
            sectionHeader("Tint Color", showSeparator: true)

            ColorPicker("Surface Tint", selection: $viewModel.tintColor, supportsOpacity: false)
                .padding(.horizontal, 4)
        }
        .padding(.horizontal, Layout.horizontalInset)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, showSeparator: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(ModalStyle.sectionLabelFont)
                .kerning(ModalStyle.sectionLabelKerning)
                .foregroundColor(ModalStyle.sectionLabelColor)
                .padding(.top, ModalStyle.sectionSpacingTop)
        }
    }
}
