//
//  CanvasViewController+SkyPatch.swift
//  3DCanvas
//

import UIKit
import RealityKit
import ARKit

extension CanvasViewController {


//    func applySky(type: String) {
//        guard let anchor = arView.scene.findEntity(named: "MainAnchor") else { return }
//
//        // Remove ALL existing sky variants before adding a new one
//        for child in anchor.children where child.name.hasPrefix("ProceduralSky") {
//            child.removeFromParent()
//        }
//
//        // Build material
//        var skyMaterial = UnlitMaterial()
//        var topColor: UIColor = UIColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1)
//
//        if type == "sky_image_1" {
//            if let texture = try? TextureResource.load(named: type) {
//                skyMaterial.color.texture = .init(texture)
//                arView.environment.background = .color(.black)
//            } else {
//                topColor = .systemGray
//                skyMaterial.color.tint = topColor
//                arView.environment.background = .color(topColor)
//            }
//        } else {
//            switch type {
//            case "sky_sunset": topColor = .orange
//            case "sky_night":  topColor = UIColor(red: 0.05, green: 0.05, blue: 0.2, alpha: 1)
//            default:           topColor = UIColor(red: 0.4,  green: 0.7,  blue: 1.0, alpha: 1)
//            }
//            skyMaterial.color.tint = topColor
//            arView.environment.background = .color(topColor)
//        }
//
//        let skyMesh   = MeshResource.generateSphere(radius: 50)
//        let skyEntity = ModelEntity(mesh: skyMesh, materials: [skyMaterial])
//        skyEntity.name        = "ProceduralSky_\(type)"
//        skyEntity.scale      *= -1
//        skyEntity.orientation = simd_quatf(angle: .pi, axis: [1, 0, 0])
//        skyEntity.components.set(CategoryComponent(toolType: .sky))
//
//        anchor.addChild(skyEntity)
//        refreshSidebarContent()
//        print("🌅 Sky applied: \(type)")
//    }

    // MARK: - Remove Sky
    //
    // Called when user taps "No Sky".
    // spawnEntity() intercepts modelFileName == "none" and routes here.

    func removeSky() {
        guard let anchor = arView.scene.findEntity(named: "MainAnchor") else { return }
        var removed = false
        for child in anchor.children {
            if child.name.hasPrefix("ProceduralSky") {
                child.removeFromParent()
                removed = true
            }
        }
        if removed {
            arView.environment.background = .color(.white)
            print("☁️ Sky removed")
        }
        refreshSidebarContent()
    }

    // MARK: - Sky Display Name
    //
    // Use this in your sidebar cell population instead of entity.name directly.
    // "ProceduralSky_sky_day"     → "Sky – Day"
    // "ProceduralSky_sky_sunset"  → "Sky – Sunset"
    // "ProceduralSky_sky_night"   → "Sky – Night"
    // "ProceduralSky_sky_image_1" → "Sky – Image 1"

    func skyDisplayName(_ entityName: String) -> String {
        guard entityName.hasPrefix("ProceduralSky_") else { return "Sky" }
        let type = String(entityName.dropFirst("ProceduralSky_".count))
        switch type {
        case "sky_day":     return "Sky – Day"
        case "sky_sunset":  return "Sky – Sunset"
        case "sky_night":   return "Sky – Night"
        default:
            let readable = type
                .replacingOccurrences(of: "sky_", with: "")
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
            return "Sky – \(readable)"
        }
    }
}
