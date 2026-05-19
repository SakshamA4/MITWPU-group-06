import Foundation
import UIKit

// MARK: - Light Kind

/// The kind of RealityKit light this fixture uses.
enum LightKind: String, Codable, CaseIterable {
    case spot    // SpotLight — directional cone (Spotlight model)
    case panel   // SpotLight with wide cone simulating soft wash (LED Panel model)
    case point   // PointLight — omnidirectional (Lantern model)
}

// MARK: - Procedural Light Kind

/// Identifies lights built from RealityKit primitive geometry (no .usdz file).
enum ProceduralLightKind: String, Codable, CaseIterable {
    case practicalLantern
    case fluorescentTube
    case skyPanel
}

// MARK: - Gobo Pattern

/// Shadow-casting pattern projected by a spotlight via a cookie mesh.
enum GoboPattern: String, Codable, CaseIterable {
    case none
    case venetianBlinds
    case windowFrame
    case leaves
    case dots
    case crosshatch
    case starBurst
    case circles
    case diamondGrid
    case barndoor
    case branchShadow

    var textureName: String? {
        switch self {
        case .none:            return nil
        case .venetianBlinds:  return "gobo_blinds"
        case .windowFrame:     return "gobo_window"
        case .leaves:          return "gobo_leaves"
        case .dots:            return "gobo_dots"
        case .crosshatch:      return "gobo_crosshatch"
        case .starBurst:       return "gobo_starburst"
        case .circles:         return "gobo_circles"
        case .diamondGrid:     return "gobo_diamond"
        case .barndoor:        return "gobo_barndoor"
        case .branchShadow:    return "gobo_branch"
        }
    }

    var displayName: String {
        switch self {
        case .none:            return "None"
        case .venetianBlinds:  return "Blinds"
        case .windowFrame:     return "Window"
        case .leaves:          return "Leaves"
        case .dots:            return "Dots"
        case .crosshatch:      return "Cross"
        case .starBurst:       return "Star"
        case .circles:         return "Rings"
        case .diamondGrid:     return "Diamond"
        case .barndoor:        return "Barn"
        case .branchShadow:    return "Branch"
        }
    }

    // MARK: - Procedural Gobo Texture Generation

