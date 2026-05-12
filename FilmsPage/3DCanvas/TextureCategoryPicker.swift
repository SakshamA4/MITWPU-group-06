//
//  TextureCategoryPicker.swift
//  FilmsPage
//
//  Segmented control + horizontal scroll grid for browsing
//  texture presets by category. Apple-native design.
//

import SwiftUI

// MARK: - TextureCategoryPicker

struct TextureCategoryPicker: View {
    let categories: [TextureCategory]
    let allPresets: [TexturePreset]
    @Binding var selectedCategory: TextureCategory
    @Binding var selectedPresetID: String
    let tint: Color

    var filteredPresets: [TexturePreset] {
        allPresets.filter { $0.category == selectedCategory }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category segmented control
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories) { category in
                        CategoryChip(
                            category: category,
                            isSelected: selectedCategory == category
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedCategory = category
                            }
                            let generator = UISelectionFeedbackGenerator()
                            generator.selectionChanged()
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            // Texture thumbnails
            TextureThumbnailGrid(
                presets: filteredPresets,
                selectedPresetID: $selectedPresetID,
                tint: tint
            )
        }
    }
}

// MARK: - CategoryChip

private struct CategoryChip: View {
    let category: TextureCategory
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                Text(category.rawValue)
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? ModalStyle.buttonSelectedBackground : ModalStyle.buttonUnselectedBackground)
            )
            .foregroundColor(isSelected ? ModalStyle.buttonSelectedTextColor : ModalStyle.buttonUnselectedTextColor)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.03 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
    }
}
