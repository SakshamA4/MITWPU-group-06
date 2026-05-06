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
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(white: 0.2))
                            .frame(width: 72, height: 72)
                            .overlay(
                                Image(systemName: preset.icon)
                                    .font(.title2)
                                    .foregroundColor(.gray)
                            )
                    }

                    // Selection ring
                    if isSelected {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2.5
                            )
                            .frame(width: 78, height: 78)
                    }
                }
                .shadow(color: isSelected ? .blue.opacity(0.3) : .clear, radius: 6, y: 2)
                .scaleEffect(isSelected ? 1.05 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)

                Text(preset.name)
                    .font(.caption2)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .blue : .secondary)
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
