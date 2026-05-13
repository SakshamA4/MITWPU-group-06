
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
    
    
    private var templates: [ScenesModel] = [
        ScenesModel(id: outdoorID,name: "Outdoor Scene", image: "outdoor"),
        ScenesModel(id: houseID,name: "House Scene", image: "scene1"),
        ScenesModel(id: scene3ID,name: "Diner Scene", image: "diner"),
        ScenesModel(id: scene4ID,name: "Park Scene", image: "park")
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
        // Template check: templates must never appear in the recents list.
        // Check by ID (stable) — not by name, since a user-created scene may
        // happen to share a template name.
        let isTemplate = templates.contains { $0.id == scene.id }
        if isTemplate { return }

        // Deduplicate by ID only — two scenes with the same name are distinct.
        recentScenes.removeAll { $0.id == scene.id }

        // Insert at top of list.
        recentScenes.insert(scene, at: 0)

        if recentScenes.count > 10 {
            recentScenes.removeLast()
        }

        saveData() // Persist
        NotificationCenter.default.post(name: ScenesDataStore.scenesUpdatedNotification, object: nil)
    }
    
    func deleteScene(by id: UUID) {
        recentScenes.removeAll { $0.id == id }
        templates.removeAll { $0.id == id }  // ← add this line
        saveData()
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

    // MARK: - Sequence Management

    /// Returns all recent scenes grouped by sequenceID (non-nil only),
    /// preserving the list order within each group.
    func scenesGroupedBySequence() -> [(sequenceID: UUID, sequenceName: String, scenes: [ScenesModel])] {
        var groups: [UUID: (name: String, scenes: [ScenesModel])] = [:]
        var order: [UUID] = []

        for scene in recentScenes {
            guard let seqID = scene.sequenceID,
                  let seqName = scene.sequenceName else { continue }
            if groups[seqID] == nil {
                groups[seqID] = (name: seqName, scenes: [])
                order.append(seqID)
            }
            groups[seqID]?.scenes.append(scene)
        }

        return order.compactMap { id in
            guard let group = groups[id] else { return nil }
            return (sequenceID: id, sequenceName: group.name, scenes: group.scenes)
        }
    }

    /// Assigns a scene to a sequence. Creates a new sequenceID if needed.
    func assignToSequence(sceneID: UUID, sequenceID: UUID, sequenceName: String) {
        guard let index = recentScenes.firstIndex(where: { $0.id == sceneID }) else { return }
        recentScenes[index].sequenceID = sequenceID
        recentScenes[index].sequenceName = sequenceName
        saveData()
        NotificationCenter.default.post(name: ScenesDataStore.scenesUpdatedNotification, object: nil)
    }

    /// Removes a scene from its sequence.
    func removeFromSequence(sceneID: UUID) {
        guard let index = recentScenes.firstIndex(where: { $0.id == sceneID }) else { return }
        recentScenes[index].sequenceID = nil
        recentScenes[index].sequenceName = nil
        saveData()
        NotificationCenter.default.post(name: ScenesDataStore.scenesUpdatedNotification, object: nil)
    }
}
