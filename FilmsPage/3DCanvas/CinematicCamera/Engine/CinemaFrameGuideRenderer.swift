//
//  CinemaFrameGuideRenderer.swift
//  FilmsPage
//
//  Draws professional frame guide overlays (thirds, golden ratio,
//  safe areas, crosshair, etc.) using Core Graphics within
//  the letterbox-safe viewport rect.
//

import UIKit

// MARK: - CinemaFrameGuideRenderer

final class CinemaFrameGuideRenderer {
    
    /// Draws all active frame guides into the given rect using Core Graphics.
    static func drawGuides(
        config: FrameGuideConfig,
        in rect: CGRect,
        context: CGContext
    ) {
        guard config.hasActiveGuides else { return }
        
        let color = config.guideColor
        let lineWidth = CGFloat(config.lineWidth)
        
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(lineWidth)
        
        for guide in config.activeGuides {
            switch guide {
            case .thirds:       drawThirds(in: rect, context: context, config: config)
            case .centerCross:  drawCenterCross(in: rect, context: context, config: config)
            case .diagonal:     drawDiagonals(in: rect, context: context, config: config)
            case .goldenRatio:  drawGoldenRatio(in: rect, context: context, config: config)
            case .goldenSpiral: drawGoldenSpiral(in: rect, context: context, config: config)
            case .actionSafe:   drawSafeArea(percent: 0.93, in: rect, context: context, config: config)
            case .titleSafe:    drawSafeArea(percent: 0.90, in: rect, context: context, config: config)
            case .crosshair:    drawCrosshair(in: rect, context: context, config: config)
            case .horizon:      drawHorizon(in: rect, context: context, config: config)
            case .fibonacci:    drawFibonacci(in: rect, context: context, config: config)
            }
        }
    }
    
    // MARK: - Guide Drawings
    
