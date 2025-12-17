//
//  SceneService.swift
//  FilmsPage
//
//  Created by SDC-USER on 17/12/25.
//

import Foundation

class SceneService {
    static let shared = SceneService()
    private let storageKey = StorageKeys.scenes
    private var isInitialized = false

    private var scenes: [Scene] = [] {
        didSet {
            guard isInitialized else { return }
            save()
            NotificationCenter.default.post(name: NSNotification.Name(NotificationNames.scenesUpdated), object: nil)
        }
    }

    private init() {
        load()
        isInitialized = true
    }

    // MARK: - CRUD Operations
    
    func getScenes() -> [Scene] {
        return scenes
    }
    
    func getScenes(forSequenceId sequenceId: UUID) -> [Scene] {
        return scenes.filter { $0.SequenceId == sequenceId }
    }
    
    func getScene(by id: UUID) -> Scene? {
        return scenes.first { $0.id == id }
    }
    
    func addScene(_ scene: Scene) {
        scenes.append(scene)
    }
    
    func updateScene(_ scene: Scene) {
        if let index = scenes.firstIndex(where: { $0.id == scene.id }) {
            scenes[index] = scene
        }
    }
    
    func deleteScene(at index: Int) {
        guard index < scenes.count else { return }
        scenes.remove(at: index)
    }
    
    func deleteScene(by id: UUID) {
        scenes.removeAll { $0.id == id }
    }
    
    func deleteScenes(forSequenceId sequenceId: UUID) {
        scenes.removeAll { $0.SequenceId == sequenceId }
    }
    
    func getSceneCount(forSequenceIds sequenceIds: [UUID]) -> Int {
        return scenes.filter { sequenceIds.contains($0.SequenceId) }.count
    }

    // MARK: - Persistence
    
    private func save() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(scenes)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save scenes: \(error)")
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            do {
                let decoder = JSONDecoder()
                scenes = try decoder.decode([Scene].self, from: data)
            } catch {
                print("Failed to load scenes: \(error)")
            }
        }
    }
}
