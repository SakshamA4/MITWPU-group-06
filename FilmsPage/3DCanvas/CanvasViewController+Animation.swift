// import Combine
// import PhotosUI
// import RealityKit
// import UIKit
// import ARKit
//
// extension CanvasViewController {
//
//    func setupAnimationPanel() {
//        animationPanel = UIStackView()
//        animationPanel.axis = .horizontal
//        animationPanel.spacing = 12
//        animationPanel.alignment = .center
//        animationPanel.distribution = .fillEqually
//        animationPanel.translatesAutoresizingMaskIntoConstraints = false
//        animationPanel.alpha = 0
//
//        let moveBtn   = makeAnimButton(title: "Move",   action: #selector(animateMove))
//        let rotateBtn = makeAnimButton(title: "Rotate", action: #selector(animateRotate))
//
//        animationPanel.addArrangedSubview(moveBtn)
//        animationPanel.addArrangedSubview(rotateBtn)
//
//        view.addSubview(animationPanel)
//
//        NSLayoutConstraint.activate([
//            animationPanel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//            animationPanel.bottomAnchor.constraint(
//                equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -90),
//            animationPanel.heightAnchor.constraint(equalToConstant: 44),
//            animationPanel.widthAnchor.constraint(equalToConstant: 220),
//        ])
//    }
//
//    func makeAnimButton(title: String, action: Selector) -> UIButton {
//        let btn = UIButton(type: .system)
//        btn.setTitle(title, for: .normal)
//        btn.backgroundColor = .systemIndigo
//        btn.setTitleColor(.white, for: .normal)
//        btn.layer.cornerRadius = 10
//        btn.addTarget(self, action: action, for: .touchUpInside)
//        return btn
//    }
//
//    func showAnimationPanel() {
//        UIView.animate(withDuration: 0.2) { self.animationPanel.alpha = 1 }
//    }
//
//    func hideAnimationPanel() {
//        UIView.animate(withDuration: 0.2) { self.animationPanel?.alpha = 0 }
//    }
//
//    @objc func animateMove()   { presentAnimationPrompt(type: .move) }
//    @objc func animateRotate() { presentAnimationPrompt(type: .rotate) }
//
//    // ── Present the input card ────────────────────────────────────────────────
//
//    func presentAnimationPrompt(type: AnimationType) {
//        guard editorMode == .edit, let entity = selectedEntity else { return }
//
//        let cardMode: AnimationCardMode = type == .move ? .addMove : .addRotate
//        let card = AnimationInputCard(mode: cardMode)
//
//        card.onConfirm = { [weak self] startTime, duration, degrees, axis in
//            guard let self else { return }
//            self.handleAnimationConfirm(
//                type:      type,
//                entity:    entity,
//                startTime: startTime,
//                duration:  duration,
//                degrees:   degrees,
//                axis:      axis
//            )
//        }
//
//        present(card, animated: false)
//    }
//
//    // ── Confirm handler ───────────────────────────────────────────────────────
//
//    func handleAnimationConfirm(
//        type:      AnimationType,
//        entity:    Entity,
//        startTime: Float,
//        duration:  Float,
//        degrees:   Float,
//        axis:      RotationAxis
//    ) {
//        guard duration > 0 else { return }
//
//        let easing: EasingType = .easeInOut
//        var track:     AnimationTrack
//        var fromValue  = SIMD3<Float>.zero
//        var toValue    = SIMD3<Float>.zero
//        var motionPath: BezierMotionPath? = nil
//
//        switch type {
//
//        case .move:
//            track = .position
//            if baseTransforms[entity.name] == nil {
//                baseTransforms[entity.name] = entity.transform
//            }
//            let evaluated = evaluateEntityTransform(entityName: entity.name, at: startTime)
//            let start = evaluated.translation
//            let end   = start + SIMD3<Float>(2, 0, 0)
//            motionPath = BezierMotionPath(
//                start:    start,
//                control1: start + SIMD3<Float>(0.5, 0, 0),
//                control2: start + SIMD3<Float>(1.5, 0, 0),
//                end:      end
//            )
//
//        case .rotate:
//            track     = .rotation
//            // fromValue = normalised rotation axis, toValue.x = total radians (unbounded)
//            fromValue = axis.simdAxis
//            toValue   = SIMD3<Float>(degrees * (.pi / 180), 0, 0)
//        }
//
//        if baseTransforms[entity.name] == nil {
//            baseTransforms[entity.name] = entity.transform
//        }
//
//        let clip = AnimationClip(
//            entityName: entity.name,
//            type:       type,
//            track:      track,
//            easing:     easing,
//            startTime:  startTime,
//            duration:   duration,
//            fromValue:  fromValue,
//            toValue:    toValue,
//            motionPath: motionPath
//        )
//
//        timeline.addClip(clip)
//
//        if clip.motionPath != nil {
//            showMotionPath(for: clip)
//        }
//        if clip.track == .rotation {
//            showRotationArc(for: clip, on: entity)
//        }
//
//        interactionMode = .move
//        debugPrintTimeline()
//    }
//
//    // ── Legacy shim — kept for any surviving call sites ───────────────────────
//
//    func handleAnimationPromptConfirm(
//        type:   AnimationType,
//        entity: Entity,
//        alert:  UIAlertController
//    ) {
//        guard
//            let s = alert.textFields?[0].text, let startTime = Float(s),
//            let d = alert.textFields?[1].text, let duration  = Float(d),
//            duration > 0
//        else { return }
//
//        let degrees: Float
//        if type == .rotate,
//           let t = alert.textFields?[2].text, let deg = Float(t) { degrees = deg }
//        else { degrees = 90 }
//
//        handleAnimationConfirm(type: type, entity: entity,
//                                startTime: startTime, duration: duration,
//                                degrees: degrees, axis: .y)
//    }
// }