    private static func drawThirds(in rect: CGRect, context: CGContext, config: FrameGuideConfig) {
        let opacity = CGFloat(FrameGuideType.thirds.defaultOpacity * config.globalOpacity)
        context.setAlpha(opacity)
        
        for i in 1...2 {
            let x = rect.minX + rect.width * CGFloat(i) / 3.0
            context.move(to: CGPoint(x: x, y: rect.minY))
            context.addLine(to: CGPoint(x: x, y: rect.maxY))
            
            let y = rect.minY + rect.height * CGFloat(i) / 3.0
            context.move(to: CGPoint(x: rect.minX, y: y))
            context.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        context.strokePath()
    }
    
    private static func drawCenterCross(in rect: CGRect, context: CGContext, config: FrameGuideConfig) {
        let opacity = CGFloat(FrameGuideType.centerCross.defaultOpacity * config.globalOpacity)
        context.setAlpha(opacity)
        
        let cx = rect.midX, cy = rect.midY
        context.move(to: CGPoint(x: cx, y: rect.minY))
        context.addLine(to: CGPoint(x: cx, y: rect.maxY))
        context.move(to: CGPoint(x: rect.minX, y: cy))
        context.addLine(to: CGPoint(x: rect.maxX, y: cy))
        context.strokePath()
    }
    
    private static func drawDiagonals(in rect: CGRect, context: CGContext, config: FrameGuideConfig) {
        let opacity = CGFloat(FrameGuideType.diagonal.defaultOpacity * config.globalOpacity)
        context.setAlpha(opacity)
        
        context.move(to: CGPoint(x: rect.minX, y: rect.minY))
        context.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        context.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        context.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        context.strokePath()
    }
    
    private static func drawGoldenRatio(in rect: CGRect, context: CGContext, config: FrameGuideConfig) {
        let opacity = CGFloat(FrameGuideType.goldenRatio.defaultOpacity * config.globalOpacity)
        context.setAlpha(opacity)
        
        let phi: CGFloat = CGFloat(kGoldenRatio)
        let xLeft = rect.minX + rect.width / phi
        let xRight = rect.maxX - rect.width / phi
        let yTop = rect.minY + rect.height / phi
        let yBottom = rect.maxY - rect.height / phi
        
        context.move(to: CGPoint(x: xLeft, y: rect.minY))
        context.addLine(to: CGPoint(x: xLeft, y: rect.maxY))
        context.move(to: CGPoint(x: xRight, y: rect.minY))
        context.addLine(to: CGPoint(x: xRight, y: rect.maxY))
        context.move(to: CGPoint(x: rect.minX, y: yTop))
        context.addLine(to: CGPoint(x: rect.maxX, y: yTop))
        context.move(to: CGPoint(x: rect.minX, y: yBottom))
        context.addLine(to: CGPoint(x: rect.maxX, y: yBottom))
        context.strokePath()
    }
    
    private static func drawGoldenSpiral(in rect: CGRect, context: CGContext, config: FrameGuideConfig) {
        let opacity = CGFloat(FrameGuideType.goldenSpiral.defaultOpacity * config.globalOpacity)
        context.setAlpha(opacity)
        
        // Simplified Fibonacci spiral using quarter-circle arcs
        let phi: CGFloat = CGFloat(kGoldenRatio)
        var w = rect.width, h = rect.height
        var x = rect.minX, y = rect.minY
        
        for i in 0..<6 {
            let radius: CGFloat
            let center: CGPoint
            let startAngle: CGFloat
            
            switch i % 4 {
            case 0:
                radius = h
                center = CGPoint(x: x + w, y: y + h)
                startAngle = .pi
            case 1:
                radius = w
                center = CGPoint(x: x, y: y + h)
                startAngle = .pi * 1.5
            case 2:
                radius = h
                center = CGPoint(x: x, y: y)
                startAngle = 0
            default:
                radius = w
                center = CGPoint(x: x + w, y: y)
                startAngle = .pi * 0.5
            }
            
            context.addArc(center: center, radius: radius,
                          startAngle: startAngle, endAngle: startAngle + .pi / 2,
                          clockwise: false)
            
            // Subdivide by golden ratio
            let newW = w / phi, newH = h / phi
            switch i % 4 {
            case 0: x += w - newW; y += h - newH
            case 1: y += h - newH
            case 2: break
            default: x += w - newW
            }
            w = newW; h = newH
        }
        context.strokePath()
    }
    
    private static func drawSafeArea(percent: Float, in rect: CGRect, context: CGContext, config: FrameGuideConfig) {
        let opacity = CGFloat(FrameGuideType.actionSafe.defaultOpacity * config.globalOpacity)
        context.setAlpha(opacity)
        
        let inset = CGFloat((1.0 - percent) / 2.0)
        let safeRect = rect.insetBy(dx: rect.width * inset, dy: rect.height * inset)
        
        context.setLineDash(phase: 0, lengths: [4, 4])
        context.stroke(safeRect)
        context.setLineDash(phase: 0, lengths: [])
    }
    
    private static func drawCrosshair(in rect: CGRect, context: CGContext, config: FrameGuideConfig) {
        let opacity = CGFloat(FrameGuideType.crosshair.defaultOpacity * config.globalOpacity)
        context.setAlpha(opacity)
        
        let cx = rect.midX, cy = rect.midY
        let size: CGFloat = 20
        let gap: CGFloat = 4
        
        // Horizontal
        context.move(to: CGPoint(x: cx - size, y: cy))
        context.addLine(to: CGPoint(x: cx - gap, y: cy))
        context.move(to: CGPoint(x: cx + gap, y: cy))
        context.addLine(to: CGPoint(x: cx + size, y: cy))
        
        // Vertical
        context.move(to: CGPoint(x: cx, y: cy - size))
        context.addLine(to: CGPoint(x: cx, y: cy - gap))
        context.move(to: CGPoint(x: cx, y: cy + gap))
        context.addLine(to: CGPoint(x: cx, y: cy + size))
        
        context.strokePath()
        
        // Center dot
        context.fillEllipse(in: CGRect(x: cx - 1.5, y: cy - 1.5, width: 3, height: 3))
    }
    
    private static func drawHorizon(in rect: CGRect, context: CGContext, config: FrameGuideConfig) {
        let opacity = CGFloat(FrameGuideType.horizon.defaultOpacity * config.globalOpacity)
        context.setAlpha(opacity)
        
        let cy = rect.midY
        context.move(to: CGPoint(x: rect.minX, y: cy))
        context.addLine(to: CGPoint(x: rect.maxX, y: cy))
        context.strokePath()
    }
    
    private static func drawFibonacci(in rect: CGRect, context: CGContext, config: FrameGuideConfig) {
        let opacity = CGFloat(FrameGuideType.fibonacci.defaultOpacity * config.globalOpacity)
        context.setAlpha(opacity)
        
        // Fibonacci grid positions: 1, 1, 2, 3, 5, 8 → ratios at 3/8, 5/8
        let x1 = rect.minX + rect.width * (3.0 / 8.0)
        let x2 = rect.minX + rect.width * (5.0 / 8.0)
        let y1 = rect.minY + rect.height * (3.0 / 8.0)
        let y2 = rect.minY + rect.height * (5.0 / 8.0)
        
        context.move(to: CGPoint(x: x1, y: rect.minY))
        context.addLine(to: CGPoint(x: x1, y: rect.maxY))
        context.move(to: CGPoint(x: x2, y: rect.minY))
        context.addLine(to: CGPoint(x: x2, y: rect.maxY))
        context.move(to: CGPoint(x: rect.minX, y: y1))
        context.addLine(to: CGPoint(x: rect.maxX, y: y1))
        context.move(to: CGPoint(x: rect.minX, y: y2))
        context.addLine(to: CGPoint(x: rect.maxX, y: y2))
        context.strokePath()
    }
}
