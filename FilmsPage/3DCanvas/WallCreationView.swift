//
//  WallCreationView.swift
//  FilmsPage
//
//  SwiftUI view presented as a sheet when the user taps "Add Wall".
//  Matches GroundCreationView design language — split top row,
//  card-based sliders, tight vertical rhythm, content-hugging sheet.
//

import SwiftUI

// MARK: - Layout Constants

private enum Layout {
    static let horizontalPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 12
    static let cardCornerRadius: CGFloat = 14
    static let sliderCardH: CGFloat = 64    // label(18) + slider(28) + vPad(2×9)
    static let dimSliderCardH: CGFloat = 60 // slightly shorter for the 3-up row
}

// MARK: - WallCreationView

struct WallCreationView: View {
    @StateObject var viewModel = WallCreationViewModel()

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.09, green: 0.09, blue: 0.10)
                    .ignoresSafeArea()

                VStack(spacing: Layout.sectionSpacing) {

                    // ── Row 1: Preview  |  Material + Tint ──────────
                    topRow

                    // ── Row 2: Dimensions (3 sliders side-by-side) ──
                    dimensionsRow

                    // ── Row 3: Properties (2 × 3 grid) + Ratio Lock ─
                    propertiesRow

                }
                .padding(.horizontal, Layout.horizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, 16)
            }
            .navigationTitle("New Wall")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
        .preferredColorScheme(.dark)
        .navigationViewStyle(.stack)
        .presentationDetents([.height(contentHeight)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(24)
    }

    // MARK: - Sheet Height

    private var contentHeight: CGFloat {
        let screenW   = UIScreen.main.bounds.width
        let usableW   = screenW - Layout.horizontalPadding * 2
        let previewW  = usableW * 0.42 - 5          // 42% of usable, minus half gap
        let previewH  = previewW * 1.15             // preview aspect ~0.87 width:height
        let dimRowH   = Layout.dimSliderCardH       // single-row, cards are equal height
        let propRowH  = Layout.sliderCardH * 3 + 8 * 2   // 3 rows + 2 gaps (properties col)
        let navBar: CGFloat = 56
        // rows + (3 sectionSpacings between 4 rows) + top + bottom
        return navBar + 10
             + previewH
             + Layout.sectionSpacing
             + dimRowH
             + Layout.sectionSpacing
             + propRowH
             + 16
    }

    // MARK: - Top Row

    private var topRow: some View {
        HStack(alignment: .top, spacing: 10) {

            // ── Left: Live Preview ───────────────────────────────
            previewCard
                .frame(width: UIScreen.main.bounds.width * 0.42)

            // ── Right: Material + Tint ───────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                materialSection
                tintSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Preview Card

    private var previewCard: some View {
        MaterialPreviewCard(
            config: viewModel.materialConfig,
            isWall: true,
            label: "Live Preview"
        )
        .frame(maxWidth: .infinity)
        .aspectRatio(0.87, contentMode: .fit)
        .background(Color(white: 0.13))
        .clipShape(RoundedRectangle(cornerRadius: Layout.cardCornerRadius, style: .continuous))
    }

    // MARK: - Material Section

    private var materialSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Material")

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
        VStack(alignment: .leading, spacing: 6) {
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
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(white: 0.13))
            )
        }
    }

    // MARK: - Dimensions Row (3 cards side-by-side)

    private var dimensionsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Dimensions")

            HStack(spacing: 8) {
                sliderCard(label: "Width", value: $viewModel.width,
                           range: 0.5...6.0, unit: "m", compact: true)
                sliderCard(label: "Height", value: $viewModel.height,
                           range: 0.3...4.0, unit: "m", compact: true)
                sliderCard(label: "Thickness", value: $viewModel.thickness,
                           range: 0.02...0.3, unit: "m", compact: true)
            }
        }
    }

    // MARK: - Properties Row (2-column × 3 rows + inline Ratio Lock)

    private var propertiesRow: some View {
        HStack(alignment: .top, spacing: 8) {

            // ── Left column: 3 sliders ────────────────────────────
            VStack(spacing: 8) {
                sliderCard(label: "Roughness", value: $viewModel.roughness,
                           range: 0...1, unit: "")
                sliderCard(label: "Metallic", value: $viewModel.metallic,
                           range: 0...1, unit: "")
                sliderCard(label: "Opacity", value: $viewModel.opacity,
                           range: 0.05...1, unit: "")
            }
            .frame(maxWidth: .infinity)

            // ── Right column: 2 sliders + Ratio Lock card ─────────
            VStack(spacing: 8) {
                sliderCard(label: "Tiling", value: $viewModel.tilingScale,
                           range: 0.25...4.0, unit: "×")
                sliderCard(label: "Reflection", value: $viewModel.reflectionIntensity,
                           range: 0...1, unit: "")
                ratioLockCard
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Ratio Lock Card

    private var ratioLockCard: some View {
        VStack(alignment: .leading, spacing: viewModel.ratioLocked ? 8 : 0) {

            // Toggle row
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Ratio Lock")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(white: 0.55))
                    Text(viewModel.ratioLocked ? "On" : "Off")
                        .font(.system(size: 12, weight: .semibold).monospacedDigit())
                        .foregroundColor(viewModel.ratioLocked
                            ? Color(red: 0.88, green: 0.28, blue: 0.28)
                            : Color(white: 0.35))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Toggle("", isOn: $viewModel.ratioLocked)
                    .labelsHidden()
                    .tint(Color(red: 0.88, green: 0.28, blue: 0.28))
                    .scaleEffect(0.75, anchor: .trailing)
            }

            // Ratio inputs — only visible when locked
            if viewModel.ratioLocked {
                HStack(spacing: 6) {
                    ratioField("W", text: $viewModel.ratioWidth, placeholder: "16")
                    Text(":")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(white: 0.35))
                    ratioField("H", text: $viewModel.ratioHeight, placeholder: "9")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: Layout.sliderCardH)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(white: 0.13))
        )
    }

    private func ratioField(_ label: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Color(white: 0.35))
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color(white: 0.19))
                )
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Slider Card

    private func sliderCard(
        label: String,
        value: Binding<Float>,
        range: ClosedRange<Float>,
        unit: String,
        compact: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(white: 0.55))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

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
        .padding(.vertical, compact ? 9 : 10)
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
            Button(
                action: { viewModel.cancel() },
                label: {
                    Text("Cancel")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(Color(white: 0.50))
                }
            )
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(
                action: { viewModel.confirm() },
                label: {
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
            )
        }
    }

    // MARK: - Helpers

    private func formattedValue(_ v: Float, unit: String) -> String {
        switch unit {
        case "×": return String(format: "%.2f×", v)
        case "m": return String(format: "%.2fm", v)
        default:  return String(format: "%.2f", v)
        }
    }
}
