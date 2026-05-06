//
//  WallCreationView.swift
//  FilmsPage
//
//  SwiftUI view presented as a sheet when the user taps "Add Wall".
//  Professional Apple-native creation experience with live preview,
//  texture selection, and PBR parameter controls.
//

import SwiftUI

// MARK: - WallCreationView

struct WallCreationView: View {
    @StateObject var viewModel = WallCreationViewModel()
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {

                        // MARK: - Live Preview
                        previewSection

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
                    .padding(.top, 8)
                }
            }
            .navigationTitle("New Wall")
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

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(spacing: 4) {
            MaterialPreviewCard(
                config: viewModel.materialConfig,
                isWall: true,
                label: "Live Preview"
            )
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Dimensions Section

    private var dimensionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Dimensions", icon: "ruler.fill")

            VStack(spacing: 14) {
                SliderRow(label: "Width", value: $viewModel.width,
                          range: 0.5...6.0, unit: "m")
                SliderRow(label: "Height", value: $viewModel.height,
                          range: 0.3...4.0, unit: "m")
                SliderRow(label: "Thickness", value: $viewModel.thickness,
                          range: 0.02...0.3, unit: "m")
            }
            .sectionCard()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Texture Section

    private var textureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Material", icon: "paintbrush.fill")

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

            // Selected preset name
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
                .transition(.opacity)
            }
        }
    }

    // MARK: - Properties Section

    private var propertiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Properties", icon: "slider.horizontal.3")

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

    // MARK: - Tint Section

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
                .foregroundColor(.blue)
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - SliderRow

struct SliderRow: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let unit: String

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(unit.isEmpty ? String(format: "%.2f", value) : String(format: "%.2f%@", value, unit))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .monospacedDigit()
            }
            Slider(value: $value, in: range)
                .tint(.blue)
        }
    }
}

// MARK: - Section Card Modifier

private struct SectionCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
    }
}

extension View {
    func sectionCard() -> some View {
        modifier(SectionCardModifier())
    }
}
