import Combine
import PhotosUI
import RealityKit
import UIKit
import ARKit

extension CanvasViewController {

//    func saveCurrentStateToUndo() {
//        let allEntities = arView.scene.anchors.flatMap { $0.children }
//        var snapshotDict: [String: Transform] = [:]
//        
//        for entity in allEntities {
//            snapshotDict[entity.name] = entity.transform
//        }
//        
//        let snapshot = SceneSnapshot(entityTransforms: snapshotDict)
//        
//        undoStack.append(snapshot)
//        redoStack.removeAll()
//    }
//    func saveCurrentStateToUndo() {
//        let anchor = arView.scene.findEntity(named: "MainAnchor")
//        var snapshotDict: [String: Transform] = [:]
//
//        anchor?.children.forEach { entity in
//            // Skip the grid (40,401 entities) and editor camera — they never need undo
//            guard entity.name != "Grid",
//                  entity.name != "EditorCamera"
//            else { return }
//            snapshotDict[entity.name] = entity.transform
//        }
//
//        undoStack.append(SceneSnapshot(entityTransforms: snapshotDict))
//        redoStack.removeAll()
//
//        // Cap the stack so memory doesn't grow forever
//        if undoStack.count > 30 {
//            undoStack.removeFirst()
//        }
//    }

    @objc func undoTapped() {
        guard let previousState = undoStack.popLast() else { return }

        // Save current state to redo before going back
        redoStack.append(createCurrentSnapshot())
        applySnapshot(previousState)
        refreshSidebarContent()
    }

    @objc func redoTapped() {
        guard let nextState = redoStack.popLast() else { return }

        // Save current state to undo before going forward
        undoStack.append(createCurrentSnapshot())

        applySnapshot(nextState)
    }

//    private func applySnapshot(_ snapshot: SceneSnapshot) {
//        // Unwrap the dictionary from the snapshot struct
//        for (name, transform) in snapshot.entityTransforms {
//            if let entity = arView.scene.findEntity(named: name) {
//                entity.transform = transform
//            }
//        }
//    }

    func restoreEntity(named name: String, with transform: Transform) {
        // 1. Detect category for all toolbar items based on your naming conventions
        let toolType: ToolType
        if name.contains("SceneCamera") {
            toolType = .camera
        } else if name.contains("Wall") || name.contains("Ground") {
            toolType = .wall
        } else if name.contains("Background") {
            toolType = .background
        } else if name.contains("Spotlight") || name.contains("LED") || name.contains("Lantern") {
            toolType = .light
        } else if name.contains("Woman") || name.contains("Man") {
            toolType = .character
        } else {
            toolType = .prop
        }

        // 2. Prepare the SpawnItem with all required compiler arguments
        let item = SpawnItem(
            title: name,
            imageName: "Image",
            modelFileName: name,
            isBackground: name.contains("Background")
        )

        Task {
            // 3. Re-spawn using your master logic
            // 📍 IMPORTANT: We pass 'isRestoring: true' so it doesn't create a new Undo point
            await spawnEntity(
                item: item,
                toolType: toolType,
                customName: name,
                isRestoring: true
            )

            // 4. 📍 THE FIX: Use a slight delay to ensure RealityKit has finished
            // adding the entity to the anchor before applying the transform
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self = self else { return }
                if let reSpawned = self.mainAnchor?.findEntity(named: name) {
                    reSpawned.transform = transform
                    print("✅ Redo Success: Restored \(name) to previous transform")
                }

                // 5. Update Sidebar UI to show the restored item
                self.refreshSidebarContent()
            }
        }
    }

    func createCurrentSnapshot() -> SceneSnapshot {
        var snapshotDict: [String: Transform] = [:]

        // Snapshot only user entities under MainAnchor — never the Grid (40k+ line entities),
        // EditorCamera, or PathContainer (motion-path geometry reconstructed from clips).
        let skipNames: Set<String> = ["Grid", "EditorCamera", "PathContainer"]
        mainAnchor?.children
            .filter { !skipNames.contains($0.name) && !$0.name.isEmpty }
            .forEach { snapshotDict[$0.name] = $0.transform }

        return SceneSnapshot(entityTransforms: snapshotDict)
    }

    func saveStateForUndo() {
        undoStack.append(createCurrentSnapshot())
        redoStack.removeAll()
    }

}