//  CanvasViewController_Animation.swift
//  3DCanvas

import Combine
import PhotosUI
import RealityKit
import UIKit
import ARKit

extension CanvasViewController {

    // MARK: - Animation Panel

    func setupAnimationPanel() {
        animationPanel = UIStackView()
        animationPanel.axis = .horizontal
        animationPanel.spacing = 12
        animationPanel.alignment = .center
        animationPanel.distribution = .fillEqually
        animationPanel.translatesAutoresizingMaskIntoConstraints = false
        animationPanel.alpha = 0

        let moveBtn   = makeAnimButton(title: "Move", action: #selector(animateMove))
        let rotateBtn = makeAnimButton(title: "Rotate", action: #selector(animateRotate))

        animationPanel.addArrangedSubview(moveBtn)
        animationPanel.addArrangedSubview(rotateBtn)

        view.addSubview(animationPanel)

        NSLayoutConstraint.activate([
            animationPanel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            animationPanel.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -90),
            animationPanel.heightAnchor.constraint(equalToConstant: 44),
            animationPanel.widthAnchor.constraint(equalToConstant: 220)
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

    // MARK: - Move & Rotate

    @objc func animateMove()   { presentUnifiedAnimationPicker(preferredType: .move) }
    @objc func animateRotate() { presentUnifiedAnimationPicker(preferredType: .rotate) }
    
    private func presentUnifiedAnimationPicker(preferredType: AnimationType) {
        guard editorMode == .edit, let entity = selectedEntity else { return }
        guard let lightEntity = resolveLightEntity(from: entity) else {
            presentAnimationPrompt(type: preferredType)
            return
        }

        let alert = UIAlertController(
            title: "Add Animations",
            message: "Choose movement or light animation",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "Animate Light", style: .default) { [weak self] _ in
            self?.presentLightAnimationCard(for: lightEntity)
        })
        alert.addAction(UIAlertAction(title: "Move (Position Path)", style: .default) { [weak self] _ in
            self?.presentAnimationPrompt(type: .move)
        })
        alert.addAction(UIAlertAction(title: "Rotate", style: .default) { [weak self] _ in
            self?.presentAnimationPrompt(type: .rotate)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let pop = alert.popoverPresentationController {
            pop.sourceView = view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.maxY - 120, width: 1, height: 1)
            pop.permittedArrowDirections = []
        }

        present(alert, animated: true)
    }

    func presentAnimationPrompt(type: AnimationType) {
        guard editorMode == .edit, let entity = selectedEntity else { return }

        let cardMode: AnimationCardMode = type == .move ? .addMove : .addRotate
        let card = AnimationInputCard(mode: cardMode)

        card.onConfirm = { [weak self] startTime, duration, degrees, axis in
            guard let self else { return }
            self.handleAnimationConfirm(
                type: type,
                entity: entity,
                startTime: startTime,
                duration: duration,
                degrees: degrees,
                axis: axis
            )
        }

        present(card, animated: false)
    }

    // MARK: - Shared confirm handler (Move + Rotate + Walk)

    func handleAnimationConfirm(
        type: AnimationType,
        entity: Entity,
        startTime: Float,
        duration: Float,
        degrees: Float,
        axis: RotationAxis
    ) {
        guard duration > 0 else { return }

        var track: AnimationTrack
        var fromValue   = SIMD3<Float>.zero
        var toValue     = SIMD3<Float>.zero
        var motionPath: BezierMotionPath?

        switch type {

        case .move, .walk:
            track = .position
            if baseTransforms[entity.name] == nil {
                baseTransforms[entity.name] = entity.transform
            }
            let evaluated = evaluateEntityTransform(entityName: entity.name, at: startTime)
            let start = evaluated.translation
            let end   = start + SIMD3<Float>(2, 0, 0)
            motionPath = BezierMotionPath(
                start: start,
                control1: start + SIMD3<Float>(0.5, 0, 0),
                control2: start + SIMD3<Float>(1.5, 0, 0),
                end: end
            )

        case .rotate:
            track     = .rotation
            fromValue = axis.simdAxis
            toValue   = SIMD3<Float>(degrees * (.pi / 180), 0, 0)

        case .zoom:
            track = .fov

        case .light:
            // Light clips are created from LightAnimationInputCard; keep this path non-fatal.
            return
        }

        if baseTransforms[entity.name] == nil {
            baseTransforms[entity.name] = entity.transform
        }

        let clip = AnimationClip(
            entityName: entity.name,
            entityID: entity.components[EntityIDComponent.self]?.id,
            type: type,
            track: track,
            easing: type == .walk ? .linear : .easeInOut,
            startTime: startTime,
            duration: duration,
            fromValue: fromValue,
            toValue: toValue,
            motionPath: motionPath
        )

        timeline.addClip(clip)

        if clip.motionPath != nil { showMotionPath(for: clip) }
        if clip.track == .rotation { showRotationArc(for: clip, on: entity) }

        interactionMode = .move
        debugPrintTimeline()
    }

    // MARK: - Legacy shim (kept for any surviving call sites)

    func handleAnimationPromptConfirm(
        type: AnimationType,
        entity: Entity,
        alert: UIAlertController
    ) {
        guard
            let s = alert.textFields?[0].text, let startTime = Float(s),
            let d = alert.textFields?[1].text, let duration  = Float(d),
            duration > 0
        else { return }

        let degrees: Float
        if type == .rotate,
           let t = alert.textFields?[2].text,
           let deg = Float(t) { degrees = deg } else { degrees = 90 }

        handleAnimationConfirm(type: type, entity: entity,
                               startTime: startTime, duration: duration,
                               degrees: degrees, axis: .y)
    }

    // MARK: - Walk entry point

    @objc func animateWalk() {
        guard editorMode == .edit, let entity = selectedEntity else { return }

        guard let cat = entity.components[CategoryComponent.self],
              cat.toolType == .character else {
            let a = UIAlertController(
                title: "Characters Only",
                message: "Walk animation can only be added to character entities.",
                preferredStyle: .alert
            )
            a.addAction(UIAlertAction(title: "OK", style: .default))
            present(a, animated: true)
            return
        }

        // Reuse AnimationInputCard .addMove — same fields (start time + duration)
        let card = AnimationInputCard(mode: .addMove)
        card.onConfirm = { [weak self] startTime, duration, _, _ in
            guard let self, duration > 0 else { return }
            self.handleAnimationConfirm(
                type: .walk,
                entity: entity,
                startTime: startTime,
                duration: duration,
                degrees: 0,
                axis: .y
            )
        }
        present(card, animated: false)
    }

    // MARK: - Walk Playback (called from evaluateTimeline every tick)

    func applyWalkToEntity(_ entity: Entity, path: BezierMotionPath, progress: Float) {
        // 1. Position along bezier
        entity.position = path.evaluateConstantSpeed(progress)
        // 2. Face direction of travel
        faceDirectionOfTravel(entity: entity, path: path, t: progress)
        // 3. Start skeleton animation (WalkAnimationComponent guards re-entry)
        if entity.components[WalkAnimationComponent.self] == nil {
            startWalkCycle(on: entity)
        }
    }

    /// Recursively searches the entity and all its descendants for a node
    /// that has at least one available animation. This handles models like
    /// Lewis_walks where the animation clip lives on a child node rather
    /// than the top-level root entity that was added to MainAnchor.
    private func findAnimationBearingEntity(in entity: Entity) -> Entity? {
        if !entity.availableAnimations.isEmpty { return entity }
        for child in entity.children {
            if let found = findAnimationBearingEntity(in: child) { return found }
        }
        return nil
    }

    private func startWalkCycle(on entity: Entity) {
        // Search the full hierarchy — some models (e.g. Lewis_walks) store
        // their animation on a child node, not the root entity.
        guard let animEntity = findAnimationBearingEntity(in: entity) else {
            print("⚠️ No availableAnimations anywhere in hierarchy of \(entity.name) — skeleton cycle skipped")
            return
        }
        print("🚶 startWalkCycle: \(entity.name) | animating node: \(animEntity.name) | anims: \(animEntity.availableAnimations.count)")
        guard let anim = animEntity.availableAnimations.first else { return }

        // separateAnimatedValue: true → bones animate, root position stays
        // under our bezier control
        let controller = animEntity.playAnimation(
            anim.repeat(),
            transitionDuration: 0.3,
            separateAnimatedValue: true,
            startsPaused: false
        )
        entity.components.set(WalkAnimationComponent(controller: controller))
        activeWalkControllers[entity.name] = controller
        print("✅ Walk cycle started on \(entity.name) via \(animEntity.name)")
    }

    func stopWalkCycle(on entity: Entity) {
        if let comp = entity.components[WalkAnimationComponent.self] {
            comp.controller.stop(blendOutDuration: 0.15)
            entity.components.remove(WalkAnimationComponent.self)
        }
        activeWalkControllers.removeValue(forKey: entity.name)
    }

    func stopAllWalkCycles() {
        guard let anchor = arView.scene.findEntity(named: "MainAnchor") else { return }
        for child in anchor.children { stopWalkCycle(on: child) }
        activeWalkControllers.removeAll()
    }

    /// Recursively pauses any auto-playing animations on the entity or any of
    /// its descendants. Called on spawn so Mixamo models don't auto-walk in place.
    func pauseAllAnimations(in entity: Entity) {
        if !entity.availableAnimations.isEmpty {
            let ctrl = entity.playAnimation(
                entity.availableAnimations[0].repeat(count: 1),
                transitionDuration: 0,
                startsPaused: true
            )
            ctrl.pause()
        }
        for child in entity.children {
            pauseAllAnimations(in: child)
        }
    }

    // MARK: - Face Direction of Travel

    func faceDirectionOfTravel(entity: Entity, path: BezierMotionPath, t: Float) {
        let delta: Float = 0.02
        let t0 = max(0.001, t - delta)
        let t1 = min(0.999, t + delta)
        guard t1 > t0 else { return }

        let p0 = path.evaluateConstantSpeed(t0)
        let p1 = path.evaluateConstantSpeed(t1)

        var dir = p1 - p0
        dir.y = 0   // flatten to XZ — no tilting on hills
        let len = simd_length(dir)
        guard len > 0.0001 else { return }
        dir /= len

        let forward = SIMD3<Float>(0, 0, 1)
        let dot     = simd_dot(forward, dir)
        let clamped = max(-1, min(1, dot))

        let q: simd_quatf
        if abs(clamped + 1) < 0.001 {
            q = simd_quatf(angle: .pi, axis: [0, 1, 0])
        } else {
            let cross = simd_cross(forward, dir)
            q = simd_normalize(simd_quatf(ix: cross.x, iy: cross.y, iz: cross.z, r: 1 + clamped))
        }

        var transform = entity.transform
        transform.rotation = q
        entity.transform = transform
    }
}
