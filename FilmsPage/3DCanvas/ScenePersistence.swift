//
//  ScenePersistence.swift
//  3DCanvas
//
//  Save/load canvas scenes to JSON.
//  KEY RULE: All RealityKit scene graph access happens on the MAIN thread.
//  JSON encoding + disk I/O happens on a background thread.
//

import Foundation
import RealityKit
import UIKit

// MARK: - Codable Helpers

struct CodableTransform: Codable {
    let tx: Float; let ty: Float; let tz: Float
    let sx: Float; let sy: Float; let sz: Float
    let qx: Float; let qy: Float; let qz: Float; let qw: Float

    init(_ t: Transform) {
        tx = t.translation.x; ty = t.translation.y; tz = t.translation.z
        sx = t.scale.x;       sy = t.scale.y;       sz = t.scale.z
        qx = t.rotation.imag.x; qy = t.rotation.imag.y
        qz = t.rotation.imag.z; qw = t.rotation.real
    }

    var transform: Transform {
        Transform(
            scale:       SIMD3(sx, sy, sz),
            rotation:    simd_quatf(ix: qx, iy: qy, iz: qz, r: qw),
            translation: SIMD3(tx, ty, tz)
        )
    }
}

struct CodableSIMD3: Codable {
    let x: Float; let y: Float; let z: Float
    init(_ v: SIMD3<Float>) { x = v.x; y = v.y; z = v.z }
    var simd: SIMD3<Float> { SIMD3(x, y, z) }
}



struct EntityRecord: Codable {
    let name: String
    let modelFileName: String
    let toolType: String
    let isBackground: Bool
    let transform: CodableTransform
    let wallWidth: Float?
    let wallHeight: Float?
    let groundWidth: Float?
    let groundDepth: Float?
    let bgWidth: Float?
    let bgHeight: Float?
}

struct AnimationClipRecord: Codable {
    let id: String
    let entityName: String
    let type: String
    let track: String
    let easing: String
    let startTime: Float
    let duration: Float
    let fromValue: CodableSIMD3
    let toValue: CodableSIMD3
    let pathStart: CodableSIMD3?
    let pathControl1: CodableSIMD3?
    let pathControl2: CodableSIMD3?
    let pathEnd: CodableSIMD3?
}

struct CanvasSceneDocument: Codable {
    var version: Int = 1
    var sceneID: String
    var entities: [EntityRecord]
    var animationClips: [AnimationClipRecord]
    var backgroundCounter: Int
    var cameraYaw: Float
    var cameraPitch: Float
    var cameraDistance: Float
    var cameraTargetX: Float
    var cameraTargetY: Float
    var cameraTargetZ: Float
}

// MARK: - ScenePersistenceService

final class ScenePersistenceService {

    static let shared = ScenePersistenceService()
    private init() {}

