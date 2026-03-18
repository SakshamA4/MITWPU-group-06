import Combine
import PhotosUI
import RealityKit
import UIKit
import ARKit

extension CanvasViewController {

    
    func setupAnimationPanel() {
        animationPanel = UIStackView()
        animationPanel.axis = .horizontal
        animationPanel.spacing = 12
        animationPanel.alignment = .center
        animationPanel.distribution = .fillEqually
        animationPanel.translatesAutoresizingMaskIntoConstraints = false
        animationPanel.alpha = 0
        
        let moveBtn = makeAnimButton(
            title: "Move",
            action: #selector(animateMove)
        )
        let rotateBtn = makeAnimButton(
            title: "Rotate",
            action: #selector(animateRotate)
        )
        
        animationPanel.addArrangedSubview(moveBtn)
        animationPanel.addArrangedSubview(rotateBtn)
        
        view.addSubview(animationPanel)
        
        NSLayoutConstraint.activate([
            animationPanel.centerXAnchor.constraint(
                equalTo: view.centerXAnchor
            ),
            animationPanel.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -90
            ),
            animationPanel.heightAnchor.constraint(equalToConstant: 44),
            animationPanel.widthAnchor.constraint(equalToConstant: 220),
        ])
    }

    
    func makeAnimButton(title: String, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.backgroundColor = .systemIndigo
        btn.setTitleColor(.white, for: .normal)
        btn.layer.cornerRadius = 10
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }

    
    func showAnimationPanel() {
        UIView.animate(withDuration: 0.2) {
            self.animationPanel.alpha = 1
        }
    }

    
    func hideAnimationPanel() {
        UIView.animate(withDuration: 0.2) {
            self.animationPanel?.alpha = 0
        }
    }

    
    @objc func animateMove() {
        presentAnimationPrompt(type: .move)
    }

    
    @objc func animateRotate() {
        presentAnimationPrompt(type: .rotate)
    }

    
    func presentAnimationPrompt(type: AnimationType) {
        guard editorMode == .edit else { return }
        guard let entity = selectedEntity else { return }

        let title = "Add \(type.rawValue.capitalized) Animation"
        let alert = UIAlertController(
            title: title,
            message: "Enter animation parameters",
            preferredStyle: .alert
        )

        alert.addTextField { field in
            field.placeholder = "Start Time (e.g. 0.0)"
            field.keyboardType = .decimalPad
            field.text = "0.0"
        }
        alert.addTextField { field in
            field.placeholder = "Duration (e.g. 1.0)"
            field.keyboardType = .decimalPad
            field.text = "1.0"
        }

        // For rotate: add a rotation amount field in degrees
        if type == .rotate {
            alert.addTextField { field in
                field.placeholder = "Rotation Amount in degrees (e.g. 90)"
                field.keyboardType = .decimalPad
                field.text = "90"
            }
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(
            UIAlertAction(title: "Add to Timeline", style: .default) { [weak self] _ in
                self?.handleAnimationPromptConfirm(type: type, entity: entity, alert: alert)
            }
        )
        present(alert, animated: true)
    }


    
    func handleAnimationPromptConfirm(
        type: AnimationType,
        entity: Entity,
        alert: UIAlertController
    ) {
        guard
            let startText    = alert.textFields?[0].text,
            let durationText = alert.textFields?[1].text,
            let startTime    = Float(startText),
            let duration     = Float(durationText),
            duration > 0
        else { return }

        // Read optional rotation degrees from third field (rotate type only)
        let rotationDegrees: Float
        if type == .rotate,
           let degText = alert.textFields?[2].text,
           let deg = Float(degText) {
            rotationDegrees = deg
        } else {
            rotationDegrees = 90
        }

        let easing: EasingType = .easeInOut
        var track:      AnimationTrack
        var fromValue = SIMD3<Float>.zero
        var toValue   = SIMD3<Float>.zero
        var motionPath: BezierMotionPath? = nil

        switch type {

        case .move:
            track = .position
            if baseTransforms[entity.name] == nil {
                baseTransforms[entity.name] = entity.transform
            }
            let evaluatedTransform = evaluateEntityTransform(entityName: entity.name, at: startTime)
            let start = evaluatedTransform.translation
            let end   = start + SIMD3<Float>(2, 0, 0)
            motionPath = BezierMotionPath(
                start:    start,
                control1: start + SIMD3<Float>(0.5, 0, 0),
                control2: start + SIMD3<Float>(1.5, 0, 0),
                end:      end
            )

        case .rotate:
            track     = .rotation
            // New model: fromValue = rotation axis (unit vector), toValue.x = totalRadians
            // Default axis is Y; user can change it via long-press → Edit Rotation after clip is added.
            fromValue = RotationAxis.y.simdAxis                          // axis vector (0,1,0)
            toValue   = SIMD3<Float>(rotationDegrees * (.pi / 180), 0, 0) // totalRadians in .x
        }

        if baseTransforms[entity.name] == nil {
            baseTransforms[entity.name] = entity.transform
        }

        let clip = AnimationClip(
            entityName: entity.name,
            type:       type,
            track:      track,
            easing:     easing,
            startTime:  startTime,
            duration:   duration,
            fromValue:  fromValue,
            toValue:    toValue,
            motionPath: motionPath
        )

        timeline.addClip(clip)

        if clip.motionPath != nil {
            showMotionPath(for: clip)
        }

        // Show rotation arc for any rotation clip (camera or regular entity)
        if clip.track == .rotation {
            showRotationArc(for: clip, on: entity)
        }

        // Always return to move mode after adding any animation clip so
        // rotation rings don't auto-appear on the next entity tap.
        interactionMode = .move

        debugPrintTimeline()
    }

}
