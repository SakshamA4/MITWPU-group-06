//
//  TextureThumbnailView.swift
//  FilmsPage
//
//  Reusable SwiftUI view for a single texture thumbnail.
//  Shows the procedural texture preview with name label,
//  selection ring, and haptic feedback.
//

import SwiftUI

// MARK: - TextureThumbnailView

struct TextureThumbnailView: View {
    let preset: TexturePreset
    let isSelected: Bool
    let tint: Color
    let onTap: () -> Void

    @State private var thumbnailImage: UIImage?

    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            onTap()
        }) {
            VStack(spacing: 6) {
                ZStack {
                    // Texture image
                    if let img = thumbnailImage {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: ModalStyle.tileCornerRadius, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: ModalStyle.tileCornerRadius, style: .continuous)
                            .fill(Color(white: 0.15))
                            .frame(width: 72, height: 72)
                    }

                    // Selection ring
                    if isSelected {
                        RoundedRectangle(cornerRadius: ModalStyle.tileCornerRadius + 2, style: .continuous)
                            .strokeBorder(Color.blue, lineWidth: 2)
                            .frame(width: 76, height: 76)
                    }
                }
                .scaleEffect(isSelected ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)

                Text(preset.name)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .onAppear(perform: loadThumbnail)
    }

    private func loadThumbnail() {
        // Generate thumbnail on background queue to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async {
            let uiColor = UIColor(tint)
            let img = ProceduralTextureGenerator.shared.thumbnail(for: preset.id, tint: uiColor)
            DispatchQueue.main.async {
                self.thumbnailImage = img
            }
        }
    }
}

// MARK: - TextureThumbnailGrid

struct TextureThumbnailGrid: View {
    let presets: [TexturePreset]
    @Binding var selectedPresetID: String
    let tint: Color

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(presets) { preset in
                    TextureThumbnailView(
                        preset: preset,
                        isSelected: selectedPresetID == preset.id,
                        tint: tint
                    ) {
                        selectedPresetID = preset.id
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}
