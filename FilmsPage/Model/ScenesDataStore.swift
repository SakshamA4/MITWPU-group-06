
//  ScenesDataStore.swift
//  FilmsPage
//
//  Created by SDC-USER on 17/12/25.


import Foundation

class ScenesDataStore {
    
    static let shared = ScenesDataStore()
    static let scenesUpdatedNotification = Notification.Name("scenesDataStoreUpdated")
    
    private let isPersistenceEnabled = false
    
    private let kRecentScenesKey = "recentScenes"
    
    private init() {
        if isPersistenceEnabled {
            loadData()
        }
    }

    private var recentScenes: [ScenesModel] = []
    
    private let templates: [ScenesModel] = [
        ScenesModel(name: "Outdoor Scene", image: "outdoor"),
        ScenesModel(name: "House Scene", image: "scene1"),
        ScenesModel(name: "Scene 3", image: "Image"),
        ScenesModel(name: "Scene 4", image: "Image")
    ]
    
    // MARK: - Getters
    var currentRecentScenes: [ScenesModel] {
        return recentScenes
    }
    
    var currentTemplates: [ScenesModel] {
        return templates
    }

    // MARK: - Mutations
    func addToRecent(scene: ScenesModel) {
        // Remove duplicate if exists (move to top)
        recentScenes.removeAll { $0.id == scene.id }
        
        // Insert at the beginning
        recentScenes.insert(scene, at: 0)

        // Limit size (optional, keeps UI clean)
        if recentScenes.count > 10 {
            recentScenes.removeLast()
        }

        if isPersistenceEnabled {
            saveData()
        }
        
        // Post notification for UI updates
        NotificationCenter.default.post(name: ScenesDataStore.scenesUpdatedNotification, object: nil)
    }
    
    // MARK: - Persistence (Private)
    private func loadData() {
        guard let data = UserDefaults.standard.data(forKey: kRecentScenesKey),
              let decoded = try? JSONDecoder().decode([ScenesModel].self, from: data) else { return }
        recentScenes = decoded
    }

    private func saveData() {
        if let encoded = try? JSONEncoder().encode(recentScenes) {
            UserDefaults.standard.set(encoded, forKey: kRecentScenesKey)
        }
    }
}
