//
//  CanvasViewController+SkyPatch.swift
//  3DCanvas
//
//  WHAT THIS FILE DOES:
//  Overrides the sky entity naming so ScenePersistence can detect the sky
//  type on save without needing a stored property on CanvasViewController.
//
//  HOW SKY WORKS (full workflow):
//  1. User taps Sky tool → tool sheet shows sky options + "No Sky"
//  2. Selecting a sky calls applySky(type: "sky_day") etc.
//     applySky removes any existing sky, creates a sphere entity named
//     "ProceduralSky_<type>" (e.g. "ProceduralSky_sky_day"), adds to scene.
//  3. Selecting "No Sky" calls removeSky() which finds any entity whose
//     name starts with "ProceduralSky" and removes it.
//  4. On SAVE: ScenePersistence walks anchor.children, finds the entity
//     named "ProceduralSky_sky_day", extracts "sky_day", stores in JSON.
//  5. On LOAD: ScenePersistence reads skyType from JSON, calls applySky(type:),
//     which recreates the sky sphere exactly as it was.
//
//  IMPORTANT: In CanvasViewController_Spawning.swift, inside applySky(type:),
//  change this line:
//
//      skyEntity.name = "ProceduralSky"
//
//  to:
//
//      skyEntity.name = "ProceduralSky_\(type)"
//
//  That single change makes the whole save/load chain work with no new properties.
//
//  The removeSky() function below handles all naming variants
//  ("ProceduralSky", "ProceduralSky_sky_day", etc.).
//

import UIKit
import RealityKit

extension CanvasViewController {

    // MARK: - Remove Sky
    //
    // Call this when user taps "No Sky" in the tool sheet.
    // Works regardless of whether the entity is named "ProceduralSky"
    // or "ProceduralSky_sky_day" etc.

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
}
