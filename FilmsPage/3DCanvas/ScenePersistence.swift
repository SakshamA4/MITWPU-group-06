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

// MARK: - Codable helpers

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

// MARK: - EntityRecord
//
// `backgroundImagePath` is the filename (not full path) of the JPEG saved beside
// the scene JSON. It is nil for all non-background entities.

struct EntityRecord: Codable {
    /// Stable UUID assigned at spawn, survives save/load cycles.
    /// nil in pre-fix saves — treated as "no stable ID" on decode.
    let id: String?
    let name: String
    let modelFileName: String
    let toolType: String
    let isBackground: Bool
    let transform: CodableTransform
    let wallWidth: Float?
    let wallHeight: Float?
    let wallThickness: Float?
    let wallColorR: Float?
    let wallColorG: Float?
    let wallColorB: Float?
    let wallColorA: Float?
    let groundWidth: Float?
    let groundDepth: Float?
    let groundColorR: Float?
    let groundColorG: Float?
    let groundColorB: Float?
    let groundColorA: Float?
    let bgWidth: Float?
    let bgHeight: Float?
    let backgroundImagePath: String?
    /// Cinematic material config for walls/ground. nil = legacy color-only.
    let materialConfig: CinematicMaterialConfig?
    /// Camera visual model asset name (e.g. "cam1"). nil for non-camera entities.
    let cameraModelName: String?
}

// MARK: - AnimationClipRecord
//
// `id` round-trips verbatim so activeMotionPaths / activeRotationArcs stay valid after reload.

struct AnimationClipRecord: Codable {
    let id: String           // clip's own UUID — already correct
    let entityName: String   // name-based entity ref (primary lookup key)
    /// Stable entity UUID for forward-compat; nil in pre-fix saves.
    /// Not yet used for runtime lookup — entityName is still the key.
    let entityID: String?
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
    var version: Int = 2
    var sceneID: String
    var entities: [EntityRecord]
    var animationClips: [AnimationClipRecord]
    var backgroundCounter: Int
    /// Monotonically increasing camera counter — never reset on delete.
    /// Restored into vc.cameraCounter so newly spawned cameras after load
    /// always get a number higher than any previously assigned.
    /// Optional for backwards-compat with pre-fix saves (nil → treated as 0).
    var cameraCounter: Int?
    var cameraYaw: Float
    var cameraPitch: Float
    var cameraDistance: Float
    var cameraTargetX: Float
    var cameraTargetY: Float
    var cameraTargetZ: Float
    // nil = no sky; "sky_day" / "sky_sunset" / "sky_night" / "sky_image_1"
    var skyType: String?
    var baseTransforms: [String: CodableTransform]
}

// MARK: - ScenePersistenceService

final class ScenePersistenceService {

    static let shared = ScenePersistenceService()

    // FIX: Scene-scoped LRU model cache manager (replaces old global cache)
    // Manages model lifecycle with automatic memory eviction.
    private let modelCacheManager = ModelCacheManager()

    @objc private func clearModelCacheOnWarning() {
        modelCacheManager.clearAll()
    }

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearModelCacheOnWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    // MARK: - URL helpers

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func sceneFileURL(for id: UUID) -> URL {
        documentsDirectory.appendingPathComponent("scene_\(id.uuidString).json")
    }

    /// Returns only the filename component (not a full path) for a background image.
    private func bgImageFilename(entityName: String, sceneID: UUID) -> String {
        let safe = entityName.replacingOccurrences(of: "/", with: "_")
        return "scene_\(sceneID.uuidString)_bg_\(safe).jpg"
    }

    func hasSave(for sceneID: UUID) -> Bool {
        FileManager.default.fileExists(atPath: sceneFileURL(for: sceneID).path)
    }

    func deleteSave(for sceneID: UUID) {
        try? FileManager.default.removeItem(at: sceneFileURL(for: sceneID))
    }

    // MARK: - Thumbnail

    /// Saves a JPEG thumbnail to the Documents directory and returns the filename.
    /// The returned filename is stored in `ScenesModel.image` so that
    /// `setFilmImage(named:)` can locate it on disk for display in list views.
    ///
    /// - Returns: The filename (not full path) of the written JPEG, or nil if the
    ///   image or JPEG conversion was nil / the write failed.
    @discardableResult
    func saveThumbnail(_ image: UIImage?, sceneID: UUID) -> String? {
        guard let image = image,
              let jpegData = image.jpegData(compressionQuality: 0.75) else { return nil }
        let filename = "thumb_\(sceneID.uuidString).jpg"
        let url = documentsDirectory.appendingPathComponent(filename)
        do {
            try jpegData.write(to: url, options: .atomic)
            print("✅ Thumbnail saved: \(filename)")
            return filename
        } catch {
            print("❌ Thumbnail save failed: \(error)")
            return nil
        }
    }

    // MARK: - Save
    //
    // Step 1 (main thread)  – snapshot the RealityKit scene into plain value types.
    //                         Read UIImages from BackgroundComponent.cachedImage.
    // Step 2 (background)   – encode JSON + write JPEG files to disk.
    // Completion            – called back on the main thread.