    /// Generates a gobo **shadow mask** texture as a CGImage.
    ///
    /// **Polarity for gate-mask approach:**
    /// - **Opaque black** (alpha = 1.0) → blocks light, casts shadow on surfaces
    /// - **Fully transparent** (alpha = 0.0) → light passes through
    ///
    /// Used with `PhysicallyBasedMaterial` + `opacityThreshold` so RealityKit's
    /// shadow system casts the gobo pattern onto scene surfaces. The gate plane
    /// is invisible from the side; you only see the shaped shadows/light on floors and walls.
    ///
    /// Returns nil for `.none`.
    func generateTexture(lightColor: UIColor = .white, resolution: Int = 512) -> CGImage? {
        guard self != .none else { return nil }
        let size = CGSize(width: resolution, height: resolution)
        let renderer = UIGraphicsImageRenderer(size: size)
        let blocked = UIColor.black.withAlphaComponent(1.0)  // casts shadow
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            let rect = CGRect(origin: .zero, size: size)

            // Start fully transparent (= light passes through everywhere)
            cg.clear(rect)

            switch self {
            case .none:
                break

            case .venetianBlinds:
                // Horizontal slats BLOCK light (drawn as opaque black).
                // Gaps between slats let light through (left transparent).
                let slatCount = 8
                let totalSlotH = rect.height / CGFloat(slatCount)
                let slatFraction: CGFloat = 0.55  // 55% of each slot is solid slat
                cg.setFillColor(blocked.cgColor)
                for i in 0..<slatCount {
                    let slotY = CGFloat(i) * totalSlotH
                    let slatH = totalSlotH * slatFraction
                    cg.fill(CGRect(x: 0, y: slotY, width: rect.width, height: slatH))
                }

            case .windowFrame:
                // Window FRAME bars block light (opaque black).
                // Glass panes let light through (transparent).
                let barW: CGFloat = rect.width * 0.08
                cg.setFillColor(blocked.cgColor)
                // Outer frame
                cg.fill(CGRect(x: 0, y: 0, width: rect.width, height: barW))
                cg.fill(CGRect(x: 0, y: rect.height - barW, width: rect.width, height: barW))
                cg.fill(CGRect(x: 0, y: 0, width: barW, height: rect.height))
                cg.fill(CGRect(x: rect.width - barW, y: 0, width: barW, height: rect.height))
                // Center vertical bar
                cg.fill(CGRect(x: rect.width / 2 - barW / 2, y: 0,
                               width: barW, height: rect.height))
                // Horizontal bars (3 rows → 6 panes)
                cg.fill(CGRect(x: 0, y: rect.height * 0.333 - barW / 2,
                               width: rect.width, height: barW))
                cg.fill(CGRect(x: 0, y: rect.height * 0.667 - barW / 2,
                               width: rect.width, height: barW))

            case .leaves:
                // Leaf shapes BLOCK light (opaque). Gaps let light through.
                srand48(42)  // deterministic
                cg.setFillColor(blocked.cgColor)
                for _ in 0..<55 {
                    let x = CGFloat(drand48()) * rect.width
                    let y = CGFloat(drand48()) * rect.height
                    let w = CGFloat(25 + drand48() * 55)
                    let h = CGFloat(12 + drand48() * 30)
                    let angle = CGFloat(drand48() * .pi)
                    cg.saveGState()
                    cg.translateBy(x: x, y: y)
                    cg.rotate(by: angle)
                    // Leaf shape — pointed ellipse via Bézier curves
                    let leafPath = UIBezierPath()
                    leafPath.move(to: CGPoint(x: -w/2, y: 0))
                    leafPath.addCurve(to: CGPoint(x: w/2, y: 0),
                                      controlPoint1: CGPoint(x: -w/4, y: -h),
                                      controlPoint2: CGPoint(x: w/4, y: -h))
                    leafPath.addCurve(to: CGPoint(x: -w/2, y: 0),
                                      controlPoint1: CGPoint(x: w/4, y: h),
                                      controlPoint2: CGPoint(x: -w/4, y: h))
                    cg.addPath(leafPath.cgPath)
                    cg.fillPath()
                    cg.restoreGState()
                }

            case .dots:
                // Solid field blocks light; circular HOLES let light through.
                // Fill everything opaque, then punch transparent holes.
                cg.setFillColor(blocked.cgColor)
                cg.fill(rect)
                let cols = 6, rows = 6
                let cellW = rect.width / CGFloat(cols)
                let cellH = rect.height / CGFloat(rows)
                let holeRadius = min(cellW, cellH) * 0.32
                // Punch holes by clearing circles
                cg.setBlendMode(.clear)
                for row in 0..<rows {
                    for col in 0..<cols {
                        let cx = CGFloat(col) * cellW + cellW / 2
                        let cy = CGFloat(row) * cellH + cellH / 2
                        cg.fillEllipse(in: CGRect(
                            x: cx - holeRadius, y: cy - holeRadius,
                            width: holeRadius * 2, height: holeRadius * 2))
                    }
                }
                cg.setBlendMode(.normal)

            case .crosshatch:
                // Diagonal grid — two sets of parallel lines at 45° block light.
                let lineWidth: CGFloat = rect.width * 0.04
                let spacing: CGFloat = rect.width / 8.0
                cg.setStrokeColor(blocked.cgColor)
                cg.setLineWidth(lineWidth)
                // 45° lines (top-left to bottom-right)
                for i in stride(from: -rect.width, through: rect.width * 2, by: spacing) {
                    cg.move(to: CGPoint(x: i, y: 0))
                    cg.addLine(to: CGPoint(x: i + rect.height, y: rect.height))
                }
                cg.strokePath()
                // 135° lines (top-right to bottom-left)
                for i in stride(from: -rect.width, through: rect.width * 2, by: spacing) {
                    cg.move(to: CGPoint(x: i, y: 0))
                    cg.addLine(to: CGPoint(x: i - rect.height, y: rect.height))
                }
                cg.strokePath()

            case .starBurst:
                // Radial spokes from center — alternating opaque/transparent wedges.
                let spokeCount = 12
                let cx = rect.width / 2, cy = rect.height / 2
                let radius = sqrt(cx * cx + cy * cy)
                cg.setFillColor(blocked.cgColor)
                let wedgeAngle = (.pi * 2) / CGFloat(spokeCount)
                for i in 0..<spokeCount where i % 2 == 0 {
                    let startAngle = CGFloat(i) * wedgeAngle
                    let endAngle = startAngle + wedgeAngle
                    cg.move(to: CGPoint(x: cx, y: cy))
                    cg.addArc(center: CGPoint(x: cx, y: cy), radius: radius,
                              startAngle: startAngle, endAngle: endAngle, clockwise: false)
                    cg.closePath()
                    cg.fillPath()
                }

            case .circles:
                // Concentric rings — alternating opaque rings and transparent gaps.
                let cx = rect.width / 2, cy = rect.height / 2
                let ringCount = 6
                let maxRadius = sqrt(cx * cx + cy * cy)
                let ringWidth = maxRadius / CGFloat(ringCount * 2)
                cg.setFillColor(blocked.cgColor)
                for i in 0..<ringCount {
                    let outerR = maxRadius - CGFloat(i * 2) * ringWidth
                    let innerR = outerR - ringWidth
                    if outerR <= 0 { continue }
                    let path = UIBezierPath(arcCenter: CGPoint(x: cx, y: cy),
                                            radius: outerR, startAngle: 0,
                                            endAngle: .pi * 2, clockwise: true)
                    if innerR > 0 {
                        path.addArc(withCenter: CGPoint(x: cx, y: cy),
                                    radius: innerR, startAngle: 0,
                                    endAngle: .pi * 2, clockwise: false)
                    }
                    cg.addPath(path.cgPath)
                    cg.fillPath()
                }

            case .diamondGrid:
                // Rotated square grid — creates diamond-shaped holes.
                cg.setFillColor(blocked.cgColor)
                cg.fill(rect)
                let cols = 5, rows = 5
                let cellW = rect.width / CGFloat(cols)
                let cellH = rect.height / CGFloat(rows)
                let diamondInset: CGFloat = 0.18
                cg.setBlendMode(.clear)
                for row in 0..<rows {
                    for col in 0..<cols {
                        let cx = CGFloat(col) * cellW + cellW / 2
                        let cy = CGFloat(row) * cellH + cellH / 2
                        let hw = cellW * (0.5 - diamondInset)
                        let hh = cellH * (0.5 - diamondInset)
                        let diamond = UIBezierPath()
                        diamond.move(to: CGPoint(x: cx, y: cy - hh))
                        diamond.addLine(to: CGPoint(x: cx + hw, y: cy))
                        diamond.addLine(to: CGPoint(x: cx, y: cy + hh))
                        diamond.addLine(to: CGPoint(x: cx - hw, y: cy))
                        diamond.close()
                        cg.addPath(diamond.cgPath)
                        cg.fillPath()
                    }
                }
                cg.setBlendMode(.normal)

            case .barndoor:
                // Barn doors — top and bottom flags partially close off the beam.
                // Also adds thin vertical side flags.
                let flagH = rect.height * 0.3   // 30% blocked from top and bottom
                let sideW = rect.width * 0.12
                cg.setFillColor(blocked.cgColor)
                cg.fill(CGRect(x: 0, y: 0, width: rect.width, height: flagH))
                cg.fill(CGRect(x: 0, y: rect.height - flagH, width: rect.width, height: flagH))
                cg.fill(CGRect(x: 0, y: 0, width: sideW, height: rect.height))
                cg.fill(CGRect(x: rect.width - sideW, y: 0, width: sideW, height: rect.height))

            case .branchShadow:
                // Organic tree branch silhouettes.
                srand48(99)
                cg.setStrokeColor(blocked.cgColor)
                for _ in 0..<8 {
                    let startX = CGFloat(drand48()) * rect.width
                    let startY = CGFloat(drand48()) * rect.height * 0.3
                    cg.setLineWidth(CGFloat(3 + drand48() * 6))
                    cg.move(to: CGPoint(x: startX, y: startY))
                    // Main branch
                    var curX = startX, curY = startY
                    let segments = 6 + Int(drand48() * 6)
                    for _ in 0..<segments {
                        curX += CGFloat(-20 + drand48() * 40)
                        curY += CGFloat(15 + drand48() * 35)
                        cg.addLine(to: CGPoint(x: curX, y: curY))
                    }
                    cg.strokePath()
                    // Sub-branches
                    curX = startX; curY = startY
                    for j in 0..<segments {
                        curX += CGFloat(-20 + drand48() * 40)
                        curY += CGFloat(15 + drand48() * 35)
                        if j % 2 == 0 {
                            cg.setLineWidth(CGFloat(1.5 + drand48() * 3))
                            cg.move(to: CGPoint(x: curX, y: curY))
                            let bx = curX + CGFloat(-30 + drand48() * 60)
                            let by = curY + CGFloat(10 + drand48() * 40)
                            cg.addLine(to: CGPoint(x: bx, y: by))
                            cg.strokePath()
                        }
                    }
                }
            }
        }
        return image.cgImage
    }
}