    private func fileURL(for sceneID: UUID) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("scene_\(sceneID.uuidString).json")
    }

    func hasSave(for sceneID: UUID) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: sceneID).path)
    }

    func deleteSave(for sceneID: UUID) {
        try? FileManager.default.removeItem(at: fileURL(for: sceneID))
    }

    // MARK: - Save
    // Step 1: snapshot the RealityKit scene on the MAIN thread → pure value types
    // Step 2: encode + write JSON on a background thread → no RealityKit access
    // completion is called on the main thread when done

    func save(canvas vc: CanvasViewController, sceneID: UUID, completion: ((Bool) -> Void)? = nil) {
        // ── STEP 1: Read everything from RealityKit on main thread ──
        assert(Thread.isMainThread, "save() must be called from the main thread")

        guard let anchor = vc.arView.scene.findEntity(named: "MainAnchor") else {
            completion?(false)
            return
        }

        let skipNames: Set<String> = ["Grid", "EditorCamera", "MainAnchor"]

        var entityRecords: [EntityRecord] = []

        for entity in anchor.children {
            guard !skipNames.contains(entity.name),
                  !entity.name.isEmpty,
                  !entity.name.hasPrefix("PathRoot_"),
                  entity.name != "MotionPath"
            else { continue }

            let toolTypeTitle = entity.components[CategoryComponent.self]?.toolType.title ?? "Prop"
            let isBackground  = entity.components[CategoryComponent.self]?.toolType == .background
            let modelFileName = resolveModelFileName(entity: entity)

            var wallWidth: Float?; var wallHeight: Float?
            var groundWidth: Float?; var groundDepth: Float?
            var bgWidth: Float?; var bgHeight: Float?

            if let model = entity as? ModelEntity {
                if let w  = model.components[CanvasViewController.WallComponent.self]       { wallWidth = w.width;   wallHeight  = w.height }
                if let g  = model.components[CanvasViewController.GroundComponent.self]     { groundWidth = g.width; groundDepth = g.depth  }
                if let bg = model.components[CanvasViewController.BackgroundComponent.self]  { bgWidth = bg.width;   bgHeight    = bg.height }
            }

            entityRecords.append(EntityRecord(
                name: entity.name,
                modelFileName: modelFileName,
                toolType: toolTypeTitle,
                isBackground: isBackground,
                transform: CodableTransform(entity.transform),
                wallWidth: wallWidth, wallHeight: wallHeight,
                groundWidth: groundWidth, groundDepth: groundDepth,
                bgWidth: bgWidth, bgHeight: bgHeight
            ))
        }

        // Snapshot animation clips (pure Swift structs — safe to copy)
        let clipRecords: [AnimationClipRecord] = vc.timeline.clips.map { clip in
            var ps: CodableSIMD3? = nil; var pc1: CodableSIMD3? = nil
            var pc2: CodableSIMD3? = nil; var pe: CodableSIMD3? = nil
            if let path = clip.motionPath {
                ps = CodableSIMD3(path.start); pc1 = CodableSIMD3(path.control1)
                pc2 = CodableSIMD3(path.control2); pe = CodableSIMD3(path.end)
            }
            return AnimationClipRecord(
                id: clip.id.uuidString, entityName: clip.entityName,
                type: clip.type.rawValue, track: clip.track.rawValue,
                easing: clip.easing.rawValue, startTime: clip.startTime,
                duration: clip.duration, fromValue: CodableSIMD3(clip.fromValue),
                toValue: CodableSIMD3(clip.toValue),
                pathStart: ps, pathControl1: pc1, pathControl2: pc2, pathEnd: pe
            )
        }

        let doc = CanvasSceneDocument(
            sceneID: sceneID.uuidString,
            entities: entityRecords,
            animationClips: clipRecords,
            backgroundCounter: vc.backgroundCounter,
            cameraYaw: vc.yaw, cameraPitch: vc.pitch, cameraDistance: vc.distance,
            cameraTargetX: vc.cameraTarget.x,
            cameraTargetY: vc.cameraTarget.y,
            cameraTargetZ: vc.cameraTarget.z
        )

        let url = fileURL(for: sceneID)

        // ── STEP 2: Encode + write on background thread ──
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(doc)
                try data.write(to: url, options: .atomic)
                print("✅ Scene saved: \(url.lastPathComponent)")
                DispatchQueue.main.async { completion?(true) }
            } catch {
                print("❌ Scene save error: \(error)")
                DispatchQueue.main.async { completion?(false) }
            }
        }
    }



    @MainActor
    func load(into vc: CanvasViewController, sceneID: UUID) async {
        let url = fileURL(for: sceneID)
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("ℹ️ No saved scene for \(sceneID)"); return
        }

        // Phase 1: decode JSON off main thread
        let doc: CanvasSceneDocument
        do {
            let data = try await Task.detached(priority: .userInitiated) {
                try Data(contentsOf: url)
            }.value
            doc = try JSONDecoder().decode(CanvasSceneDocument.self, from: data)
        } catch {
            print("❌ Scene load error: \(error)"); return
        }

        // Restore camera state
        vc.yaw = doc.cameraYaw; vc.pitch = doc.cameraPitch
        vc.distance = doc.cameraDistance; vc.backgroundCounter = doc.backgroundCounter
        vc.cameraTarget = SIMD3(doc.cameraTargetX, doc.cameraTargetY, doc.cameraTargetZ)
        vc.updateEditorCamera()

        // Phase 2: restore entities sequentially on @MainActor
        for record in doc.entities {
            await restoreEntity(record: record, vc: vc)
        }

        // Phase 3: seed baseTransforms NOW — entities are confirmed in scene.
        // This is the critical fix. evaluateTimeline() has:
        //   guard let base = baseTransforms[entityName] else { continue }
        // Without this seeding step every animated entity is silently skipped.
        for record in doc.animationClips {
            if vc.baseTransforms[record.entityName] == nil,
               let entity = vc.arView.scene.findEntity(named: record.entityName) {
                vc.baseTransforms[record.entityName] = entity.transform
            }
        }

        // Phase 4: restore clip data into vc.timeline (no visuals yet)
        restoreClipsOnly(doc.animationClips, vc: vc)

        // Phase 5: show motion path visuals deferred + staggered
        // Staggering 50ms per path means the render loop gets clean frames
        // between each path's ModelEntities being added — zero visible lag.
        let clipsWithPaths = doc.animationClips.filter { $0.pathStart != nil }
        for (i, record) in clipsWithPaths.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) { [weak vc] in
                guard let vc = vc,
                      let clip = vc.timeline.clips.first(where: { $0.id.uuidString == record.id })
                else { return }
                vc.showMotionPath(for: clip)
            }
        }

        vc.refreshSidebarContent()
        print("✅ Loaded: \(doc.entities.count) entities, \(doc.animationClips.count) clips")
    }

    // MARK: - Entity Restoration (always called on @MainActor)

    @MainActor
    private func restoreEntity(record: EntityRecord, vc: CanvasViewController) async {
        guard let anchor = vc.arView.scene.findEntity(named: "MainAnchor") else { return }
        let t = record.transform.transform

        // Wall
        if record.name.lowercased().contains("wall") || record.modelFileName == "cube" {
            let e = ModelEntity()
            e.name = record.name
            let w = record.wallWidth ?? 1.5; let h = record.wallHeight ?? 1.2
            e.model = ModelComponent(
                mesh: MeshResource.generateBox(width: w, height: h, depth: 0.05),
                materials: [SimpleMaterial(color: .lightGray, roughness: 0.6, isMetallic: false)]
            )
            e.components.set(CategoryComponent(toolType: .wall))
            e.components.set(CanvasViewController.WallComponent(width: w, height: h))
            e.generateCollisionShapes(recursive: true)
            e.components.set(InputTargetComponent())
            e.transform = t
            anchor.addChild(e)
            return
        }

        // Ground
        if record.name.lowercased().contains("ground") {
            let e = ModelEntity()
            e.name = record.name
            let w = record.groundWidth ?? 4.0; let d = record.groundDepth ?? 4.0
            e.model = ModelComponent(
                mesh: MeshResource.generatePlane(width: w, depth: d),
                materials: [SimpleMaterial(color: .darkGray, roughness: 1.0, isMetallic: false)]
            )
            e.components.set(CategoryComponent(toolType: .wall))
            e.components.set(CanvasViewController.GroundComponent(width: w, depth: d))
            e.generateCollisionShapes(recursive: true)
            e.components.set(InputTargetComponent())
            e.transform = t
            anchor.addChild(e)
            return
        }

        // Scene Camera
        if record.name.lowercased().contains("scenecamera") {
            let root = Entity()
            root.name = record.name
            root.components.set(CategoryComponent(toolType: .camera))
            let visual = vc.makeCameraVisual()
            visual.generateCollisionShapes(recursive: true)
            visual.components.set(InputTargetComponent())
            let cam = PerspectiveCamera(); cam.isEnabled = false
            root.addChild(visual); root.addChild(cam)
            root.transform = t
            anchor.addChild(root)
            vc.sceneCameras.append(cam)
            vc.cameraToVisualMap[cam] = root
            vc.sceneCameraItems.append(CanvasViewController.SceneCameraItem(camera: cam, cameraRoot: root))
            vc.cameraCollectionView?.reloadData()
            return
        }

        // Background
        if record.isBackground || record.name.lowercased().contains("background") {
            let w = record.bgWidth ?? 2.0; let h = record.bgHeight ?? 1.5
            let e = ModelEntity(
                mesh: MeshResource.generateBox(width: w, height: h, depth: 0.05),
                materials: [UnlitMaterial()]
            )
            e.name = record.name
            e.components.set(CanvasViewController.BackgroundComponent(width: w, height: h))
            e.components.set(CategoryComponent(toolType: .background))
            e.generateCollisionShapes(recursive: true)
            e.components.set(InputTargetComponent())
            e.transform = t
            anchor.addChild(e)
            return
        }

        // Regular 3D model — async load is fine here since we're already in an async context
        do {
            let entity = try await Entity(named: record.modelFileName)
            entity.name = record.name
            let toolType = ToolType.allCases.first { $0.title == record.toolType } ?? .prop
            entity.components.set(CategoryComponent(toolType: toolType))
            entity.generateCollisionShapes(recursive: true)
            entity.components.set(InputTargetComponent())
            if record.modelFileName == "Spotlight"           { vc.addRealLightToModel(entity) }
            else if record.modelFileName.contains("LED")     { vc.addLEDPanel(to: entity) }
            else if record.modelFileName.contains("Lantern") { vc.addLantern(to: entity) }
            entity.transform = t   // apply saved transform AFTER load
            anchor.addChild(entity)
        } catch {
            print("⚠️ Could not restore '\(record.name)': \(error)")
        }
    }

    // MARK: - Clip Restoration
    //
    // restoreClipsOnly: adds clips to vc.timeline WITHOUT touching showMotionPath.
    // Motion path visuals are handled separately in load() with asyncAfter stagger.
    // This separation is what prevents the lag spike and missing-path bugs.

    private func restoreClipsOnly(_ records: [AnimationClipRecord], vc: CanvasViewController) {
        for record in records {
            guard let type   = AnimationType(rawValue: record.type),
                  let track  = AnimationTrack(rawValue: record.track),
                  let easing = EasingType(rawValue: record.easing) else { continue }

            var motionPath: BezierMotionPath? = nil
            if let ps = record.pathStart, let pc1 = record.pathControl1,
               let pc2 = record.pathControl2, let pe = record.pathEnd {
                motionPath = BezierMotionPath(
                    start:    ps.simd,
                    control1: pc1.simd,
                    control2: pc2.simd,
                    end:      pe.simd
                )
            }

            let clip = AnimationClip(
                entityName: record.entityName,
                type:       type,
                track:      track,
                easing:     easing,
                startTime:  record.startTime,
                duration:   record.duration,
                fromValue:  record.fromValue.simd,
                toValue:    record.toValue.simd,
                motionPath: motionPath
            )
            vc.timeline.addClip(clip)
            // NOTE: baseTransforms is seeded in load() Phase 3, not here.
            // NOTE: showMotionPath is called in load() Phase 5, not here.
        }
    }

    // MARK: - Helper

    private func resolveModelFileName(entity: Entity) -> String {
        let name = entity.name
        if let range = name.range(of: #"_\d+$"#, options: .regularExpression) {
            return String(name[name.startIndex..<range.lowerBound])
        }
        return name
    }
}
