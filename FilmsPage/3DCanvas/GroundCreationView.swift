//
//  GroundCreationView.swift
//  FilmsPage
//
//  SwiftUI view presented as a sheet when the user taps "Add Ground".
//  Professional creation flow with live preview, environment texture
//  selection, and PBR parameter controls.
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
    static let separatorHeight: CGFloat = 0.5
    static let cornerRadius: CGFloat = 14
}

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
                    VStack(spacing: Layout.interSectionSpacing) {

                        // MARK: - Live Preview
                        previewSection
                            .padding(.top, Layout.previewTopInset)
                            .padding(.bottom, Layout.previewToFirstSectionSpacing - Layout.interSectionSpacing)

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
                }
            }
            .navigationTitle("New Ground")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { viewModel.cancel() }) {
                        Text("Cancel")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(Color(UIColor.label))
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { viewModel.confirm() }) {
                        Text("Create")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: Layout.cornerRadius))
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
            .padding(.horizontal, Layout.horizontalInset)
        }
    }

    // MARK: - Size

    private var sizeSection: some View {
        VStack(alignment: .leading, spacing: Layout.separatorBottomSpacing) {
            sectionHeader("Size", showSeparator: false)

            VStack(spacing: Layout.interSliderSpacing) {
                LabeledSliderView(label: "Ground Size", value: $viewModel.size,
                          range: 1...20, unit: "m")
            }
            .sectionCard()
        }
        .padding(.horizontal, Layout.horizontalInset)
    }

    // MARK: - Texture

    private var textureSection: some View {
        VStack(alignment: .leading, spacing: Layout.separatorBottomSpacing) {
            sectionHeader("Environment", showSeparator: true)

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
            .sectionCard()
        }
        .padding(.horizontal, Layout.horizontalInset)
    }

    // MARK: - Properties

    private var propertiesSection: some View {
        VStack(alignment: .leading, spacing: Layout.separatorBottomSpacing) {
            sectionHeader("Surface Properties", showSeparator: true)

            VStack(spacing: Layout.interSliderSpacing) {
                LabeledSliderView(label: "Roughness", value: $viewModel.roughness,
                          range: 0...1, unit: "")
                LabeledSliderView(label: "Metallic", value: $viewModel.metallic,
                          range: 0...1, unit: "")
                LabeledSliderView(label: "Tiling Scale", value: $viewModel.tilingScale,
                          range: 0.25...4.0, unit: "×")
                LabeledSliderView(label: "Reflection", value: $viewModel.reflectionIntensity,
                          range: 0...1, unit: "")
            }
            .sectionCard()
        }
        .padding(.horizontal, Layout.horizontalInset)
    }

    // MARK: - Tint

    private var tintSection: some View {
        VStack(alignment: .leading, spacing: Layout.separatorBottomSpacing) {
            sectionHeader("Tint Color", showSeparator: true)

            ColorPicker("Surface Tint", selection: $viewModel.tintColor, supportsOpacity: false)
                .padding(.horizontal, 4)
                .sectionCard()
        }
        .padding(.horizontal, Layout.horizontalInset)
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, showSeparator: Bool) -> some View {
        VStack(alignment: .leading, spacing: Layout.separatorBottomSpacing) {
            if showSeparator {
                Rectangle()
                    .fill(Color(UIColor.separator))
                    .frame(height: Layout.separatorHeight)
                    .padding(.top, Layout.separatorTopSpacing)
            }
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
}
