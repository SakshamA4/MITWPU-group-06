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

        let moveBtn   = makeAnimButton(title: "Move",   action: #selector(animateMove))
        let rotateBtn = makeAnimButton(title: "Rotate", action: #selector(animateRotate))

        animationPanel.addArrangedSubview(moveBtn)
        animationPanel.addArrangedSubview(rotateBtn)

        view.addSubview(animationPanel)

        NSLayoutConstraint.activate([
            animationPanel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            animationPanel.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -90),
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
        UIView.animate(withDuration: 0.2) { self.animationPanel.alpha = 1 }
    }

    func hideAnimationPanel() {
        UIView.animate(withDuration: 0.2) { self.animationPanel?.alpha = 0 }
    }

    @objc func animateMove()   { presentAnimationPrompt(type: .move) }
    @objc func animateRotate() { presentAnimationPrompt(type: .rotate) }

    // ── Present the input card ────────────────────────────────────────────────

    func presentAnimationPrompt(type: AnimationType) {
        guard editorMode == .edit, let entity = selectedEntity else { return }

        let cardMode: AnimationCardMode = type == .move ? .addMove : .addRotate
        let card = AnimationInputCard(mode: cardMode)

        card.onConfirm = { [weak self] startTime, duration, degrees, axis in
            guard let self else { return }
            self.handleAnimationConfirm(
                type:      type,
                entity:    entity,
                startTime: startTime,
                duration:  duration,
                degrees:   degrees,
                axis:      axis
            )
        }

        present(card, animated: false)
    }

    // ── Confirm handler ───────────────────────────────────────────────────────

    func handleAnimationConfirm(
        type:      AnimationType,
        entity:    Entity,
        startTime: Float,
        duration:  Float,
        degrees:   Float,
        axis:      RotationAxis
    ) {
        guard duration > 0 else { return }

        let easing: EasingType = .easeInOut
        var track:     AnimationTrack
        var fromValue  = SIMD3<Float>.zero
        var toValue    = SIMD3<Float>.zero
        var motionPath: BezierMotionPath? = nil

        switch type {

        case .move:
            track = .position
            if baseTransforms[entity.name] == nil {
                baseTransforms[entity.name] = entity.transform
            }
            let evaluated = evaluateEntityTransform(entityName: entity.name, at: startTime)
            let start = evaluated.translation
            let end   = start + SIMD3<Float>(2, 0, 0)
            motionPath = BezierMotionPath(
                start:    start,
                control1: start + SIMD3<Float>(0.5, 0, 0),
                control2: start + SIMD3<Float>(1.5, 0, 0),
                end:      end
            )

        case .rotate:
            track     = .rotation
            // fromValue = normalised rotation axis, toValue.x = total radians (unbounded)
            fromValue = axis.simdAxis
            toValue   = SIMD3<Float>(degrees * (.pi / 180), 0, 0)
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
            // FIX: defer by one frame so the alert dismiss animation gets a clean
            // render pass before RealityKit builds 32+ mesh entities for the path.
            showMotionPathDeferred(for: clip)
        }
        if clip.track == .rotation {
            showRotationArc(for: clip, on: entity)
        }

        interactionMode = .move
        debugPrintTimeline()
    }

    // ── Legacy shim — kept for any surviving call sites ───────────────────────

    func handleAnimationPromptConfirm(
        type:   AnimationType,
        entity: Entity,
        alert:  UIAlertController
    ) {
        guard
            let s = alert.textFields?[0].text, let startTime = Float(s),
            let d = alert.textFields?[1].text, let duration  = Float(d),
            duration > 0
        else { return }

        let degrees: Float
        if type == .rotate,
           let t = alert.textFields?[2].text, let deg = Float(t) { degrees = deg }
        else { degrees = 90 }

        handleAnimationConfirm(type: type, entity: entity,
                                startTime: startTime, duration: duration,
                                degrees: degrees, axis: .y)
    }
}
