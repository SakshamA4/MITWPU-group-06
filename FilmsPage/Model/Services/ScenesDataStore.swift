
//  ScenesDataStore.swift
//  FilmsPage
//
//  Created by SDC-USER on 17/12/25.


import Foundation

class ScenesDataStore {
    
    static let shared = ScenesDataStore()
    static let scenesUpdatedNotification = Notification.Name("scenesDataStoreUpdated")
    
    private let isPersistenceEnabled = true
    
    private let kRecentScenesKey = "recentScenes"
    
    private init() {
        if isPersistenceEnabled {
            loadData()
        }
    }

    private var recentScenes: [ScenesModel] = []
    private static let outdoorID = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!
    private static let houseID   = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440001")!
    private static let scene3ID  = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440002")!
    private static let scene4ID  = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440003")!
    
    
    private let templates: [ScenesModel] = [
        ScenesModel(id: outdoorID,name: "Outdoor Scene", image: "outdoor"),
        ScenesModel(id: houseID,name: "House Scene", image: "scene1"),
        ScenesModel(id: scene3ID,name: "Scene 3", image: "Image"),
        ScenesModel(id: scene4ID,name: "Scene 4", image: "Image")
    ]
    
    //Getters
    var currentRecentScenes: [ScenesModel] {
        return recentScenes
    }
    
    var currentTemplates: [ScenesModel] {
        let savedNotes = UserDefaults.standard.dictionary(forKey: kTemplateNotesKey) as? [String: String] ?? [:]
            
            return templates.map { template in
                var t = template
                // 📍 THE FIX: Attach the saved note to the template model
                if let note = savedNotes[template.id.uuidString] {
                    t.notes = note
                }
                return t
            }
    }

    private let kTemplateNotesKey = "templateNotes"

    // 📍 Saves notes for templates by their unique ID without moving them to Recents
    func saveTemplateNote(id: UUID, notes: String) {
        var allNotes = UserDefaults.standard.dictionary(forKey: kTemplateNotesKey) as? [String: String] ?? [:]
        allNotes[id.uuidString] = notes
        UserDefaults.standard.set(allNotes, forKey: kTemplateNotesKey)
    }
    
    
    func addToRecent(scene: ScenesModel) {
        // 1. Template check remains the same
        let isTemplate = templates.contains { $0.name == scene.name }
        if isTemplate { return }

        // 📍 THE FIX: Remove by ID AND Name to ensure zero duplication
        recentScenes.removeAll { $0.id == scene.id || $0.name == scene.name }
        
        // 2. Insert at index 0 (Top of list)
        recentScenes.insert(scene, at: 0)

        if recentScenes.count > 10 {
            recentScenes.removeLast()
        }

        saveData() // Persist
        NotificationCenter.default.post(name: ScenesDataStore.scenesUpdatedNotification, object: nil)
    }
    
    // Add these to ScenesDataStore.swift
    func deleteScene(by id: UUID) {
        // 1. Remove from the local array
        recentScenes.removeAll { $0.id == id }
        
        // 2. Save the updated list to UserDefaults
        saveData()
        
        // 3. Post the notification that HomeViewController is listening for
        NotificationCenter.default.post(name: ScenesDataStore.scenesUpdatedNotification, object: nil)
    }

    func updateScene(_ updatedModel: ScenesModel) {
        // 1. Find the scene in the recents list
        if let index = recentScenes.firstIndex(where: { $0.id == updatedModel.id }) {
            // 2. Replace it with the new version (new name/notes)
            recentScenes[index] = updatedModel
            
            // 3. Save and notify
            saveData()
            NotificationCenter.default.post(name: ScenesDataStore.scenesUpdatedNotification, object: nil)
        }
    }
    
    
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