// MARK: - Reflector Type

/// Named presets that set inner/outer angle pairs to simulate real-world reflectors.
enum ReflectorType: String, Codable, CaseIterable {
    case standard     // default focused spot
    case parabolic    // very tight, theatrical
    case openFace     // wide flood, no reflector feel
    case fresnel      // soft edge, classic film look

    var innerAngle: Float {
        switch self {
        case .standard:  return 10
        case .parabolic: return 5
        case .openFace:  return 45
        case .fresnel:   return 20
        }
    }
    var outerAngle: Float {
        switch self {
        case .standard:  return 30
        case .parabolic: return 15
        case .openFace:  return 80
        case .fresnel:   return 45
        }
    }

    var displayName: String {
        switch self {
        case .standard:  return "Standard"
        case .parabolic: return "Parabolic"
        case .openFace:  return "Open Face"
        case .fresnel:   return "Fresnel"
        }
    }
}

// MARK: - Light Config

/// All mutable light properties in one value type.
/// This is the config that travels from data → spawn → UI → persistence.
struct LightConfig {
    var intensity: Float                 // lumens — RealityKit's actual unit
    var colorTemperatureKelvin: Float    // 2700 = tungsten, 5600 = daylight, 7000 = cool
    var innerAngleDeg: Float             // SpotLight only — ignored for point
    var outerAngleDeg: Float             // SpotLight only — ignored for point
    var attenuationRadius: Float         // metres — how far light reaches before zero
    var shadowEnabled: Bool              // SpotLight only — PointLight cannot cast shadows in RealityKit
    var modelScale: Float                // the scale this model is spawned at (e.g. 0.01)
                                         // used to derive child counter-scale = 1.0 / modelScale
    var reflectorType: ReflectorType = .standard
    var activeGobo: GoboPattern = .none
    var diffuserAmount: Float = 0.0      // 0.0 = hard edge, 1.0 = full silk diffusion
}

