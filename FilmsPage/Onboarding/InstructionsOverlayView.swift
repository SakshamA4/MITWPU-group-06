//
//  InstructionsOverlayView.swift
//  FilmsPage
//
//  Premium SwiftUI coach mark overlay. Renders a dimmed background,
//  spotlight cutout, glowing rings, and glassmorphic instruction cards.
//

import SwiftUI

struct CutoutShape: Shape {
    var cutoutRect: CGRect?

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        if let cutout = cutoutRect {
            path.addRoundedRect(in: cutout, cornerSize: CGSize(width: 14, height: 14))
        }
        return path
    }
}

struct InstructionsOverlayView: View {
    let spotlightRect: CGRect?
    let title: String
    let message: String
    let hint: String
    let stepIndex: Int
    let totalSteps: Int
    let isInteractionRequired: Bool

    let onTapToContinue: () -> Void
    let onSkip: () -> Void

    @State private var pulseScale: CGFloat = 1.0
    @State private var animateIn = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // ── 1. Dimmed Background with Cutout ──
                CutoutShape(cutoutRect: spotlightRect)
                    .fill(Color.black.opacity(0.75), style: FillStyle(eoFill: true))
                    .ignoresSafeArea()
                    .contentShape(Rectangle()) // Allows hits on the dimmed area
                    .onTapGesture {
                        if !isInteractionRequired {
                            onTapToContinue()
                        }
                    }

                // ── 2. Pulsing Neon Highlight Ring ──
                if let rect = spotlightRect {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.85), lineWidth: 2.5)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .shadow(color: .white.opacity(0.4), radius: 6)

                    // Outer pulse ring
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                        .frame(width: rect.width, height: rect.height)
                        .scaleEffect(pulseScale)
                        .opacity(2.0 - Double(pulseScale))
                        .position(x: rect.midX, y: rect.midY)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: false)) {
                                pulseScale = 1.25
                            }
                        }
                }

                // ── 3. Callout Card ──
                let cardWidth: CGFloat = 340
                let cardHeight: CGFloat = 165
                let size = geo.size

                let positioning = getCardPosition(
                    containerSize: size,
                    rect: spotlightRect,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight
                )

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        // Title
                        Text(title)
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Spacer()

                        // Step index indicator
                        if totalSteps > 0 {
                            Text("Step \(stepIndex) of \(totalSteps)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }

                    // Coach message text
                    Text(message)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 4)

                    // Bottom instruction row
                    HStack {
                        // Hint text
                        HStack(spacing: 4) {
                            if isInteractionRequired {
                                Image(systemName: "hand.tap.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.yellow)
                            }
                            Text(hint)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(isInteractionRequired ? .yellow : .white.opacity(0.55))
                        }

                        Spacer()

                        // Skip button
                        Button(action: onSkip) {
                            Text("Skip")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 18)
                .frame(width: cardWidth, height: cardHeight)
                // Glassmorphic styling
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color(red: 0.08, green: 0.08, blue: 0.10).opacity(0.92))
                        .shadow(color: .black.opacity(0.5), radius: 15, x: 0, y: 10)
                )
                // Left red accent bar for spotlight card
                .overlay(
                    HStack {
                        if spotlightRect != nil {
                            Rectangle()
                                .fill(Color(red: 0.75, green: 0.1, blue: 0.15))
                                .frame(width: 4)
                                .cornerRadius(4)
                                .padding(.vertical, 14)
                                .padding(.leading, 1)
                        }
                        Spacer()
                    }
                )
                .position(x: positioning.x, y: positioning.y)
                .opacity(animateIn ? 1.0 : 0.0)
                .scaleEffect(animateIn ? 1.0 : 0.95)
                .onAppear {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                        animateIn = true
                    }
                }
                .onTapGesture {
                    if !isInteractionRequired {
                        onTapToContinue()
                    }
                }
            }
        }
    }

    private func getCardPosition(
        containerSize: CGSize,
        rect: CGRect?,
        cardWidth: CGFloat,
        cardHeight: CGFloat
    ) -> CGPoint {
        // If there's no spotlight view, center the card on screen
        guard let rect = rect else {
            return CGPoint(
                x: containerSize.width / 2,
                y: containerSize.height / 2
            )
        }

        // Horizontal positioning: align with target center, clamped to screen margins
        let minX = cardWidth / 2 + 16
        let maxX = containerSize.width - cardWidth / 2 - 16
        let x = max(minX, min(maxX, rect.midX))

        // Vertical positioning: place below if there is space, otherwise place above
        let spaceBelow = containerSize.height - rect.maxY
        let y: CGFloat
        if spaceBelow >= cardHeight + 40 {
            // Space below is available
            y = rect.maxY + cardHeight / 2 + 16
        } else {
            // Place above the spotlight
            y = rect.minY - cardHeight / 2 - 16
        }

        return CGPoint(x: x, y: y)
    }
}
