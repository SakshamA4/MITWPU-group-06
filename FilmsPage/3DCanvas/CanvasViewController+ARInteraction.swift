//
//  CanvasViewController+ARInteraction.swift
//  FilmsPage
//
//  All AR-specific interaction helpers live here so they don't clutter
//  the editor-mode gesture / gizmo / spawning files.
//  The existing files call into these thin helpers via one-line delegates.
//

import UIKit
import RealityKit
import ARKit

// MARK: - AR Interaction Helpers

extension CanvasViewController {

    // MARK: Spawning — position in front of AR camera

    /// Returns a spawn position 1.5 m in front of the device camera,
    /// expressed in MainAnchor-local coordinates.
    /// Call this from `spawnEntity` when `isARModeActive == true`.
    func arSpawnPosition(verticalOffset: Float, liftToGround: Float) -> (x: Float, y: Float, z: Float) {
        let camTransform = arView.cameraTransform
        let forward      = camTransform.rotation.act([0, 0, -1])   // camera looks –Z
        let camPos       = camTransform.translation
        let worldTarget  = camPos + forward * 1.5                  // 1.5 m ahead

        // Convert world position to MainAnchor-local coordinates
        if let anchor = mainAnchor {
            let anchorWorld = anchor.position(relativeTo: nil)
            let local       = worldTarget - anchorWorld
            let y = verticalOffset > 0 ? verticalOffset : max(liftToGround, local.y)
            return (local.x, y, local.z)
        } else {
            let y = verticalOffset > 0 ? verticalOffset : liftToGround
            return (worldTarget.x, y, worldTarget.z)
        }
    }

    // MARK: Gizmo — anchor-relative position

    /// Returns the position to set `gizmoRoot.position` to, correctly using
    /// MainAnchor as the reference frame (gizmo is a child of MainAnchor).
    func gizmoPositionForEntity(_ entity: Entity) -> SIMD3<Float> {
        if let anchor = mainAnchor {
            return entity.position(relativeTo: anchor)
        }
        return entity.position(relativeTo: nil)
    }

    // MARK: Tap — AR empty-space behaviour

    /// Called from `handleTap` when the user taps empty space in AR mode.
    /// Runs a raycast against detected planes and moves MainAnchor there.
    func arHandleEmptySpaceTap(at point: CGPoint) {
        guard isARModeActive else { return }
        placeSceneOnRealSurface(at: point)
    }

    // MARK: Sky — suppression toast

    /// Shows a brief auto-dismissing note explaining why Sky is unavailable
    /// in AR mode.  Called from `applySky` / `removeSky`.
    func showARFeatureDisabledToast(_ message: String) {
        let label = UILabel()
        label.text            = message
        label.textColor       = .white
        label.font            = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment   = .center
        label.numberOfLines   = 2
        label.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        label.layer.cornerRadius = 12
        label.clipsToBounds   = true
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
}
