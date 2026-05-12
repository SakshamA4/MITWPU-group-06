import Combine
import PhotosUI
import RealityKit
import UIKit
import ARKit

extension CanvasViewController {

    // NOTE: shouldShowStartHandle(for:) lives in CanvasViewController+Timeline.swift
    // to avoid the "invalid redeclaration" error. Do NOT redeclare it here.

    func makePathHandle(color: UIColor, name: String) -> ModelEntity {
        let mesh     = MeshResource.generateSphere(radius: 0.04)
        let material = SimpleMaterial(color: color, roughness: 0.2, isMetallic: true)
        let handle   = ModelEntity(mesh: mesh, materials: [material])
        handle.name  = name

        // Collision radius slightly larger than visual (0.04) for comfortable tapping,
        // but NOT 0.15 — that giant sphere overlaps camera model geometry and causes
        // the entity body hit-test to return the camera root instead of the handle,
        // which clears activeHandleEntity and drags all paths at once.
        let collision = CollisionComponent(shapes: [.generateSphere(radius: 0.06)])
        handle.components.set(collision)
        handle.components.set(InputTargetComponent())
        return handle
    }

    func showMotionPath(for clip: AnimationClip) {
        guard let path = clip.motionPath else { return }

        activeMotionPaths[clip.id]?.root.removeFromParent()

        guard let anchor = mainAnchor else { return }

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

        // Add path root to pathAnchor (not mainAnchor) so it is excluded from
        // sidebar, undo snapshots, and the save document automatically.
        (pathAnchor ?? anchor).addChild(pathRoot)

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

        let card = AnimationInputCard(mode: .editMoveTiming(
            currentStart:    clip.startTime,
            currentDuration: clip.duration
        ))

        card.onConfirm = { [weak self] newStart, newDuration, _, _ in
            guard let self, newDuration > 0 else { return }

            let oldClip = self.timeline.clips[clipIndex]
            let candidateClip = AnimationClip(
                preservingID: oldClip,
                startTime:    newStart,
                duration:     newDuration
            )

            if let conflictingClip = self.detectClipConflict(
                editedClip:  candidateClip,
                replacingID: oldClip.id
            ) {
                self.presentClipConflictResolution(
                    editedClip:      candidateClip,
                    replacingID:     oldClip.id,
                    conflicting:     conflictingClip,
                    clipIndex:       clipIndex,
                    originalEndTime: oldClip.startTime + oldClip.duration
                )
            } else {
                self.commitClipTimingChange(
                    newClip:   candidateClip,
                    oldClipID: oldClip.id,
                    clipIndex: clipIndex
                )
            }
        }

        present(card, animated: false)
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
            guard let entity = mainAnchor?.findEntity(named: entityName) else { continue }

            baseTransforms[entityName] = entity.transform

            let lastTime = timeline.clips
                .filter { $0.entityName == entityName }
                .map    { $0.startTime + $0.duration }
                .max() ?? 0

            entity.transform = evaluateEntityTransform(entityName: entityName, at: lastTime)
        }
    }
}
