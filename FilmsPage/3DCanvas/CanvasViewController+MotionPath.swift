import Combine
import PhotosUI
import RealityKit
import UIKit
import ARKit

extension CanvasViewController {

    func makePathHandle(
        color: UIColor,
        name: String
    ) -> ModelEntity {
        
        // small visible handle
        let mesh = MeshResource.generateSphere(radius: 0.04)
        
        let material = SimpleMaterial(
            color: color,
            roughness: 0.2,
            isMetallic: true
        )
        
        let handle = ModelEntity(mesh: mesh, materials: [material])
        handle.name = name
        
        // LARGE invisible touch radius
        let collision = CollisionComponent(
            shapes: [.generateSphere(radius: 0.15)]
        )
        
        handle.components.set(collision)
        handle.components.set(InputTargetComponent())
        
        return handle
    }

    
    func showMotionPath(for clip: AnimationClip) {
        
        guard let path = clip.motionPath else { return }
        
        // Remove existing visual if any
        activeMotionPaths[clip.id]?.root.removeFromParent()
        
        guard let anchor = arView.scene.findEntity(named: "MainAnchor") else {
            return
        }
        
        // Root for this path
        let pathRoot = Entity()
        pathRoot.name = "PathRoot_\(clip.id)"
        pathRoot.position = path.start
        pathRoot.components.set(LockComponent(isLocked: false))
        
        // ─────────────────────────────────────
        // 1️⃣ Decide if START HANDLE should exist
        // ─────────────────────────────────────
        let showStartHandle = shouldShowStartHandle(for: clip)
        
        // ─────────────────────────────────────
        // 2️⃣ Create curve mesh
        // ─────────────────────────────────────
        let curve = MotionPathRenderer.makePathEntity(path: path)
        curve.name = "MotionPath"
        curve.position = .zero
        curve.orientation = simd_quatf()
        curve.scale = .one
        
        pathRoot.addChild(curve)
        
        // ─────────────────────────────────────
        // 3️⃣ Create handles (conditionally)
        // ─────────────────────────────────────
        var startHandle: ModelEntity? = nil
        
        if showStartHandle {
            let start = makePathHandle(color: .gray, name: "path.start")
            start.components.set(
                MotionPathHandleComponent(clipID: clip.id)
            )
            start.position = .zero
            pathRoot.addChild(start)
            startHandle = start
        }
        
        let c1 = makePathHandle(color: .orange, name: "path.c1")
        c1.components.set(
            MotionPathHandleComponent(clipID: clip.id)
        )
        c1.position = path.control1 - path.start
        pathRoot.addChild(c1)
        
        let c2 = makePathHandle(color: .orange, name: "path.c2")
        c2.components.set(
            MotionPathHandleComponent(clipID: clip.id)
        )
        c2.position = path.control2 - path.start
        pathRoot.addChild(c2)
        
        let end = makePathHandle(color: .systemBlue, name: "path.end")
        end.components.set(
            MotionPathHandleComponent(clipID: clip.id)
        )
        end.position = (path.end - path.start) + SIMD3<Float>(0, 0.02, 0)
        pathRoot.addChild(end)
        
        // ─────────────────────────────────────
        // 4️⃣ Add to scene
        // ─────────────────────────────────────
        anchor.addChild(pathRoot)
        
        // ─────────────────────────────────────
        // 5️⃣ Store visual (start may be nil)
        // ─────────────────────────────────────
        activeMotionPaths[clip.id] = MotionPathVisual(
            root: pathRoot,
            startHandle: startHandle,
            control1Handle: c1,
            control2Handle: c2,
            endHandle: end
        )
    }

    
    func showPathEditToolbar(for clipID: UUID, at screenPoint: CGPoint) {
        
        // Remove any existing toolbar
        pathEditToolbar?.removeFromSuperview()

        guard
            let clipIndex = timeline.clips.firstIndex(where: { $0.id == clipID }
            )
        else {
            return
        }
        
        let clip = timeline.clips[clipIndex]
        
        // Container
        let container = UIView()
        container.backgroundColor = UIColor.systemBackground.withAlphaComponent(
            0.95
        )
        container.layer.cornerRadius = 14
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.25
        container.layer.shadowRadius = 8
        container.translatesAutoresizingMaskIntoConstraints = false
        
        // Start time field
        let startField = UITextField()
        startField.borderStyle = .roundedRect
        startField.keyboardType = .decimalPad
        startField.placeholder = "Start Time"
        startField.text = String(format: "%.2f", clip.startTime)
        
        // Duration field
        let durationField = UITextField()
        durationField.borderStyle = .roundedRect
        durationField.keyboardType = .decimalPad
        durationField.placeholder = "Duration"
        durationField.text = String(format: "%.2f", clip.duration)
        
        // Apply button
        let applyButton = UIButton(type: .system)
        applyButton.setTitle("Apply", for: .normal)
        applyButton.titleLabel?.font = .systemFont(
            ofSize: 15,
            weight: .semibold
        )

        // Stack
        let stack = UIStackView(arrangedSubviews: [
            startField,
            durationField,
            applyButton,
        ])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(stack)
        view.addSubview(container)
        
        // Layout
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(
                equalTo: container.topAnchor,
                constant: 10
            ),
            stack.bottomAnchor.constraint(
                equalTo: container.bottomAnchor,
                constant: -10
            ),
            stack.leadingAnchor.constraint(
                equalTo: container.leadingAnchor,
                constant: 10
            ),
            stack.trailingAnchor.constraint(
                equalTo: container.trailingAnchor,
                constant: -10
            ),

            container.centerXAnchor.constraint(
                equalTo: view.leadingAnchor,
                constant: screenPoint.x
            ),
            container.bottomAnchor.constraint(
                equalTo: view.topAnchor,
                constant: screenPoint.y - 20
            ),
            container.widthAnchor.constraint(equalToConstant: 220),
        ])
        
        // ✅ APPLY CHANGES (UIKit-native, no Obj-C runtime)
        applyButton.addAction(
            UIAction { [weak self] _ in
                guard
                    let self,
                    let newStart = Float(startField.text ?? ""),
                    let newDuration = Float(durationField.text ?? ""),
                    newDuration > 0
                else { return }

                let oldClip = self.timeline.clips[clipIndex]

                self.timeline.clips[clipIndex] = AnimationClip(
                    entityName: oldClip.entityName,
                    type: oldClip.type,
                    track: oldClip.track,
                    easing: oldClip.easing,
                    startTime: newStart,
                    duration: newDuration,
                    fromValue: oldClip.fromValue,
                    toValue: oldClip.toValue,
                    motionPath: oldClip.motionPath
                )

                // Re-key the motion path visual to the new clip ID
                let newClipID = self.timeline.clips[clipIndex].id
                if let visual = self.activeMotionPaths.removeValue(forKey: oldClip.id) {
                    self.activeMotionPaths[newClipID] = visual
                    // CRITICAL: update the MotionPathHandleComponent on every handle
                    // entity so they carry the new UUID. Without this, all guard
                    // lookups after a timing edit silently fail (path can't be
                    // selected, handles move but curve doesn't update).
                    let newComp = MotionPathHandleComponent(clipID: newClipID)
                    visual.startHandle?.components.set(newComp)
                    visual.control1Handle.components.set(newComp)
                    visual.control2Handle.components.set(newComp)
                    visual.endHandle.components.set(newComp)
                    // Keep the selection in sync so the path stays red
                    if self.selectedPathClipID == oldClip.id {
                        self.selectedPathClipID = newClipID
                    }
                }
            },
            for: .touchUpInside
        )

        pathEditToolbar = container
    }


    
    func showPathContextMenu(
        clipID: UUID,
        pathRoot: Entity
    ) {
        let alert = UIAlertController(
            title: "Animation Path",
            message: nil,
            preferredStyle: .actionSheet
        )
        
        // ⏱ Edit Timing
        alert.addAction(
            UIAlertAction(title: "Edit Timing", style: .default) { _ in
                self.selectedPathClipID = clipID
                self.updatePathSelection()

                if let screenPos = self.arView.project(
                    pathRoot.position(relativeTo: nil)
                ) {
                    self.showPathEditToolbar(for: clipID, at: screenPos)
                }
            }
        )

        let isLocked =
        pathRoot.components[LockComponent.self]?.isLocked ?? false
        let lockTitle = isLocked ? "Unlock Path" : "Lock Path"

        alert.addAction(
            UIAlertAction(title: lockTitle, style: .default) { _ in
                var lock =
                    pathRoot.components[LockComponent.self]
                    ?? LockComponent(isLocked: false)
                lock.isLocked.toggle()
                pathRoot.components.set(lock)
                self.updatePathSelection()
            }
        )

        // 🗑 Delete
        alert.addAction(
            UIAlertAction(title: "Delete", style: .destructive) { _ in
                self.selectedPathClipID = clipID
                self.deleteSelected()
            }
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }


    func updateEntityFinalTransforms() {
        
        let entities = Set(timeline.clips.map { $0.entityName })
        
        for entityName in entities {
            
            guard let entity = arView.scene.findEntity(named: entityName) else {
                continue
            }
            
            // 🔥 REBASE BASE TRANSFORM TO CURRENT WORLD STATE
            baseTransforms[entityName] = entity.transform
            
            let lastTime =
                timeline.clips
                .filter { $0.entityName == entityName }
                .map { $0.startTime + $0.duration }
                .max() ?? 0

            let finalTransform = evaluateEntityTransform(
                entityName: entityName,
                at: lastTime
            )
            
            entity.transform = finalTransform
        }
    }

}
