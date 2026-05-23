//
//  CinematicScenePersistence.swift
//  FilmsPage
//
//  Persistence layer for cinema camera configurations.
//  Serializes/deserializes all cinema ECS component data
//  to/from the existing scene JSON persistence system.
//

import Foundation
import RealityKit

// MARK: - Persistable Cinema Configuration

/// Complete serializable snapshot of a cinema camera's configuration.
/// Used for scene save/load and undo/redo.
struct CinematicCameraSnapshot: Codable, Hashable {
    var cameraBodyID: String
    var lensFamilyID: String
    var focalLengthMM: Float
    var lookID: String
    var lookIntensity: Float
    var aspectRatioPreset: CinemaAspectRatioPreset
    var motionStyle: CameraMotionStyle
    var motionIntensity: Float
    var motionActive: Bool
    var frameGuideConfig: FrameGuideConfig
    var breathingMode: CineBreathingMode
    var customLUTFileID: String?
    
    /// Timeline keyframe data
    var timelineTracks: [CinematicTimelineTrack]
}

// MARK: - Snapshot Builder

extension CinematicCameraSnapshot {
    
    /// Creates a snapshot from a camera entity's current ECS components.
    static func from(entity: Entity) -> CinematicCameraSnapshot? {
        guard entity.components[CinematicCameraTag.self] != nil else { return nil }
        
        let sensor = entity.components[CineSensorComponent.self]
        let lens = entity.components[CineLensComponent.self]
        let look = entity.components[CineLookComponent.self]
        let aspect = entity.components[CineAspectRatioComponent.self]
        let motion = entity.components[CineMotionComponent.self]
        let guide = entity.components[CineFrameGuideComponent.self]
        
        return CinematicCameraSnapshot(
            cameraBodyID: sensor?.cameraBodyID ?? CinemaCameraDatabase.defaultCamera.id,
            lensFamilyID: lens?.lensFamilyID ?? CinemaLensDatabase.defaultFamily.id,
            focalLengthMM: lens?.selectedFocalLengthMM ?? 50,
            lookID: look?.lookID ?? CinematicLookDatabase.defaultLook.id,
            lookIntensity: look?.intensity ?? 1.0,
            aspectRatioPreset: aspect?.preset ?? .hdWidescreen,
            motionStyle: motion?.motionStyle ?? .tripod,
            motionIntensity: motion?.intensityMultiplier ?? 1.0,
            motionActive: motion?.isActive ?? false,
            frameGuideConfig: guide?.config ?? .clean,
            breathingMode: lens?.breathingMode ?? .cinematic,
            customLUTFileID: look?.customLUTFileID,
            timelineTracks: []
        )
    }
    
    /// Applies this snapshot's values back onto a camera entity's ECS components.
    func apply(to entity: Entity) {
        entity.components.set(CineSensorComponent(cameraBodyID: cameraBodyID))
        entity.components.set(CineLensComponent(
            lensFamilyID: lensFamilyID,
            selectedFocalLengthMM: focalLengthMM,
            breathingMode: breathingMode
        ))
        entity.components.set(CineLookComponent(
            lookID: lookID,
            intensity: lookIntensity,
            customLUTFileID: customLUTFileID
        ))
        entity.components.set(CineAspectRatioComponent(preset: aspectRatioPreset))
        entity.components.set(CineMotionComponent(
            motionStyle: motionStyle,
            isActive: motionActive,
            intensityMultiplier: motionIntensity
        ))
        entity.components.set(CineFrameGuideComponent(config: frameGuideConfig))
        entity.components.set(CinematicCameraTag())
    }
}

// MARK: - Scene-Level Persistence

/// Manages persistence of all cinema cameras in a scene.
final class CinematicScenePersistence {
    
    /// File name for cinema camera data within the scene folder.
    static let fileName = "cinematic_cameras.json"
    
    /// Saves all cinema camera snapshots to disk.
    static func save(snapshots: [String: CinematicCameraSnapshot], sceneURL: URL) {
        let fileURL = sceneURL.appendingPathComponent(fileName)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(snapshots)
            try data.write(to: fileURL, options: .atomic)
            print("🎬 Saved \(snapshots.count) cinema camera(s)")
        } catch {
            print("❌ Cinema save failed: \(error)")
        }
    }
    
    /// Loads cinema camera snapshots from disk.
    static func load(sceneURL: URL) -> [String: CinematicCameraSnapshot] {
        let fileURL = sceneURL.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [:] }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let snapshots = try JSONDecoder().decode([String: CinematicCameraSnapshot].self, from: data)
            print("🎬 Loaded \(snapshots.count) cinema camera(s)")
            return snapshots
        } catch {
            print("❌ Cinema load failed: \(error)")
            return [:]
        }
    }
    
    /// Collects snapshots from all cinema camera entities in the scene.
    static func collectSnapshots(from cameras: [(id: String, entity: Entity)]) -> [String: CinematicCameraSnapshot] {
        var result: [String: CinematicCameraSnapshot] = [:]
        for cam in cameras {
            if let snapshot = CinematicCameraSnapshot.from(entity: cam.entity) {
                result[cam.id] = snapshot
            }
        }
        return result
    }
    
    /// Restores cinema camera components from saved snapshots.
    static func restoreSnapshots(_ snapshots: [String: CinematicCameraSnapshot],
                                  to cameras: [(id: String, entity: Entity)]) {
        for cam in cameras {
            if let snapshot = snapshots[cam.id] {
                snapshot.apply(to: cam.entity)
            }
        }
    }
}