// MARK: - Light Item

struct LightItem {
    let name: String
    let imageName: String
    let description: String
    var modelFileName: String?
    var lightKind: LightKind = .spot
    var isProcedural: Bool = false
    var proceduralKind: ProceduralLightKind?
    var defaultConfig: LightConfig = LightConfig(
        intensity: 200_000,
        colorTemperatureKelvin: 5600,
        innerAngleDeg: 10,
        outerAngleDeg: 30,
        attenuationRadius: 10,
        shadowEnabled: false,
        modelScale: 0.01
    )
}

// MARK: - Light Data Store

struct LightsDataStore {

    private(set) static var items: [LightItem] = [
        LightItem(
            name: "LED Panel",
            imageName: "LED Panel_img",
            description: "Soft, even light source ideal for key or fill.",
            modelFileName: "LED Panel",
            lightKind: .panel,
            defaultConfig: LightConfig(
                intensity: 400_000,
                colorTemperatureKelvin: 5600,
                innerAngleDeg: 50,
                outerAngleDeg: 100,
                attenuationRadius: 6,
                shadowEnabled: false,
                modelScale: 0.01
            )
        ),
        LightItem(
            name: "Lantern",
            imageName: "Lantern_img",
            description: "Soft omnidirectional light often used as a hanging practical.",
            modelFileName: "Lantern 2",
            lightKind: .point,
            defaultConfig: LightConfig(
                intensity: 500_000,
                colorTemperatureKelvin: 2700,
                innerAngleDeg: 0,
                outerAngleDeg: 0,
                attenuationRadius: 6,
                shadowEnabled: false,
                modelScale: 0.0025
            )
        ),
        LightItem(
            name: "Spotlight",
            imageName: "Spotlight_img 1",
            description: "Narrow beam for highlighting specific areas or subjects.",
            modelFileName: "Spotlight",
            lightKind: .spot,
            defaultConfig: LightConfig(
                intensity: 300_000,
                colorTemperatureKelvin: 5600,
                innerAngleDeg: 15,
                outerAngleDeg: 35,
                attenuationRadius: 4,
                shadowEnabled: false,
                modelScale: 0.01
            )
        ),

        // ── Procedural lights (no .usdz — geometry built from RealityKit primitives) ──

        LightItem(
            name: "Practical Lantern",
            imageName: "practical lantern",
            description: "Round paper lantern practical — soft omnidirectional warm glow.",
            modelFileName: nil,
            lightKind: .point,
            isProcedural: true,
            proceduralKind: .practicalLantern,
            defaultConfig: LightConfig(
                intensity: 150_000,
                colorTemperatureKelvin: 2700,
                innerAngleDeg: 0,
                outerAngleDeg: 0,
                attenuationRadius: 4,
                shadowEnabled: false,
                modelScale: 1.0
            )
        ),
        LightItem(
            name: "Fluorescent Tube",
            imageName: "Fluorescent tube",
            description: "Long horizontal strip light — soft cool linear wash.",
            modelFileName: nil,
            lightKind: .panel,
            isProcedural: true,
            proceduralKind: .fluorescentTube,
            defaultConfig: LightConfig(
                intensity: 200_000,
                colorTemperatureKelvin: 6500,
                innerAngleDeg: 60,
                outerAngleDeg: 110,
                attenuationRadius: 5,
                shadowEnabled: false,
                modelScale: 1.0
            )
        ),
        LightItem(
            name: "Sky Panel",
            imageName: "sky panel",
            description: "Large flat rectangular soft panel — powerful wide soft wash.",
            modelFileName: nil,
            lightKind: .panel,
            isProcedural: true,
            proceduralKind: .skyPanel,
            defaultConfig: LightConfig(
                intensity: 500_000,
                colorTemperatureKelvin: 5600,
                innerAngleDeg: 50,
                outerAngleDeg: 100,
                attenuationRadius: 8,
                shadowEnabled: false,
                modelScale: 1.0
            )
        )
    ]

