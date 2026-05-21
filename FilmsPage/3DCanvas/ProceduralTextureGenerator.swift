//
//  ProceduralTextureGenerator.swift
//  FilmsPage
//
//  Generates procedural texture images via Core Graphics.
//  Thread-safe with NSCache for texture reuse.
//  Each generator produces a CGImage at configurable resolution.
//

import UIKit
import CoreGraphics

// MARK: - ProceduralTextureGenerator

final class ProceduralTextureGenerator {

    static let shared = ProceduralTextureGenerator()

    /// Default resolution for generated textures. 512 balances quality vs memory.
    static let defaultResolution: Int = 512

    /// Cache for generated UIImages keyed by preset ID + tint hash.
    private let imageCache = NSCache<NSString, UIImage>()

    private init() {
        imageCache.countLimit = 30
        imageCache.totalCostLimit = 100 * 1024 * 1024 // 100 MB
    }

    // MARK: - Public API

    /// Returns a UIImage for the given preset, optionally tinted.
    /// Results are cached.
    func texture(
        for presetID: String,
        tint: UIColor = .white,
        resolution: Int = ProceduralTextureGenerator.defaultResolution
    ) -> UIImage {
        let cacheKey = "\(presetID)_\(tint.hexString)_\(resolution)" as NSString
        if let cached = imageCache.object(forKey: cacheKey) {
            return cached
        }
        let image = generateTexture(presetID: presetID, tint: tint, resolution: resolution)
        imageCache.setObject(image, forKey: cacheKey, cost: resolution * resolution * 4)
        return image
    }

    /// Generates a small thumbnail (128×128) for UI display.
    func thumbnail(for presetID: String, tint: UIColor = .white) -> UIImage {
        texture(for: presetID, tint: tint, resolution: 128)
    }

    /// Clears the texture cache (for memory warnings).
    func clearCache() {
        imageCache.removeAllObjects()
    }

    // MARK: - Generator Dispatch