    func save(
        canvas vc: CanvasViewController,
        sceneID: UUID,
        completion: ((Bool) -> Void)? = nil
    ) {
        assert(Thread.isMainThread, "save() must be called from the main thread")
        // Reset all entities to rest pose before saving transforms
        let savedBaseTransforms = vc.baseTransforms.mapValues { CodableTransform($0) }
        vc.evaluateTimeline(at: 0)
        guard let anchor = vc.arView.scene.findEntity(named: "MainAnchor") else {
            completion?(false)
            return
        }

        // Skip all internal/runtime entities that cannot be saved as records.
        // GizmoRoot and ring entities are runtime UI only.
        // Light group children are re-attached by addRealLightToModel/addLEDPanel/addLantern on load.
        // ProceduralSky is re-applied via applySky on load (not stored here).
        let skipNames: Set<String> = [
            "Grid", "EditorCamera", "MainAnchor",
            "GizmoRoot",
            "xRing", "yRing", "zRing",
            "Gizmo_Arrow_Y", "PlaneHandle", "Gizmo_Plane_XZ",
            "LED_Guts_Group", "Lantern_Guts_Group",
            "DynamicPointLight", "LanternInternalLight",
            "ProceduralSky"
        ]

        var entityRecords:   [EntityRecord] = []
        var bgImagePayloads: [(filename: String, data: Data)] = []

        for entity in anchor.children {
            let eName = entity.name
            guard !skipNames.contains(eName),
                  !eName.hasPrefix("ProceduralSky"),
                  !eName.isEmpty,
                  !eName.hasPrefix("PathRoot_"),
                  !eName.hasPrefix("Gizmo_"),
                  !eName.contains("Ring"),
                   !eName.contains("Guts"),
                   eName != "MotionPath"
             else { continue }

             let toolTypeTitle = entity.components[CategoryComponent.self]?.toolType.title ?? "Prop"
             let isBackground  = entity.components[CategoryComponent.self]?.toolType == .background
             let modelFileName = resolveModelFileName(entity: entity)

             var wallWidth: Float?;   var wallHeight: Float?;   var wallThickness: Float?
             var wallColorR: Float?;  var wallColorG: Float?
             var wallColorB: Float?;  var wallColorA: Float?
             var groundWidth: Float?; var groundDepth: Float?
             var groundColorR: Float?; var groundColorG: Float?
             var groundColorB: Float?; var groundColorA: Float?
             var bgWidth: Float?;     var bgHeight: Float?
             var backgroundImagePath: String?
             var materialConfig: CinematicMaterialConfig?
             var cameraModelName: String?

             // Extract camera visual model name from CameraVisualComponent
             if let camVisual = entity.components[CanvasViewController.CameraVisualComponent.self] {
                 cameraModelName = camVisual.modelName
             }

             if let model = entity as? ModelEntity {

                 if let w = model.components[CanvasViewController.WallComponent.self] {
                     wallWidth = w.width; wallHeight = w.height; wallThickness = w.thickness
                     wallColorR = w.colorR; wallColorG = w.colorG
                     wallColorB = w.colorB; wallColorA = w.colorA
                     materialConfig = w.materialConfig
                 }

                 if let g = model.components[CanvasViewController.GroundComponent.self] {
                     groundWidth = g.width; groundDepth = g.depth
                     groundColorR = g.colorR; groundColorG = g.colorG
                     groundColorB = g.colorB; groundColorA = g.colorA
                     materialConfig = g.materialConfig
                 }

                // Background image extraction.
                //
                // RealityKit exposes no API to read pixel data back out of a TextureResource,
                // so we rely on BackgroundComponent.cachedImage — the UIImage stored when
                // applyBackgroundImage() or restoreEntity() created the entity.
                if let bg = model.components[CanvasViewController.BackgroundComponent.self] {
                    bgWidth  = bg.width
                    bgHeight = bg.height

                    // Prefer the image stored in BackgroundComponent.cachedImage.
                    // Fall back to vc.backgroundImageCache (keyed by entity name) in case
                    // cachedImage was lost after a TextureResource upload failure on a
                    // previous restore — the VC-level cache is populated independently
                    // and survives texture upload failures.
                    let imageToSave = bg.cachedImage ?? vc.backgroundImageCache[entity.name]

                    if let image    = imageToSave,
                       let jpegData = image.jpegData(compressionQuality: 0.9) {
                         let filename = bgImageFilename(entityName: entity.name, sceneID: sceneID)
                         bgImagePayloads.append((filename, jpegData))
                         backgroundImagePath = filename
                         print("💾 Saving background image for '\(entity.name)': \(filename) (size: \(jpegData.count) bytes)")

                        // Keep BackgroundComponent.cachedImage in sync so future paths
                        // that read the component directly also find the image.
                        if bg.cachedImage == nil {
                            var updated = bg
                            updated.cachedImage = image
                            model.components.set(updated)
                        }
                    } else {
                        print("⚠️ Save: '\(entity.name)' has no image in cachedImage or backgroundImageCache — texture will not be saved.")
                    }
                }
            }

             entityRecords.append(EntityRecord(
                 id:                  {
                     // Read existing stable UUID from component; assign one if missing.
                     if entity.components[CanvasViewController.EntityIDComponent.self] == nil {
                         entity.components.set(CanvasViewController.EntityIDComponent(id: UUID()))
                     }
                     return entity.components[CanvasViewController.EntityIDComponent.self]!.id.uuidString
                 }(),
                 name:                entity.name,
                 modelFileName:       modelFileName,
                 toolType:            toolTypeTitle,
                 isBackground:        isBackground,
                 transform:           CodableTransform(entity.transform),
                 wallWidth:           wallWidth,   wallHeight:   wallHeight,
                 wallThickness:       wallThickness,
                 wallColorR:          wallColorR,  wallColorG:   wallColorG,
                 wallColorB:          wallColorB,  wallColorA:   wallColorA,
                 groundWidth:         groundWidth, groundDepth:  groundDepth,
                 groundColorR:        groundColorR, groundColorG: groundColorG,
                 groundColorB:        groundColorB, groundColorA: groundColorA,
                 bgWidth:             bgWidth,     bgHeight:     bgHeight,
                 backgroundImagePath: backgroundImagePath,
                 materialConfig:      materialConfig,
                 cameraModelName:     cameraModelName
             ))
        }

        let clipRecords: [AnimationClipRecord] = vc.timeline.clips.map { clip in
            var ps:  CodableSIMD3?; var pc1: CodableSIMD3?
            var pc2: CodableSIMD3?; var pe:  CodableSIMD3?
            if let path = clip.motionPath {
                ps  = CodableSIMD3(path.start)
                pc1 = CodableSIMD3(path.control1)
                pc2 = CodableSIMD3(path.control2)
                pe  = CodableSIMD3(path.end)
            }
            return AnimationClipRecord(
                id:           clip.id.uuidString,
                entityName:   clip.entityName,
                entityID:     {
                    if let id = clip.entityID { return id.uuidString }
                    // Persist the entity's stable UUID alongside the name for future use.
                    if let entity = vc.mainAnchor?.findEntity(named: clip.entityName) {
                        return entity.components[CanvasViewController.EntityIDComponent.self]?.id.uuidString
                    }
                    return nil
                }(),
                type:         clip.type.rawValue,
                track:        clip.track.rawValue,
                easing:       clip.easing.rawValue,
                startTime:    clip.startTime,
                duration:     clip.duration,
                fromValue:    CodableSIMD3(clip.fromValue),
                toValue:      CodableSIMD3(clip.toValue),
                pathStart:    ps,  pathControl1: pc1,
                pathControl2: pc2, pathEnd:      pe
            )
        }

        // Detect sky type directly from the scene — no extra property needed on CanvasViewController.
        // applySky(type:) names the entity "ProceduralSky_<type>" (e.g. "ProceduralSky_sky_day").
        // If it finds a plain "ProceduralSky" entity we can't recover the type, so we store nil
        // and the sky won't be re-applied on load (acceptable — user can re-select it).
        let savedSkyType: String? = {
            // Look for entity named "ProceduralSky_<type>"
            for child in anchor.children {
                if child.name.hasPrefix("ProceduralSky_") {
                    let type = String(child.name.dropFirst("ProceduralSky_".count))
                    return type.isEmpty ? nil : type
                }
            }
            // Fallback: check CategoryComponent on any sky entity
            for child in anchor.children {
                if child.components[CategoryComponent.self]?.toolType == .sky,
                   child.name != "Grid" {
                    // We can't recover the exact type string without extra metadata
                    return nil
                }
            }
            return nil
        }()

        let doc = CanvasSceneDocument(
            sceneID:           sceneID.uuidString,
            entities:          entityRecords,
            animationClips:    clipRecords,
            backgroundCounter: vc.backgroundCounter,
            cameraCounter:     vc.cameraCounter,
            cameraYaw: vc.yaw, cameraPitch: vc.pitch, cameraDistance: vc.distance,
            cameraTargetX: vc.cameraTarget.x,
            cameraTargetY: vc.cameraTarget.y,
            cameraTargetZ: vc.cameraTarget.z,
            skyType: savedSkyType,
            baseTransforms: vc.baseTransforms.mapValues { CodableTransform($0) }
        )

        let jsonURL = sceneFileURL(for: sceneID)
        let docsDir = documentsDirectory

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let encoder = JSONEncoder()
                // FIX 9: Removed .prettyPrinted and .sortedKeys — both options cause
                // significant overhead on large documents. Compact JSON is ~30% faster
                // to encode and produces smaller files with no functional difference.
                try encoder.encode(doc).write(to: jsonURL, options: .atomic)

                for payload in bgImagePayloads {
                    let imgURL = docsDir.appendingPathComponent(payload.filename)
                    try payload.data.write(to: imgURL, options: .atomic)
                }

                print("✅ Saved: \(jsonURL.lastPathComponent), \(bgImagePayloads.count) bg image(s)")
                DispatchQueue.main.async { completion?(true) }
            } catch {
                print("❌ Save error: \(error)")
                DispatchQueue.main.async { completion?(false) }
            }
        }
    }

    // MARK: - Load
    //
    // Phase 1  – decode JSON off the main thread.
    // Phase 2  – clear ALL stale state (no duplicates or memory leaks on repeat loads).
    // Phase 3  – restore camera state.
    // Phase 4  – restore entities CONCURRENTLY.
    //            Multiple Entity(named:) USDZ loads happen in parallel; instant entities
    //            (walls, grounds, backgrounds, cameras) complete immediately.
    //            All scene-graph mutations happen on @MainActor.
    // Phase 5  – reload the camera collection view ONCE after all cameras are appended.
    //            (Moving this out of restoreEntity fixes the camera sidebar race condition.)
    // Phase 6  – seed baseTransforms.
    // Phase 7  – restore animation clips with original stable UUIDs.
    // Phase 8  – show motion path visuals, one render-frame apart.
    // Phase 9  – single sidebar refresh.

    @MainActor
    func load(into vc: CanvasViewController, sceneID: UUID) async {
        let url = sceneFileURL(for: sceneID)
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("ℹ️ No saved scene for \(sceneID)")
            return
        }

        // Phase 1 – decode off main thread
        let doc: CanvasSceneDocument
        do {
            let data = try await Task.detached(priority: .userInitiated) {
                try Data(contentsOf: url)
            }.value
            doc = try JSONDecoder().decode(CanvasSceneDocument.self, from: data)
        } catch {
            print("❌ Load error: \(error)")
            return
        }

        // Phase 2 – clean slate
        // FIX: Evict LRU scene from cache if memory pressure detected
        modelCacheManager.evictLRUSceneIfNeeded()
        clearSceneState(vc: vc)

        // FIX 8: Suppress intermediate sidebar rebuilds during load.
        // refreshSidebarContent() is called below at Phase 9 exactly once.
        vc.isBatchLoading = true

        // FIX C: Pause the display link for the duration of the load.
        // If playback is running, the display link fires evaluateTimeline(at:) every frame,
        // which reads vc.timeline.clips while restoreClipsOnly() below is writing them —
        // a data race that causes clips to vanish or apply to wrong entities.
        let wasPlaying = vc.playbackState == .playing
        vc.displayLink?.isPaused = true
        vc.playbackState = .stopped

        // Phase 3 – camera state
        vc.yaw            = doc.cameraYaw
        vc.pitch          = doc.cameraPitch
        vc.distance       = doc.cameraDistance
        vc.backgroundCounter = doc.backgroundCounter
        vc.cameraTarget   = SIMD3(doc.cameraTargetX, doc.cameraTargetY, doc.cameraTargetZ)
        // Restore the monotonic camera counter.
        // For pre-fix saves where cameraCounter was never stored (nil), fall back to
        // counting the camera entity records so the counter is at least as large as
        // the number of cameras that are about to be restored — preventing name reuse.
        vc.cameraCounter = doc.cameraCounter
            ?? doc.entities.filter { $0.name.lowercased().contains("scenecamera") }.count
        vc.updateEditorCamera()

        // Phase 4 – serial entity restore.
        //
        // FIX: replaced concurrent withTaskGroup with a serial for-loop.
        //
        // The previous concurrent approach had a race condition: restoreEntity is
        // @MainActor but contains `await TextureResource(image:options:)` suspension
        // points. When a task suspends, another task runs. Because `backgroundCounter`
        // is a plain `var` (no locking) and entity transforms are applied inside async
        // continuations, multiple concurrent tasks could read-modify-write the counter
        // simultaneously and apply transforms out of order — causing entities to land
        // at (0,0,0) instead of their saved positions.
        //
        // A serial loop is safe, predictable, and still avoids blocking the main thread
        // because each `await restoreEntity(...)` suspends cooperatively while GPU
        // texture uploads (TextureResource) and USDZ decompression (Entity(named:))
        // run on background executors.
        //
        // NOTE: cameraCollectionView.reloadData() is deliberately NOT called inside
        // restoreEntity. Phase 5 calls reloadData() once after all entities are restored.
        for record in doc.entities {
            await restoreEntity(record: record, vc: vc, sceneID: sceneID)
        }

        // Phase 5 – reload camera collection view once, now that all cameras are appended.
        vc.cameraCollectionView?.reloadData()

        // Phase 5b – show the camera panel pull-tab and capture previews if cameras were restored.
        if !vc.sceneCameraItems.isEmpty {
            vc.view.viewWithTag(8803)?.alpha = 1.0
            vc.setCameraPanelExpanded(true, animated: false)
            // FIX 7: Increased delay to 1.5s so RealityKit has time to render
            // restored entities before capture. Added a guard so capture is skipped
            // if the user is already interacting or playback is running.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak vc] in
                guard let vc = vc,
                      !vc.isDraggingObject,
                      vc.playbackState == .stopped else { return }
                vc.captureAllPreviews()
            }
        }

        // Phase 6 – seed baseTransforms
        for record in doc.animationClips {
            guard let entity = resolveEntity(for: record, in: vc) else { continue }
            if vc.baseTransforms[entity.name] == nil {
                vc.baseTransforms[entity.name] = entity.transform
            }
        }

        // Phase 7 – animation clips
        restoreClipsOnly(doc.animationClips, vc: vc)

        // Phase 8 – motion path visuals.
        // No polling needed — entities are in the scene after the Phase 4 group.
        // Yield one frame between each path to keep the render loop responsive.
        let clipsWithPaths = vc.timeline.clips.filter { $0.motionPath != nil }
        for (index, clip) in clipsWithPaths.enumerated() {
            if index > 0 {
                try? await Task.sleep(nanoseconds: 16_000_000) // ~1 frame @ 60 fps
            }
            vc.showMotionPath(for: clip)
        }

        // Phase 9 – single sidebar refresh
        vc.isBatchLoading = false   // FIX 8: re-enable before the final refresh
        // Phase 6: restore sky if one was saved
        if let skyType = doc.skyType {
            vc.applySky(type: skyType)
            // skyType is encoded in the entity name by applySky — no extra property needed
        }

        vc.refreshSidebarContent()
        print("✅ Loaded: \(doc.entities.count) entities, \(doc.animationClips.count) clips")
        
        // FIX: Log memory diagnostics for debugging and tuning
        logCacheStats()

        // Phase 9.5 – serialised collision shape generation (FIX E).
        //
        // Previously each restoreEntity branch launched its own Task { generateCollisionShapes }
        // which caused all N tasks to run concurrently on the main actor right after load,
        // stalling the render loop for N × (shape-gen time) ms in rapid succession.
        //
        // Instead we walk the anchor children once, generating collision shapes one entity
        // per frame so the render loop always has a chance to run between them.
        let skipCollision: Set<String> = ["Grid", "EditorCamera", "PathContainer"]
        Task { @MainActor [weak vc] in
            guard let vc = vc, let anchor = vc.mainAnchor else { return }
            for child in anchor.children {
                guard !skipCollision.contains(child.name),
                      !child.name.hasPrefix("PathRoot_"),
                      !child.name.hasPrefix("RotationArc_"),
                      child.name != "MotionPath" else { continue }
                child.generateCollisionShapes(recursive: true)
                try? await Task.sleep(nanoseconds: 16_000_000) // ~1 frame @ 60 fps
            }
        }

        // FIX C: Resume the display link now that all state mutations are complete.
        // Only re-start if it was actually playing before load began (rare but safe).
        if wasPlaying {
            vc.displayLink?.isPaused = false
        }
    }

    // MARK: - Clear stale state

    @MainActor
    private func clearSceneState(vc: CanvasViewController) {
        vc.activeMotionPaths.values.forEach  { $0.root.removeFromParent() }
        vc.activeMotionPaths.removeAll()

        vc.activeRotationArcs.values.forEach { $0.root.removeFromParent() }
        vc.activeRotationArcs.removeAll()
        
         // FIX: Clean up preview ARView clones to prevent memory accumulation
         // when switching between scenes (shot preview timer adds clones continuously).
         vc.cleanupPreviewARView()
         
         // System entities to keep throughout the scene lifecycle
         let keep: Set<String> = ["Grid", "EditorCamera", "PathContainer"]
         
         // FIX: Release GPU texture memory by clearing TextureResource references
         // in BackgroundComponents before removing entities from the scene graph.
         // TextureResource GPU memory is freed when the reference is deallocated.
         vc.mainAnchor?.children
             .filter { !keep.contains($0.name) }
             .forEach { entity in
                 if let modelEntity = entity as? ModelEntity,
                    var bgComp = modelEntity.components[CanvasViewController.BackgroundComponent.self] {
                     bgComp.textureResource = nil  // Release GPU texture reference
                     modelEntity.components.set(bgComp)
                     print("🧹 Released texture for background: \(entity.name)")
                 }
             }

         // FIX 2 + FIX 6: Remove recursively bottom-up so nested entities (e.g. camera visuals
         // with child lights) are detached from their parents before the root is removed.
         // RealityKit's removeFromParent() only unlinks the immediate parent link; orphaned
         // sub-trees would linger in memory without explicit recursive removal.
         // "PathContainer" is kept — its PathRoot_ children are already removed above via
         // the activeMotionPaths loop, so the container itself is empty after this point.
         func removeRecursively(_ entity: Entity) {
             for child in entity.children { removeRecursively(child) }
             entity.removeFromParent()
         }
         vc.mainAnchor?.children
             .filter { !keep.contains($0.name) }
             .forEach { removeRecursively($0) }

        vc.timeline.clips.removeAll()
        vc.baseTransforms.removeAll()
        vc.undoStack.removeAll()
        vc.redoStack.removeAll()
        vc.sceneCameras.removeAll()
        vc.sceneCameraItems.removeAll()
        vc.cameraToVisualMap.removeAll()
        vc.cameraCounter   = 0
        vc.selectedEntity  = nil
        vc.backgroundPlane = nil

        // FIX A (editorMode): Always reset to .edit so timeline playback guards
        // don't block animation after the new scene loads. If the previous scene
        // was in .timeline mode, playTimeline() would silently return early.
        vc.editorMode = .edit

        // FIX B: Clear the entity lookup cache so evaluateTimeline() doesn't find
        // stale orphaned entities from the previous session's scene graph.
        vc.timelineEntityCache.removeAll()

        // Clear background image cache — each scene manages its own images.
        vc.backgroundImageCache.removeAll()

        // Stop the camera preview timer so it doesn't fire against a torn-down scene graph.
        vc.stopCameraPreviewUpdates()

        // FIX A: Re-enable the editor camera after clearing scene state.
        // If a scene camera was active when the user left, setActiveCamera() may have
        // called editorCamera.isEnabled = false. Without explicitly re-enabling it here,
        // the subsequent entity restore renders to a black / invisible view.
        vc.editorCamera?.isEnabled = true
        vc.activeCamera = vc.editorCamera

        // Reset the collection view after clearing all camera state
        vc.cameraCollectionView?.reloadData()
    }

    // MARK: - Entity restoration (always on @MainActor)

    @MainActor
    private func restoreEntity(
        record:  EntityRecord,
        vc:      CanvasViewController,
        sceneID: UUID
    ) async {
        guard let anchor = vc.mainAnchor else { return }
        let t = record.transform.transform

         // ── Wall ───────────────────────────────────────────────────────────────
         if record.name.lowercased().contains("wall") || record.modelFileName == "cube" {
             let w = record.wallWidth  ?? 1.5
             let h = record.wallHeight ?? 1.2
             let th = record.wallThickness ?? 0.05
             let e = ModelEntity()
             e.name  = record.name
             if let savedID = record.id, let uuid = UUID(uuidString: savedID) {
                 e.components.set(CanvasViewController.EntityIDComponent(id: uuid))
             }
             
             // Create wall component with saved color, fallback to light gray defaults
             var wallComp = CanvasViewController.WallComponent(width: w, height: h, thickness: th)
             if let r = record.wallColorR, let g = record.wallColorG,
                let b = record.wallColorB, let a = record.wallColorA {
                 wallComp.colorR = r; wallComp.colorG = g
                 wallComp.colorB = b; wallComp.colorA = a
             }
             wallComp.materialConfig = record.materialConfig

             // Use cinematic material if available, else legacy SimpleMaterial
             if let config = record.materialConfig {
                 let simpleMat = CinematicMaterialManager.shared.buildSimpleMaterial(from: config)
                 e.model = ModelComponent(
                     mesh:      MeshResource.generateBox(width: w, height: h, depth: th),
                     materials: [simpleMat]
                 )
                 // Apply full PBR material asynchronously
                 Task { @MainActor in
                     await CinematicMaterialManager.shared.applyMaterial(config, to: e)
                 }
             } else {
                 e.model = ModelComponent(
                     mesh:      MeshResource.generateBox(width: w, height: h, depth: th),
                     materials: [SimpleMaterial(color: wallComp.uiColor, roughness: 0.6, isMetallic: false)]
                 )
             }
             e.components.set(CategoryComponent(toolType: .wall))
             e.components.set(wallComp)
             e.components.set(InputTargetComponent())
             e.transform = t
             anchor.addChild(e)
             return
         }

         // ── Ground ─────────────────────────────────────────────────────────────
         if record.name.lowercased().contains("ground") {
             let w = record.groundWidth ?? 4.0
             let d = record.groundDepth ?? 4.0
             let e = ModelEntity()
             e.name  = record.name
             if let savedID = record.id, let uuid = UUID(uuidString: savedID) {
                 e.components.set(CanvasViewController.EntityIDComponent(id: uuid))
             }
             
             // Create ground component with saved color, fallback to dark gray defaults
             var groundComp = CanvasViewController.GroundComponent(width: w, depth: d)
             if let r = record.groundColorR, let g = record.groundColorG,
                let b = record.groundColorB, let a = record.groundColorA {
                 groundComp.colorR = r; groundComp.colorG = g
                 groundComp.colorB = b; groundComp.colorA = a
             }
             groundComp.materialConfig = record.materialConfig

             // Use cinematic material if available, else legacy SimpleMaterial
             if let config = record.materialConfig {
                 let simpleMat = CinematicMaterialManager.shared.buildSimpleMaterial(from: config)
                 e.model = ModelComponent(
                     mesh:      MeshResource.generatePlane(width: w, depth: d),
                     materials: [simpleMat]
                 )
                 Task { @MainActor in
                     await CinematicMaterialManager.shared.applyMaterial(config, to: e)
                 }
             } else {
                 e.model = ModelComponent(
                     mesh:      MeshResource.generatePlane(width: w, depth: d),
                     materials: [SimpleMaterial(color: groundComp.uiColor, roughness: 1.0, isMetallic: false)]
                 )
             }
             e.components.set(CategoryComponent(toolType: .wall))
             e.components.set(groundComp)
             e.components.set(InputTargetComponent())
             e.transform = t
             anchor.addChild(e)
             return
         }

        // ── Scene camera ───────────────────────────────────────────────────────
        //
        // NOTE: cameraCollectionView.reloadData() is intentionally omitted here.
        // It is called once in load() Phase 5, after ALL entities (including all cameras)
        // have been added. Calling it here inside a concurrent TaskGroup would fire
        // before sibling camera tasks finish, producing an incomplete camera sidebar.
        if record.name.lowercased().contains("scenecamera") {
            let root  = Entity()
            
            // Extract or generate UUID for this camera
            let cameraID: UUID
            if let savedID = record.id, let uuid = UUID(uuidString: savedID) {
                cameraID = uuid
                root.components.set(CanvasViewController.EntityIDComponent(id: uuid))
            } else {
                cameraID = UUID()
                root.components.set(CanvasViewController.EntityIDComponent(id: cameraID))
            }

            // Recover the human-readable display number from the saved entity name.
            // Format is "SceneCamera_<counter>_<UUID>" — part[1] is the counter.
            // Fall back to incrementing vc.cameraCounter (covers malformed or legacy names).
            let displayNumber: Int = {
                let parts = record.name.split(separator: "_")
                if parts.count >= 2, let n = Int(parts[1]) { return n }
                vc.cameraCounter += 1
                return vc.cameraCounter
            }()
            let displayName = "Camera \(displayNumber)"

            // Always rebuild the root name in canonical format using the recovered number.
            root.name = "SceneCamera_\(displayNumber)_\(cameraID.uuidString)"

             root.components.set(CategoryComponent(toolType: .camera))

              // Restore the camera visual model name. Default to "cam1" for
              // legacy saves that didn't persist the model name.
              let cameraModelName = record.cameraModelName ?? "cam1"
              root.components.set(CanvasViewController.CameraVisualComponent(
                  modelName: cameraModelName,
                  displayName: displayName
              ))
              print("📷 Restoring camera '\(displayName)' with model: \(cameraModelName)")

              let cam = PerspectiveCamera()
              cam.name = "PerspCam_\(cameraID.uuidString)"
              cam.isEnabled = false
              cam.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0])
              root.addChild(cam)
              root.transform = t
              anchor.addChild(root)

              // Load the correct visual model asset (same one used at creation time)
              vc.loadCameraVisualModel(cameraModelName, onto: root, camera: cam)

              vc.sceneCameras.append(cam)
              vc.cameraToVisualMap[cam] = root
             vc.sceneCameraItems.append(
                 CanvasViewController.SceneCameraItem(
                     id:          cameraID,
                     camera:      cam,
                     cameraRoot:  root,
                     displayName: displayName
                 )
             )
             // Do NOT call vc.cameraCollectionView?.reloadData() here — see Phase 5 in load().
             return
        }

        // ── Background ─────────────────────────────────────────────────────────
        //
        // Full restore pipeline:
        //   1. Read backgroundImagePath from the record (the saved JPEG filename).
        //   2. Load the JPEG from disk into a UIImage.
        //   3. Store the loaded UIImage immediately in vc.backgroundImageCache so that
        //      save() can always find it regardless of whether step 4 succeeds.
        //   4. Convert to a guaranteed-sRGB CGImage via sRGBCGImage().
        //   5. Await TextureResource(image:options:) — this uploads the texture to the GPU.
        //   6. Apply it to an UnlitMaterial on the restored ModelEntity.
        //   7. Store the UIImage back into BackgroundComponent.cachedImage.
        //
        if record.isBackground
            || record.name.lowercased().hasPrefix("background")
            || record.modelFileName.lowercased().hasPrefix("background") {
            let w = record.bgWidth  ?? 2.0
            let h = record.bgHeight ?? 1.5

            var material       = UnlitMaterial()
            var restoredImage: UIImage?
            var textureResource: TextureResource?  // FIX: Track texture for cleanup

            // Check backgroundImagePath from the JSON record first,
            // then fall back to backgroundImageCache (populated by a previous session's
            // applyBackgroundImage call — covers the case where an old save had no
            // backgroundImagePath but the VC cache was seeded from a prior load).
             let loadedFromDisk: UIImage? = {
                 if let filename = record.backgroundImagePath {
                     let imgURL = documentsDirectory.appendingPathComponent(filename)
                     print("🔍 Attempting to load background from: \(imgURL.path)")
                     if let image = UIImage(contentsOfFile: imgURL.path) {
                         print("✅ Successfully loaded background image from disk: \(filename)")
                         return image
                     } else {
                         print("❌ Failed to load background image from disk: \(filename)")
                         print("   File exists: \(FileManager.default.fileExists(atPath: imgURL.path))")
                         return nil
                     }
                 }
                 return nil
             }()

            // Fall back to VC-level cache for entities whose JPEG path was never saved
            // (pre-fix scenes) but whose image is still in memory from this session.
            let sourceImage = loadedFromDisk ?? vc.backgroundImageCache[record.name]

            if let image = sourceImage {
                // Store in VC cache immediately — this survives a texture upload failure
                // so that save() can still extract the JPEG data on the next save.
                vc.backgroundImageCache[record.name] = image

                 do {
                     // sRGBCGImage() always re-renders through a Device-RGB context —
                     // this ensures P3/wide-gamut images from Photos or camera roll are
                     // safe to pass to TextureResource (which rejects non-sRGB data).
                     print("🔄 Converting image to sRGB and creating texture for '\(record.name)'...")
                     let safeCG = image.sRGBCGImage()
                     let texture = try await TextureResource(
                         image:   safeCG,
                         options: .init(semantic: .color)
                     )
                     material.color.texture = .init(texture)
                     restoredImage = image
                     textureResource = texture  // FIX: Store reference for cleanup
                     print("✅ Background texture restored: \(record.name)")
                } catch {
                    // Texture upload failed — show a magenta placeholder so the user
                    // can see the entity exists and try again.
                    // The UIImage is still in backgroundImageCache so the next save()
                    // will re-write the JPEG and next reload will retry the upload.
                    material.color.tint = UIColor(red: 1.0, green: 0.0, blue: 1.0, alpha: 0.8)
                    print("❌ Background texture upload failed for '\(record.name)': \(error)")
                }
            } else if record.backgroundImagePath != nil {
                // Path was recorded but the JPEG file is missing from disk.
                material.color.tint = UIColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 0.8)
                print("❌ Background JPEG missing on disk for '\(record.name)'")
            } else {
                // No image path and no cached image — geometry-only restore.
                // This happens for old saves created before the image pipeline existed.
                print("ℹ️ No backgroundImagePath for '\(record.name)' — restoring geometry only.")
            }

            let e = ModelEntity(
                mesh:      MeshResource.generateBox(width: w, height: h, depth: 0.05),
                materials: [material]
            )
            e.name = record.name
            if let savedID = record.id, let uuid = UUID(uuidString: savedID) {
                e.components.set(CanvasViewController.EntityIDComponent(id: uuid))
            }
            
            // FIX: Store textureResource reference for cleanup when scene is cleared
            e.components.set(CanvasViewController.BackgroundComponent(
                width:       w,
                height:      h,
                cachedImage: restoredImage,      // retained so future save() calls can extract JPEG data
                textureResource: textureResource  // FIX: Track for cleanup
            ))
            e.components.set(CategoryComponent(toolType: .background))
            e.components.set(InputTargetComponent())
            e.generateCollisionShapes(recursive: true)
            e.transform = t
            anchor.addChild(e)
            return
        }

        // ── Regular 3D model ───────────────────────────────────────────────────
        do {
            // FIX: Use scene-scoped LRU cache manager instead of global cache.
            // This allows fast revisits to the same scene while evicting old scenes automatically.
            let entity: Entity
            if let cached = modelCacheManager.getModel(record.modelFileName, for: sceneID) {
                entity = cached.clone(recursive: true)
            } else {
                let loaded = try await Entity(named: record.modelFileName)
                let estimatedSize = estimateEntitySize(loaded)
                modelCacheManager.cacheModel(loaded, record.modelFileName, for: sceneID, estimatedSize: estimatedSize)
                entity = loaded.clone(recursive: true)
            }
            entity.name = record.name
            if let savedID = record.id, let uuid = UUID(uuidString: savedID) {
                entity.components.set(CanvasViewController.EntityIDComponent(id: uuid))
            }
            let toolType = ToolType.allCases.first { $0.title == record.toolType } ?? .prop
            entity.components.set(CategoryComponent(toolType: toolType))
            entity.components.set(InputTargetComponent())

            if record.modelFileName == "Spotlight"           { vc.addRealLightToModel(entity) }
            else if record.modelFileName.contains("LED")     { vc.addLEDPanel(to: entity) }
            else if record.modelFileName.contains("Lantern") { vc.addLantern(to: entity) }

            entity.transform = t
            anchor.addChild(entity)
        } catch {
            print("⚠️ Could not restore '\(record.name)' (\(record.modelFileName)): \(error)")
        }
    }

    // MARK: - Clip restoration

    private func restoreClipsOnly(_ records: [AnimationClipRecord], vc: CanvasViewController) {
        for record in records {
            guard
                let type   = AnimationType(rawValue: record.type),
                let track  = AnimationTrack(rawValue: record.track),
                let easing = EasingType(rawValue: record.easing)
            else { continue }

            let resolvedEntity = resolveEntity(for: record, in: vc)
            let resolvedName = resolvedEntity?.name ?? record.entityName
            let resolvedID: UUID? = {
                if let entityID = record.entityID, let uuid = UUID(uuidString: entityID) { return uuid }
                if let entityID = resolvedEntity?.components[CanvasViewController.EntityIDComponent.self]?.id {
                    return entityID
                }
                return nil
            }()

            var motionPath: BezierMotionPath?
            if let ps  = record.pathStart,
               let pc1 = record.pathControl1,
               let pc2 = record.pathControl2,
               let pe  = record.pathEnd {
                motionPath = BezierMotionPath(
                    start:    ps.simd,
                    control1: pc1.simd,
                    control2: pc2.simd,
                    end:      pe.simd
                )
            }

            let clip = AnimationClip(
                id:         UUID(uuidString: record.id) ?? UUID(),
                entityName: resolvedName,
                entityID:   resolvedID,
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
        }
    }

    private func resolveEntity(for record: AnimationClipRecord, in vc: CanvasViewController) -> Entity? {
        guard let anchor = vc.mainAnchor else { return nil }
        if let entityID = record.entityID, let uuid = UUID(uuidString: entityID) {
            if let found = findEntity(with: uuid, in: anchor) { return found }
        }
        return anchor.findEntity(named: record.entityName)
    }

    private func findEntity(with id: UUID, in root: Entity) -> Entity? {
        if let comp = root.components[CanvasViewController.EntityIDComponent.self], comp.id == id {
            return root
        }
        for child in root.children {
            if let found = findEntity(with: id, in: child) { return found }
        }
        return nil
    }
     
     // MARK: - Cache Management & Diagnostics
     
     /// Retrieves a cached model for the given scene (used by spawnEntity).
     func getCachedModel(_ fileName: String, for sceneID: UUID) -> Entity? {
         return modelCacheManager.getModel(fileName, for: sceneID)
     }
     
     /// Caches a model for the given scene (used by spawnEntity).
     func cacheSpawnedModel(_ entity: Entity, _ fileName: String, for sceneID: UUID) {
         let estimatedSize = estimateEntitySize(entity)
         modelCacheManager.cacheModel(entity, fileName, for: sceneID, estimatedSize: estimatedSize)
     }
     
     /// Evicts a specific scene from the model cache to free memory.
     func evictScene(_ sceneID: UUID) {
         modelCacheManager.evictScene(sceneID)
     }
     
     /// Logs current cache statistics to console.
     func logCacheStats() {
         let stats = modelCacheManager.getStats()
         let current = stats["currentMemory"] as? Int ?? 0
         let max = stats["maxMemory"] as? Int ?? 0
         let percent = stats["percentUsed"] as? String ?? "0"
         let scenes = stats["scenesInCache"] as? Int ?? 0
         let models = stats["totalModels"] as? Int ?? 0
         
         print("====== 📊 CACHE STATISTICS ======")
         print("Memory: \(current / 1024 / 1024)MB / \(max / 1024 / 1024)MB (\(percent)%)")
         print("Scenes: \(scenes), Models: \(models)")
         print("==================================")
     }
    
    // MARK: - resolveModelFileName

    /// Strips the uniquifying suffix from an entity display name so we can
    /// reload the original asset. Works for both space-separated and
    /// underscore-separated suffixes.
    ///
    /// Examples:
    ///   "Woman1_2"      → "Woman1"
    ///   "LED Panel_3"   → "LED Panel"
    ///   "Background_1"  → "Background"
    ///   "Wall_2"        → "Wall"
    ///   "Wall"          → "Wall"
    private func resolveModelFileName(entity: Entity) -> String {
        let name = entity.name
        // Never strip the suffix from camera roots — they don't load from .usdz files.
        // The restore path handles them by name-prefix matching, not by loading a model.
        if name.lowercased().contains("scenecamera") { return name }
        // For regular props, strip trailing instance suffix (_2, _3, etc.)
        // so we can reload the base .usdz from the app bundle.
        if let range = name.range(of: #"_\d+$"#, options: .regularExpression) {
            return String(name[name.startIndex..<range.lowerBound])
        }
        return name
    }
}

// MARK: - UIImage → sRGB CGImage
// NOTE: sRGBCGImage() is defined as an internal extension in
// CanvasViewController+Spawning.swift and is available throughout the module.
// It is referenced below inside restoreEntity() for background texture loading.
