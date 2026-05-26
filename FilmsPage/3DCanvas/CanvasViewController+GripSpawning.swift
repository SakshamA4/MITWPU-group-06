//
//  CanvasViewController+GripSpawning.swift
//  3DCanvas
//
//  Additive-only: Spawning logic for reflector and diffuser prop entities.
//  These are physical props — no RealityKit light component attached.
//  They use .prop toolType so existing selection, gizmo, move, rotate,
//  delete, and hierarchy support work automatically with zero new code.
//

import RealityKit
import UIKit

extension CanvasViewController {

    // MARK: - Reflector Spawning

    /// Spawns a reflector prop entity into the scene.
    func spawnReflector(type: SceneReflectorType) {
        saveCurrentStateToUndo()

        let entity = buildReflectorEntity(type: type)

        // Unique name
        let baseName = "Reflector_\(type.displayName)"
        let uniqueName: String = {
            guard let anchor = mainAnchor else { return baseName }
            let existing = anchor.children.filter {
                $0.name == baseName || $0.name.hasPrefix(baseName + "_")
            }.count
            return existing == 0 ? baseName : "\(baseName)_\(existing + 1)"
        }()
        entity.name = uniqueName

        // Position in front of camera at a reasonable height
        let randomX = Float.random(in: -0.5...0.5)
        let randomZ = Float.random(in: -0.5...0.5)
        entity.position = [randomX, 0.5, randomZ]

        // Assign as prop so existing systems handle it
        entity.components.set(CategoryComponent(toolType: .prop))
        entity.components.set(InputTargetComponent())
        entity.components.set(EntityIDComponent(id: UUID()))
        entity.generateCollisionShapes(recursive: true)

        if let anchor = mainAnchor {
            anchor.addChild(entity)
            refreshSidebarContent()
        }
    }

    // MARK: - Diffuser Spawning

    /// Spawns a diffuser prop entity into the scene.
    func spawnDiffuser(type: DiffuserType) {
        saveCurrentStateToUndo()

        let entity = buildDiffuserEntity(type: type)

        // Unique name
        let baseName = "Diffuser_\(type.displayName)"
        let uniqueName: String = {
            guard let anchor = mainAnchor else { return baseName }
            let existing = anchor.children.filter {
                $0.name == baseName || $0.name.hasPrefix(baseName + "_")
            }.count
            return existing == 0 ? baseName : "\(baseName)_\(existing + 1)"
        }()
        entity.name = uniqueName

        // Position in front of camera
        let randomX = Float.random(in: -0.5...0.5)
        let randomZ = Float.random(in: -0.5...0.5)
        entity.position = [randomX, 0.5, randomZ]

        entity.components.set(CategoryComponent(toolType: .prop))
        entity.components.set(InputTargetComponent())
        entity.components.set(EntityIDComponent(id: UUID()))
        entity.generateCollisionShapes(recursive: true)

        if let anchor = mainAnchor {
            anchor.addChild(entity)
            refreshSidebarContent()
        }
    }
}