    private func generateTexture(presetID: String, tint: UIColor, resolution: Int) -> UIImage {
        let size = CGSize(width: resolution, height: resolution)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cgCtx = ctx.cgContext
            let rect = CGRect(origin: .zero, size: size)

            switch presetID {
            case "concrete":    drawConcrete(in: cgCtx, rect: rect, tint: tint)
            case "brick":       drawBrick(in: cgCtx, rect: rect, tint: tint)
            case "marble":      drawMarble(in: cgCtx, rect: rect, tint: tint)
            case "metal":       drawMetal(in: cgCtx, rect: rect, tint: tint)
            case "glass":       drawGlass(in: cgCtx, rect: rect, tint: tint)
            case "grass":       drawGrass(in: cgCtx, rect: rect, tint: tint)
            case "sand":        drawSand(in: cgCtx, rect: rect, tint: tint)
            case "dirt":        drawDirt(in: cgCtx, rect: rect, tint: tint)
            case "asphalt":     drawAsphalt(in: cgCtx, rect: rect, tint: tint)
            case "snow":        drawSnow(in: cgCtx, rect: rect, tint: tint)
            case "industrial":  drawIndustrial(in: cgCtx, rect: rect, tint: tint)
            case "studioFloor": drawStudioFloor(in: cgCtx, rect: rect, tint: tint)
            case "neon":        drawNeon(in: cgCtx, rect: rect, tint: tint)
            default:            drawConcrete(in: cgCtx, rect: rect, tint: tint)
            }
        }
    }

    // MARK: - Concrete

    private func drawConcrete(in ctx: CGContext, rect: CGRect, tint: UIColor) {
        let base = UIColor(red: 0.72, green: 0.71, blue: 0.68, alpha: 1.0).blended(with: tint)
        ctx.setFillColor(base.cgColor)
        ctx.fill(rect)

        // Noise speckles
        let rng = SeededRNG(seed: 42)
        for _ in 0..<Int(rect.width * rect.height * 0.08) {
            let x = CGFloat(rng.nextFloat()) * rect.width
            let y = CGFloat(rng.nextFloat()) * rect.height
            let gray = CGFloat(0.6 + rng.nextFloat() * 0.2)
            let size = CGFloat(1 + rng.nextFloat() * 2.5)
            ctx.setFillColor(UIColor(white: gray, alpha: 0.4).cgColor)
            ctx.fillEllipse(in: CGRect(x: x, y: y, width: size, height: size))
        }

        // Subtle cracks
        ctx.setStrokeColor(UIColor(white: 0.5, alpha: 0.15).cgColor)
        ctx.setLineWidth(0.8)
        for _ in 0..<5 {
            let startX = CGFloat(rng.nextFloat()) * rect.width
            let startY = CGFloat(rng.nextFloat()) * rect.height
            ctx.move(to: CGPoint(x: startX, y: startY))
            for _ in 0..<4 {
                let dx = CGFloat(rng.nextFloat() - 0.5) * 60
                let dy = CGFloat(rng.nextFloat() - 0.5) * 60
                ctx.addLine(to: CGPoint(x: startX + dx, y: startY + dy))
            }
            ctx.strokePath()
        }
    }

    // MARK: - Brick

    private func drawBrick(in ctx: CGContext, rect: CGRect, tint: UIColor) {
        let mortarColor = UIColor(red: 0.78, green: 0.76, blue: 0.72, alpha: 1.0)
        ctx.setFillColor(mortarColor.cgColor)
        ctx.fill(rect)

        let brickW: CGFloat = rect.width / 4
        let brickH: CGFloat = rect.height / 8
        let gap: CGFloat = 3
        let rng = SeededRNG(seed: 99)

        let brickBase = UIColor(red: 0.72, green: 0.28, blue: 0.18, alpha: 1.0).blended(with: tint)

        for row in 0..<Int(rect.height / brickH) + 1 {
            let offset: CGFloat = (row % 2 == 0) ? 0 : brickW * 0.5
            for col in -1..<Int(rect.width / brickW) + 1 {
                let x = CGFloat(col) * brickW + offset + gap / 2
                let y = CGFloat(row) * brickH + gap / 2
                let w = brickW - gap
                let h = brickH - gap

                // Slight color variation per brick
                let variation = CGFloat(rng.nextFloat() * 0.12 - 0.06)
                let brickColor = brickBase.adjustedBrightness(by: variation)
                ctx.setFillColor(brickColor.cgColor)

                let brickRect = CGRect(x: x, y: y, width: w, height: h)
                let path = UIBezierPath(roundedRect: brickRect, cornerRadius: 1.5)
                ctx.addPath(path.cgPath)
                ctx.fillPath()
            }
        }
    }

    // MARK: - Marble

    private func drawMarble(in ctx: CGContext, rect: CGRect, tint: UIColor) {
        let base = UIColor(red: 0.95, green: 0.93, blue: 0.90, alpha: 1.0).blended(with: tint)
        ctx.setFillColor(base.cgColor)
        ctx.fill(rect)

        let rng = SeededRNG(seed: 77)
        // Veins
        ctx.setStrokeColor(UIColor(white: 0.65, alpha: 0.35).cgColor)
        ctx.setLineWidth(1.2)
        ctx.setLineCap(.round)
        for _ in 0..<12 {
            var x = CGFloat(rng.nextFloat()) * rect.width
            var y = CGFloat(rng.nextFloat()) * rect.height
            ctx.move(to: CGPoint(x: x, y: y))
            for _ in 0..<20 {
                x += CGFloat(rng.nextFloat() - 0.4) * 30
                y += CGFloat(rng.nextFloat() - 0.3) * 15
                ctx.addLine(to: CGPoint(x: x, y: y))
            }
            ctx.strokePath()
        }

        // Fine secondary veins
        ctx.setStrokeColor(UIColor(white: 0.7, alpha: 0.2).cgColor)
        ctx.setLineWidth(0.5)
        for _ in 0..<20 {
            var x = CGFloat(rng.nextFloat()) * rect.width
            var y = CGFloat(rng.nextFloat()) * rect.height
            ctx.move(to: CGPoint(x: x, y: y))
            for _ in 0..<10 {
                x += CGFloat(rng.nextFloat() - 0.45) * 20
                y += CGFloat(rng.nextFloat() - 0.3) * 12
                ctx.addLine(to: CGPoint(x: x, y: y))
            }
            ctx.strokePath()
        }
    }

    // MARK: - Metal

    private func drawMetal(in ctx: CGContext, rect: CGRect, tint: UIColor) {
        let base = UIColor(red: 0.68, green: 0.70, blue: 0.72, alpha: 1.0).blended(with: tint)
        ctx.setFillColor(base.cgColor)
        ctx.fill(rect)

        // Brushed lines
        let rng = SeededRNG(seed: 55)
        ctx.setLineWidth(0.4)
        for _ in 0..<Int(rect.height * 1.5) {
            let y = CGFloat(rng.nextFloat()) * rect.height
            let alpha = CGFloat(rng.nextFloat() * 0.12 + 0.03)
            ctx.setStrokeColor(UIColor(white: 0.5, alpha: alpha).cgColor)
            ctx.move(to: CGPoint(x: 0, y: y))
            ctx.addLine(to: CGPoint(x: rect.width, y: y))
            ctx.strokePath()
        }
    }

    // MARK: - Glass

    private func drawGlass(in ctx: CGContext, rect: CGRect, tint: UIColor) {
        let base = UIColor(red: 0.85, green: 0.92, blue: 0.98, alpha: 0.25).blended(with: tint)
        ctx.setFillColor(base.cgColor)
        ctx.fill(rect)

        // Frost/reflection highlights
        let rng = SeededRNG(seed: 33)
        for _ in 0..<30 {
            let x = CGFloat(rng.nextFloat()) * rect.width
            let y = CGFloat(rng.nextFloat()) * rect.height
            let w = CGFloat(rng.nextFloat() * 80 + 20)
            let h = CGFloat(rng.nextFloat() * 40 + 10)
            ctx.setFillColor(UIColor.white.withAlphaComponent(CGFloat(rng.nextFloat() * 0.08)).cgColor)
            ctx.fillEllipse(in: CGRect(x: x, y: y, width: w, height: h))
        }
    }

    // MARK: - Grass

    private func drawGrass(in ctx: CGContext, rect: CGRect, tint: UIColor) {
        let base = UIColor(red: 0.30, green: 0.55, blue: 0.22, alpha: 1.0).blended(with: tint)
        ctx.setFillColor(base.cgColor)
        ctx.fill(rect)

        let rng = SeededRNG(seed: 101)
        // Blades
        for _ in 0..<Int(rect.width * rect.height * 0.03) {
            let x = CGFloat(rng.nextFloat()) * rect.width
            let y = CGFloat(rng.nextFloat()) * rect.height
            let h = CGFloat(rng.nextFloat() * 8 + 3)
            let lean = CGFloat(rng.nextFloat() - 0.5) * 4
            let green = CGFloat(0.35 + rng.nextFloat() * 0.3)
            ctx.setStrokeColor(UIColor(red: 0.15, green: green, blue: 0.1, alpha: 0.6).cgColor)
            ctx.setLineWidth(CGFloat(0.5 + rng.nextFloat() * 0.8))
            ctx.move(to: CGPoint(x: x, y: y))
            ctx.addLine(to: CGPoint(x: x + lean, y: y - h))
            ctx.strokePath()
        }
    }

    // MARK: - Sand

    private func drawSand(in ctx: CGContext, rect: CGRect, tint: UIColor) {
        let base = UIColor(red: 0.85, green: 0.78, blue: 0.60, alpha: 1.0).blended(with: tint)
        ctx.setFillColor(base.cgColor)
        ctx.fill(rect)

        let rng = SeededRNG(seed: 88)
        for _ in 0..<Int(rect.width * rect.height * 0.12) {
            let x = CGFloat(rng.nextFloat()) * rect.width
            let y = CGFloat(rng.nextFloat()) * rect.height
            let size = CGFloat(0.5 + rng.nextFloat() * 1.5)
            let brightness = CGFloat(0.7 + rng.nextFloat() * 0.25)
            ctx.setFillColor(UIColor(red: brightness, green: brightness * 0.9, blue: brightness * 0.65, alpha: 0.3).cgColor)
            ctx.fillEllipse(in: CGRect(x: x, y: y, width: size, height: size))
        }
    }

    // MARK: - Dirt

    private func drawDirt(in ctx: CGContext, rect: CGRect, tint: UIColor) {
        let base = UIColor(red: 0.45, green: 0.35, blue: 0.25, alpha: 1.0).blended(with: tint)
        ctx.setFillColor(base.cgColor)
        ctx.fill(rect)

        let rng = SeededRNG(seed: 66)
        // Soil texture
        for _ in 0..<Int(rect.width * rect.height * 0.06) {
            let x = CGFloat(rng.nextFloat()) * rect.width
            let y = CGFloat(rng.nextFloat()) * rect.height
            let size = CGFloat(1 + rng.nextFloat() * 3)
            let brown = CGFloat(0.3 + rng.nextFloat() * 0.25)
            ctx.setFillColor(UIColor(red: brown + 0.05, green: brown, blue: brown * 0.7, alpha: 0.4).cgColor)
            ctx.fillEllipse(in: CGRect(x: x, y: y, width: size, height: size))
        }

        // Small pebbles
        for _ in 0..<15 {
            let x = CGFloat(rng.nextFloat()) * rect.width
            let y = CGFloat(rng.nextFloat()) * rect.height
            let size = CGFloat(3 + rng.nextFloat() * 6)
            ctx.setFillColor(UIColor(white: CGFloat(0.4 + rng.nextFloat() * 0.2), alpha: 0.3).cgColor)
            ctx.fillEllipse(in: CGRect(x: x, y: y, width: size, height: size * 0.7))
        }
    }

    // MARK: - Asphalt

    private func drawAsphalt(in ctx: CGContext, rect: CGRect, tint: UIColor) {
        let base = UIColor(red: 0.25, green: 0.25, blue: 0.27, alpha: 1.0).blended(with: tint)
        ctx.setFillColor(base.cgColor)
        ctx.fill(rect)

        let rng = SeededRNG(seed: 44)
        // Aggregate specks
        for _ in 0..<Int(rect.width * rect.height * 0.1) {
            let x = CGFloat(rng.nextFloat()) * rect.width
            let y = CGFloat(rng.nextFloat()) * rect.height
            let size = CGFloat(0.5 + rng.nextFloat() * 2)
            let gray = CGFloat(0.2 + rng.nextFloat() * 0.15)
            ctx.setFillColor(UIColor(white: gray, alpha: 0.35).cgColor)
            ctx.fillEllipse(in: CGRect(x: x, y: y, width: size, height: size))
        }
    }

    // MARK: - Snow

    private func drawSnow(in ctx: CGContext, rect: CGRect, tint: UIColor) {
        let base = UIColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1.0).blended(with: tint)
        ctx.setFillColor(base.cgColor)
        ctx.fill(rect)

        let rng = SeededRNG(seed: 22)
        // Crystal sparkles
        for _ in 0..<Int(rect.width * rect.height * 0.02) {
            let x = CGFloat(rng.nextFloat()) * rect.width
            let y = CGFloat(rng.nextFloat()) * rect.height
            let size = CGFloat(0.8 + rng.nextFloat() * 2)
            ctx.setFillColor(UIColor.white.withAlphaComponent(CGFloat(0.4 + rng.nextFloat() * 0.5)).cgColor)
            ctx.fillEllipse(in: CGRect(x: x, y: y, width: size, height: size))
        }

        // Subtle shadows in dips
        for _ in 0..<40 {
            let x = CGFloat(rng.nextFloat()) * rect.width
            let y = CGFloat(rng.nextFloat()) * rect.height
            let w = CGFloat(rng.nextFloat() * 30 + 10)
            let h = CGFloat(rng.nextFloat() * 15 + 5)
            ctx.setFillColor(UIColor(red: 0.85, green: 0.88, blue: 0.92, alpha: 0.15).cgColor)
            ctx.fillEllipse(in: CGRect(x: x, y: y, width: w, height: h))
        }
    }

    // MARK: - Industrial

    private func drawIndustrial(in ctx: CGContext, rect: CGRect, tint: UIColor) {
        let base = UIColor(red: 0.40, green: 0.42, blue: 0.44, alpha: 1.0).blended(with: tint)
        ctx.setFillColor(base.cgColor)
        ctx.fill(rect)

        // Diamond plate pattern
        let cellSize: CGFloat = rect.width / 8
        ctx.setStrokeColor(UIColor(white: 0.35, alpha: 0.4).cgColor)
        ctx.setLineWidth(1.0)
        for row in 0..<9 {
            for col in 0..<9 {
                let cx = CGFloat(col) * cellSize + (row % 2 == 0 ? 0 : cellSize * 0.5)
                let cy = CGFloat(row) * cellSize
                let d: CGFloat = cellSize * 0.3
                let path = UIBezierPath()
                path.move(to: CGPoint(x: cx, y: cy - d))
                path.addLine(to: CGPoint(x: cx + d, y: cy))
                path.addLine(to: CGPoint(x: cx, y: cy + d))
                path.addLine(to: CGPoint(x: cx - d, y: cy))
                path.close()
                ctx.addPath(path.cgPath)
                ctx.strokePath()

                ctx.setFillColor(UIColor(white: 0.5, alpha: 0.08).cgColor)
                ctx.addPath(path.cgPath)
                ctx.fillPath()
            }
        }
    }

    // MARK: - Studio Floor

    private func drawStudioFloor(in ctx: CGContext, rect: CGRect, tint: UIColor) {
        let base = UIColor(red: 0.15, green: 0.15, blue: 0.17, alpha: 1.0).blended(with: tint)
        ctx.setFillColor(base.cgColor)
        ctx.fill(rect)

        // Grid lines
        let gridSize: CGFloat = rect.width / 8
        ctx.setStrokeColor(UIColor(white: 0.25, alpha: 0.5).cgColor)
        ctx.setLineWidth(0.8)
        for i in 1..<8 {
            let pos = CGFloat(i) * gridSize
            ctx.move(to: CGPoint(x: pos, y: 0))
            ctx.addLine(to: CGPoint(x: pos, y: rect.height))
            ctx.strokePath()
            ctx.move(to: CGPoint(x: 0, y: pos))
            ctx.addLine(to: CGPoint(x: rect.width, y: pos))
            ctx.strokePath()
        }

        // Subtle sheen gradient
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                UIColor(white: 0.2, alpha: 0.0).cgColor,
                UIColor(white: 0.3, alpha: 0.08).cgColor,
                UIColor(white: 0.2, alpha: 0.0).cgColor
            ] as CFArray,
            locations: [0, 0.5, 1]
        )!
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: rect.width, y: rect.height),
            options: []
        )
    }

    // MARK: - Neon

    private func drawNeon(in ctx: CGContext, rect: CGRect, tint: UIColor) {
        let base = UIColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0)
        ctx.setFillColor(base.cgColor)
        ctx.fill(rect)

        // Neon glow strips
        let neonColor = tint == .white
            ? UIColor(red: 0.2, green: 0.9, blue: 1.0, alpha: 1.0)
            : tint
        let stripHeight: CGFloat = rect.height / 6
        for i in [1, 3, 5] {
            let y = CGFloat(i) * stripHeight - stripHeight * 0.1
            let stripRect = CGRect(x: 0, y: y, width: rect.width, height: stripHeight * 0.2)

            // Glow halo
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: 15, color: neonColor.withAlphaComponent(0.6).cgColor)
            ctx.setFillColor(neonColor.withAlphaComponent(0.8).cgColor)
            ctx.fill(stripRect)
            ctx.restoreGState()

            // Core bright line
            let coreLine = CGRect(x: 0, y: y + stripHeight * 0.07, width: rect.width, height: stripHeight * 0.06)
            ctx.setFillColor(UIColor.white.withAlphaComponent(0.9).cgColor)
            ctx.fill(coreLine)
        }
    }
}

// MARK: - SeededRNG (deterministic noise)

/// Simple deterministic random number generator for repeatable textures.
private class SeededRNG {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    /// Returns a Float in [0, 1).
    func nextFloat() -> Float {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let shifted = UInt32(truncatingIfNeeded: (state >> 33) ^ (state >> 17))
        return Float(shifted) / Float(UInt32.max)
    }
}

// MARK: - UIColor helpers

private extension UIColor {

    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X%02X",
                      Int(r * 255), Int(g * 255), Int(b * 255), Int(a * 255))
    }

    func blended(with tint: UIColor) -> UIColor {
        if tint == .white { return self }
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        tint.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(
            red: r1 * r2,
            green: g1 * g2,
            blue: b1 * b2,
            alpha: a1
        )
    }

    func adjustedBrightness(by amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(
            red: max(0, min(1, r + amount)),
            green: max(0, min(1, g + amount)),
            blue: max(0, min(1, b + amount)),
            alpha: a
        )
    }
}
