//
//  CanvasViewController+SkyPatch.swift
//  3DCanvas
//
//  CHANGES IN THIS VERSION vs what you have:
//  ─────────────────────────────────────────
//  1. applySky(type:) is now defined HERE — removes ALL ProceduralSky* entities
//     before adding a new one (fixes the Sky(3) duplicate stacking bug).
//     ★ Comment out applySky(type:) in CanvasViewController_Spawning.swift
//       to avoid a "redeclaration" compiler error.
//
//  2. removeSky() — unchanged from what you had.
//
//  3. skyDisplayName(_:) — NEW. Use in refreshSidebarContent() so sidebar shows
//     "Sky – Day" instead of the raw entity name "ProceduralSky_sky_day".
//     Usage:
//       let label = entity.name.hasPrefix("ProceduralSky")
//           ? skyDisplayName(entity.name) : entity.name
//
//  4. startARSession() / stopARSession() — NEW. Fixes the blank AR screen.
//     ★ Call startARSession()  where you activate AR mode.
//     ★ Call stopARSession()   where you deactivate AR mode.
//

import UIKit
import RealityKit
import ARKit

extension CanvasViewController {

    // MARK: - Apply Sky
    //
    // ★ REPLACE applySky(type:) in CanvasViewController_Spawning.swift with this.
    //   Comment out the one in Spawning.swift — this version takes over.
    //
    // FIX vs old: old version called findEntity(named: "ProceduralSky") which only
    // finds the entity with that exact name. After the rename to "ProceduralSky_sky_day"
    // the old remove call found nothing, so every tap stacked a new sphere on top.
    // This version removes ALL children whose name starts with "ProceduralSky".

    func applySky(type: String) {
        // In AR mode the real camera feed IS the background — skyboxes are meaningless
        if isARModeActive {
            showARSkySuppressedToast()
            return
        }
        guard let anchor = arView.scene.findEntity(named: "MainAnchor") else { return }

        // Remove ALL existing sky variants before adding a new one
        for child in anchor.children where child.name.hasPrefix("ProceduralSky") {
            child.removeFromParent()
        }

        // Build material
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
        print("🌅 Sky applied: \(type)")
    }

    // MARK: - Remove Sky
    //
    // Called when user taps "No Sky".
    // spawnEntity() intercepts modelFileName == "none" and routes here.

    func removeSky() {
        if isARModeActive {
            showARSkySuppressedToast()
            return
        }
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

    // MARK: - AR Session  (fixes blank screen in AR mode)
    //
    // automaticallyConfigureSession = false means RealityKit will NOT start the
    // camera feed. You must call arView.session.run(config) yourself.
    //
    // ★ Call startARSession()  wherever isARModeActive is set to true.
    // ★ Call stopARSession()   wherever isARModeActive is set to false.

    // MARK: - AR Mode Toggle
    //
    // CRASH FIX: arView.cameraMode = .nonAR — this is a virtual canvas.
    // Calling arView.session.run() on a nonAR-mode ARView crashes instantly
    // because the ARKit session is not bound to this view.
    //
    // MARK: - AR Sky Toast
    //
    // Shows a brief auto-dismissing note explaining why Sky is unavailable in AR mode.

    func showARSkySuppressedToast() {
        let label = UILabel()
        label.text = "🌤 Sky is disabled in AR mode — the real camera feed is your background."
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 2
        label.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        label.layer.cornerRadius = 12
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 80),
            label.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -40),
            label.heightAnchor.constraint(equalToConstant: 44),
        ])

        UIView.animate(withDuration: 0.3, delay: 2.5, options: .curveEaseOut) {
            label.alpha = 0
        } completion: { _ in
            label.removeFromSuperview()
        }
    }

    // startARSession / stopARSession now just toggle isARModeActive and hide/show sky.
    // The gesture handlers (orbit, pinch) already guard on isARModeActive, so
    // AR-mode behaviour (locked camera, device-moves-world) still works correctly.

//    func startARSession() {
//        isARModeActive = true
//        arView.renderOptions = [.disableMotionBlur, .disableDepthOfField]
//        // Hide sky — irrelevant when device camera is the intended background
//        if let anchor = arView.scene.findEntity(named: "MainAnchor") {
//            for child in anchor.children where child.name.hasPrefix("ProceduralSky") {
//                child.isEnabled = false
//            }
//        }
//        print("📷 AR mode ON")
//    }
//
//    func stopARSession() {
//        isARModeActive = false
//        arView.renderOptions = []
//        if let anchor = arView.scene.findEntity(named: "MainAnchor") {
//            for child in anchor.children where child.name.hasPrefix("ProceduralSky") {
//                child.isEnabled = true
//            }
//        }
//        print("🖥 AR mode OFF")
//    }
}
