//
//  GroundCreationView.swift
//  FilmsPage
//
//  SwiftUI view presented as a sheet when the user taps "Add Ground".
//  Professional creation flow with live preview, environment texture
//  selection, and PBR parameter controls.
//

import SwiftUI

// MARK: - Layout Constants

private enum Layout {
    static let horizontalPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 24
    static let cardCornerRadius: CGFloat = 16
    static let innerPadding: CGFloat = 14
    static let previewAspect: CGFloat = 0.72   // width fraction of the split
}

// MARK: - GroundCreationView

struct GroundCreationView: View {
    @StateObject var viewModel = GroundCreationViewModel()
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(red: 0.09, green: 0.09, blue: 0.10)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Layout.sectionSpacing) {

                        // ── Row 1: Preview + Environment/Tint ───────
                        topRow

                        // ── Row 2: Surface Properties ────────────────
                        surfacePropertiesSection
                    }
                    .padding(.horizontal, Layout.horizontalPadding)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("New Ground")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .preferredColorScheme(.dark)
        .navigationViewStyle(.stack)
    }

    // MARK: - Top Row

    private var topRow: some View {
        HStack(alignment: .top, spacing: 12) {

            // Left: Preview card
            previewCard
                .frame(width: UIScreen.main.bounds.width * 0.40)

            // Right: Environment + Tint stacked
            VStack(alignment: .leading, spacing: 14) {

                if !viewModel.isPlainGround {
                    environmentSection
                }

                tintSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Preview Card

    private var previewCard: some View {
        VStack(spacing: 0) {
            MaterialPreviewCard(
                config: viewModel.materialConfig,
                isWall: false,
                label: "Live Preview"
            )
            .frame(maxWidth: .infinity)
            .aspectRatio(0.9, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous))
        }
        .background(
            RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous)
                .fill(Color(white: 0.13))
        )
        .clipShape(RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous))
    }

    // MARK: - Environment Section

    private var environmentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Environment")

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

    // MARK: - Tint Section

    private var tintSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Tint Color")

            HStack(spacing: 0) {
                Text("Surface Tint")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Color(white: 0.55))
                    .frame(maxWidth: .infinity, alignment: .leading)

                ColorPicker("", selection: $viewModel.tintColor, supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 28, height: 28)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(white: 0.13))
            )
        }
    }

    // MARK: - Surface Properties

    private var surfacePropertiesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Surface Properties")

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    sliderCard(
                        label: "Roughness",
                        value: $viewModel.roughness,
                        range: 0...1,
                        unit: ""
                    )
                    sliderCard(
                        label: "Metallic",
                        value: $viewModel.metallic,
                        range: 0...1,
                        unit: ""
                    )
                }
                HStack(spacing: 10) {
                    sliderCard(
                        label: "Tiling Scale",
                        value: $viewModel.tilingScale,
                        range: 0.25...4.0,
                        unit: "×"
                    )
                    sliderCard(
                        label: "Reflection",
                        value: $viewModel.reflectionIntensity,
                        range: 0...1,
                        unit: ""
                    )
                }
            }
        }
    }

    // MARK: - Slider Card

    private func sliderCard(
        label: String,
        value: Binding<Float>,
        range: ClosedRange<Float>,
        unit: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(white: 0.55))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(formattedValue(value.wrappedValue, unit: unit))
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundColor(Color(white: 0.85))
            }

            LabeledSliderView(
                label: "",
                value: value,
                range: range,
                unit: unit
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(white: 0.13))
        )
    }

    // MARK: - Section Label

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .kerning(1.2)
            .foregroundColor(Color(white: 0.38))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(action: { viewModel.cancel() }) {
                Text("Cancel")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(Color(white: 0.50))
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(action: { viewModel.confirm() }) {
                Text("Create")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(red: 0.88, green: 0.28, blue: 0.28))
                    )
            }
        }
    }

    // MARK: - Helpers

    private func formattedValue(_ v: Float, unit: String) -> String {
        if unit == "×" {
            return String(format: "%.2f×", v)
        }
        return String(format: "%.2f", v)
    }
}
