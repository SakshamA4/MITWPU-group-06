import Combine
import PhotosUI
import RealityKit
import UIKit
import ARKit

extension CanvasViewController {

    func makePathHandle(color: UIColor, name: String) -> ModelEntity {
        let mesh     = MeshResource.generateSphere(radius: 0.04)
        let material = SimpleMaterial(color: color, roughness: 0.2, isMetallic: true)
        let handle   = ModelEntity(mesh: mesh, materials: [material])
        handle.name  = name

        let collision = CollisionComponent(shapes: [.generateSphere(radius: 0.15)])
        handle.components.set(collision)
        handle.components.set(InputTargetComponent())
        return handle
    }

    func showMotionPath(for clip: AnimationClip) {
        guard let path = clip.motionPath else { return }

        activeMotionPaths[clip.id]?.root.removeFromParent()

        guard let anchor = arView.scene.findEntity(named: "MainAnchor") else { return }

        let pathRoot = Entity()
        pathRoot.name     = "PathRoot_\(clip.id)"
        pathRoot.position = path.start
        pathRoot.components.set(LockComponent(isLocked: false))

        let showStartHandle = shouldShowStartHandle(for: clip)

        let curve = MotionPathRenderer.makePathEntity(path: path)
        curve.name        = "MotionPath"
        curve.position    = .zero
        curve.orientation = simd_quatf()
        curve.scale       = .one
        pathRoot.addChild(curve)

        var startHandle: ModelEntity? = nil
        if showStartHandle {
            let start = makePathHandle(color: .gray, name: "path.start")
            start.components.set(MotionPathHandleComponent(clipID: clip.id))
            start.position = .zero
            pathRoot.addChild(start)
            startHandle = start
        }

        let c1 = makePathHandle(color: .orange, name: "path.c1")
        c1.components.set(MotionPathHandleComponent(clipID: clip.id))
        c1.position = path.control1 - path.start
        pathRoot.addChild(c1)

        let c2 = makePathHandle(color: .orange, name: "path.c2")
        c2.components.set(MotionPathHandleComponent(clipID: clip.id))
        c2.position = path.control2 - path.start
        pathRoot.addChild(c2)

        let end = makePathHandle(color: .systemBlue, name: "path.end")
        end.components.set(MotionPathHandleComponent(clipID: clip.id))
        end.position = (path.end - path.start) + SIMD3<Float>(0, 0.02, 0)
        pathRoot.addChild(end)

        anchor.addChild(pathRoot)

        activeMotionPaths[clip.id] = MotionPathVisual(
            root:           pathRoot,
            startHandle:    startHandle,
            control1Handle: c1,
            control2Handle: c2,
            endHandle:      end
        )
    }

    func showPathEditToolbar(for clipID: UUID, at screenPoint: CGPoint) {
        pathEditToolbar?.removeFromSuperview()

        guard let clipIndex = timeline.clips.firstIndex(where: { $0.id == clipID }) else { return }
        let clip = timeline.clips[clipIndex]

        let container = UIView()
        container.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        container.layer.cornerRadius = 14
        container.layer.shadowColor   = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.25
        container.layer.shadowRadius  = 8
        container.translatesAutoresizingMaskIntoConstraints = false

        let startField = UITextField()
        startField.borderStyle  = .roundedRect
        startField.keyboardType = .decimalPad
        startField.placeholder  = "Start Time"
        startField.text         = String(format: "%.2f", clip.startTime)

        let durationField = UITextField()
        durationField.borderStyle  = .roundedRect
        durationField.keyboardType = .decimalPad
        durationField.placeholder  = "Duration"
        durationField.text         = String(format: "%.2f", clip.duration)

        let applyButton = UIButton(type: .system)
        applyButton.setTitle("Apply", for: .normal)
        applyButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)

        let stack = UIStackView(arrangedSubviews: [startField, durationField, applyButton])
        stack.axis    = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(stack)
        view.addSubview(container)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            container.centerXAnchor.constraint(equalTo: view.leadingAnchor, constant: screenPoint.x),
            container.bottomAnchor.constraint(equalTo: view.topAnchor, constant: screenPoint.y - 20),
            container.widthAnchor.constraint(equalToConstant: 220),
        ])

        applyButton.addAction(UIAction { [weak self] _ in
            guard
                let self,
                let newStart    = Float(startField.text ?? ""),
                let newDuration = Float(durationField.text ?? ""),
                newDuration > 0
            else { return }

            let oldClip = self.timeline.clips[clipIndex]
            self.timeline.clips[clipIndex] = AnimationClip(
                entityName: oldClip.entityName,
                type:       oldClip.type,
                track:      oldClip.track,
                easing:     oldClip.easing,
                startTime:  newStart,
                duration:   newDuration,
                fromValue:  oldClip.fromValue,
                toValue:    oldClip.toValue,
                motionPath: oldClip.motionPath
            )

            let newClipID = self.timeline.clips[clipIndex].id
            if let visual = self.activeMotionPaths.removeValue(forKey: oldClip.id) {
                self.activeMotionPaths[newClipID] = visual
                let newComp = MotionPathHandleComponent(clipID: newClipID)
                visual.startHandle?.components.set(newComp)
                visual.control1Handle.components.set(newComp)
                visual.control2Handle.components.set(newComp)
                visual.endHandle.components.set(newComp)
                if self.selectedPathClipID == oldClip.id {
                    self.selectedPathClipID = newClipID
                }
            }
        }, for: .touchUpInside)

        pathEditToolbar = container
    }

    func showPathContextMenu(clipID: UUID, pathRoot: Entity) {
        let alert = UIAlertController(
            title: "Animation Path",
            message: nil,
            preferredStyle: .actionSheet
        )

        alert.addAction(UIAlertAction(title: "Edit Timing", style: .default) { [weak self] _ in
            guard let self else { return }
            self.selectedPathClipID = clipID
            self.updatePathSelection()
            if let screenPos = self.arView.project(pathRoot.position(relativeTo: nil)) {
                self.showPathEditToolbar(for: clipID, at: screenPos)
            }
        })

        let isLocked = pathRoot.components[LockComponent.self]?.isLocked ?? false
        alert.addAction(UIAlertAction(title: isLocked ? "Unlock Path" : "Lock Path", style: .default) { _ in
            var lock = pathRoot.components[LockComponent.self] ?? LockComponent(isLocked: false)
            lock.isLocked.toggle()
            pathRoot.components.set(lock)
            self.updatePathSelection()
        })

        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.selectedPathClipID = clipID
            self?.deleteSelected()
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    func updateEntityFinalTransforms() {
        let entities = Set(timeline.clips.map { $0.entityName })

        for entityName in entities {
            guard let entity = arView.scene.findEntity(named: entityName) else { continue }

            baseTransforms[entityName] = entity.transform

            let lastTime = timeline.clips
                .filter { $0.entityName == entityName }
                .map    { $0.startTime + $0.duration }
                .max() ?? 0

            entity.transform = evaluateEntityTransform(entityName: entityName, at: lastTime)
        }
    }
}
