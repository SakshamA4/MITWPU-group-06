//
//  CanvasViewController+ARInteraction.swift
//  FilmsPage
//

import UIKit
import RealityKit
import ARKit

extension CanvasViewController {

    func arSpawnPosition(verticalOffset: Float, liftToGround: Float) -> (x: Float, y: Float, z: Float) {
        guard isARModeActive else {
            return (Float.random(in: -1...1),
                    verticalOffset > 0 ? verticalOffset : liftToGround,
                    Float.random(in: -1...1))
        }
        let cam      = arView.cameraTransform
        let forward  = cam.rotation.act(SIMD3<Float>(0, 0, -1))
        let worldPos = cam.translation + forward * 1.5
        guard let anchor = mainAnchor else {
            return (worldPos.x, verticalOffset > 0 ? verticalOffset : liftToGround, worldPos.z)
        }
        let local  = anchor.convert(position: worldPos, from: nil)
        return (local.x, verticalOffset > 0 ? verticalOffset : liftToGround, local.z)
    }

    func gizmoPositionForEntity(_ entity: Entity) -> SIMD3<Float> {
        if let anchor = mainAnchor { return entity.position(relativeTo: anchor) }
        return entity.position(relativeTo: nil)
    }

    func arHandleEmptySpaceTap(at point: CGPoint) {
        guard isARModeActive else { return }
        placeSceneOnRealSurface(at: point)
    }

    func showARFeatureDisabledToast(_ message: String) {
        view.viewWithTag(9102)?.removeFromSuperview()
        let label = UILabel()
        label.tag = 9102
        label.text = "  \(message)  "
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
            label.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
        ])
        UIView.animate(withDuration: 0.3, delay: 2.0, options: .curveEaseOut) {
            label.alpha = 0
        } completion: { _ in label.removeFromSuperview() }
    }
}