    // Optional: add new lights later
    static func addLight(name: String, imageName: String, description: String) {
        let newLight = LightItem(name: name, imageName: imageName, description: description)
        items.append(newLight)
    }

    /// Look up a light item by its model file name (e.g. "Spotlight", "LED Panel", "Lantern 2").
    /// Used by the router and persistence fallback path.
    static func find(byModelFileName name: String) -> LightItem? {
        items.first { $0.modelFileName == name }
    }

    /// Look up a procedural light item by its kind.
    /// Used by persistence restore path and spawn routing.
    static func find(byProceduralKind kind: ProceduralLightKind) -> LightItem? {
        items.first { $0.proceduralKind == kind }
    }
}

// MARK: - Diffuser Helper

/// Applies diffusion by adjusting the inner/outer angle ratio.
/// diffuserAmount 0.0 → hard edge (inner close to outer)
/// diffuserAmount 1.0 → full silk (inner = 10% of outer — very soft gradual falloff)
func applyDiffuser(to config: inout LightConfigComponent) {
    let hardInner = config.outerAngleDeg - 5.0
    let softInner = config.outerAngleDeg * 0.1
    config.innerAngleDeg = hardInner + (softInner - hardInner) * config.diffuserAmount
    config.innerAngleDeg = max(1.0, config.innerAngleDeg)
}

// MARK: - UIColor Kelvin Extension

extension UIColor {
    /// Converts a colour temperature in Kelvin to an approximate RGB UIColor.
    /// Algorithm: Tanner Helland (2012), verified accurate 1000K–40000K.
    static func fromKelvin(_ kelvin: Float) -> UIColor {
        let temp = Double(kelvin) / 100.0
        let r, g, b: Double

        // Red
        if temp <= 66 {
            r = 255
        } else {
            r = min(max(329.698727446 * pow(temp - 60, -0.1332047592), 0), 255)
        }

        // Green
        if temp <= 66 {
            g = min(max(99.4708025861 * log(temp) - 161.1195681661, 0), 255)
        } else {
            g = min(max(288.1221695283 * pow(temp - 60, -0.0755148492), 0), 255)
        }

        // Blue
        if temp >= 66 {
            b = 255
        } else if temp <= 19 {
            b = 0
        } else {
            b = min(max(138.5177312231 * log(temp - 10) - 305.0447927307, 0), 255)
        }

        return UIColor(
            red: CGFloat(r / 255),
            green: CGFloat(g / 255),
            blue: CGFloat(b / 255),
            alpha: 1.0
        )
    }
}
