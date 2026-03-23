//
//  CanvasViewController+SkyPatch.swift
//  3DCanvas
//
//  Replace CanvasViewController_Spawning.swift's applySky(type:) and removeSky()
//  with these versions (comment out the ones in Spawning.swift).
//

import UIKit
import RealityKit
import ARKit

extension CanvasViewController {

    // MARK: - Apply Sky

    func applySky(type: String) {
        // Sky is not compatible with AR mode — camera feed IS the background.
        if isARModeActive {
            showARFeatureDisabledToast("Sky unavailable in AR mode")
            return
        }

        guard let anchor = mainAnchor else { return }

        // Remove ALL existing sky variants before adding a new one
        for child in anchor.children where child.name.hasPrefix("ProceduralSky") {
            child.removeFromParent()
        }

        var skyMaterial = UnlitMaterial()
        var topColor: UIColor = UIColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1)

        if type == "sky_image_1" {
            if let texture = try? TextureResource.load(named: type) {
                skyMaterial.color.texture = .init(texture)
                arView.environment.background = .color(.black)
            } else {
                topColor = .systemGray
                skyMaterial.color.tint = topColor
                arView.environment.background = .color(topColor)
            }
        } else {
            switch type {
            case "sky_sunset": topColor = .orange
            case "sky_night":  topColor = UIColor(red: 0.05, green: 0.05, blue: 0.2, alpha: 1)
            default:           topColor = UIColor(red: 0.4,  green: 0.7,  blue: 1.0, alpha: 1)
            }
            skyMaterial.color.tint = topColor
            arView.environment.background = .color(topColor)
        }

        let skyMesh   = MeshResource.generateSphere(radius: 50)
        let skyEntity = ModelEntity(mesh: skyMesh, materials: [skyMaterial])
        skyEntity.name        = "ProceduralSky_\(type)"
        skyEntity.scale      *= -1
        skyEntity.orientation = simd_quatf(angle: .pi, axis: [1, 0, 0])
        skyEntity.components.set(CategoryComponent(toolType: .sky))

        anchor.addChild(skyEntity)
        refreshSidebarContent()
    }

    // MARK: - Remove Sky

    func removeSky() {
        guard let anchor = mainAnchor else { return }
        for child in anchor.children where child.name.hasPrefix("ProceduralSky") {
            child.removeFromParent()
        }
        // Restore the correct background for the current mode
        arView.environment.background = isARModeActive ? .cameraFeed() : .color(.clear)
        refreshSidebarContent()
    }

    // MARK: - Sky Display Name (use in sidebar instead of raw entity name)

    func skyDisplayName(_ entityName: String) -> String {
        guard entityName.hasPrefix("ProceduralSky_") else { return "Sky" }
        let type = String(entityName.dropFirst("ProceduralSky_".count))
        switch type {
        case "sky_day":     return "Sky – Day"
        case "sky_sunset":  return "Sky – Sunset"
        case "sky_night":   return "Sky – Night"
        default:
            return "Sky – " + type
                .replacingOccurrences(of: "sky_", with: "")
                .replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
    }
}
