//
//  CharacterService.swift
//  FilmsPage
//
//  Created by SDC-USER on 17/12/25.
//

import Foundation

class CharacterService {
    static let shared = CharacterService()
    private let storageKey = StorageKeys.characters
    private var isInitialized = false

    private var characters: [CharacterItem] = [] {
        didSet {
            guard isInitialized else { return }
            save()
            NotificationCenter.default.post(name: NSNotification.Name(NotificationNames.charactersUpdated), object: nil)
        }
    }

    private init() {
        load()
        isInitialized = true
    }

    // MARK: - CRUD Operations
    
    func getCharacters() -> [CharacterItem] {
        return characters
    }
    
    func getCharacters(forFilmId filmId: UUID) -> [CharacterItem] {
        return characters.filter { $0.filmId == filmId }
    }
    
    func getCharacter(by id: UUID) -> CharacterItem? {
        return characters.first { $0.id == id }
    }
    
    func addCharacter(_ character: CharacterItem) {
        characters.append(character)
    }
    
    func updateCharacter(_ character: CharacterItem) {
        if let charId = character.id,
           let index = characters.firstIndex(where: { $0.id == charId }) {
            characters[index] = character
        }
    }
    
    func deleteCharacter(at index: Int) {
        guard index < characters.count else { return }
        characters.remove(at: index)
    }
    
    func deleteCharacter(by id: UUID) {
        characters.removeAll { $0.id == id }
    }
    
    func deleteCharacters(forFilmId filmId: UUID) {
        characters.removeAll { $0.filmId == filmId }
    }
    
    func getCharacterCount(forFilmId filmId: UUID) -> Int {
        return characters.filter { $0.filmId == filmId }.count
    }
    
    func getPoses(forCharacterId characterId: UUID) -> [CharacterPoseItem] {
        return characters.first { $0.id == characterId }?.pose ?? []
    }

    // MARK: - Persistence
    
    private func save() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(characters)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save characters: \(error)")
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            do {
                let decoder = JSONDecoder()
                characters = try decoder.decode([CharacterItem].self, from: data)
            } catch {
                print("Failed to load characters: \(error)")
            }
        }
        
        // Initialize with default template characters (no filmId - templates)
        if characters.isEmpty {
            characters = [
                CharacterItem(
                    id: UUID(),
                    name: "Character 1",
                    imageName: "Woman 1",
                    filmId: nil,
                    pose: [
                        CharacterPoseItem(id: UUID(), name: "Fighting Pose", imageName: "fighting pose"),
                        CharacterPoseItem(id: UUID(), name: "Talking", imageName: "Talking Woman"),
                        CharacterPoseItem(id: UUID(), name: "Sitting", imageName: "Sitting Woman"),
                        CharacterPoseItem(id: UUID(), name: "Sleeping", imageName: "Sleeping"),
                        CharacterPoseItem(id: UUID(), name: "Falling", imageName: "Falling"),
                        CharacterPoseItem(id: UUID(), name: "Buffering", imageName: "Buffering")
                    ]
                ),
                CharacterItem(
                    id: UUID(),
                    name: "Character 2",
                    imageName: "Man in a suit",
                    filmId: nil,
                    pose: [
                        CharacterPoseItem(id: UUID(), name: "Arms stretched", imageName: "Arms stretched"),
                        CharacterPoseItem(id: UUID(), name: "Talking", imageName: "Talking Man"),
                        CharacterPoseItem(id: UUID(), name: "Sitting", imageName: "Sitting Man"),
                        CharacterPoseItem(id: UUID(), name: "Laying Down", imageName: "Lying down"),
                        CharacterPoseItem(id: UUID(), name: "Waving", imageName: "Waving Man"),
                        CharacterPoseItem(id: UUID(), name: "Joining Hands", imageName: "Joining hands")
                    ]
                ),
                CharacterItem(
                    id: UUID(),
                    name: "Character 3",
                    imageName: "Woman 2",
                    filmId: nil,
                    pose: [
                        CharacterPoseItem(id: UUID(), name: "Arms stretched", imageName: "Arms stretched"),
                        CharacterPoseItem(id: UUID(), name: "Talking", imageName: "Talking Woman"),
                        CharacterPoseItem(id: UUID(), name: "Sitting", imageName: "Sitting Woman"),
                        CharacterPoseItem(id: UUID(), name: "Laying Down", imageName: "Lying down"),
                        CharacterPoseItem(id: UUID(), name: "Waving", imageName: "Waving Woman"),
                        CharacterPoseItem(id: UUID(), name: "Joining Hands", imageName: "Joining hands")
                    ]
                ),
                CharacterItem(
                    id: UUID(),
                    name: "Character 4",
                    imageName: "Woman 3",
                    filmId: nil,
                    pose: [
                        CharacterPoseItem(id: UUID(), name: "Fighting Pose", imageName: "fighting pose"),
                        CharacterPoseItem(id: UUID(), name: "Talking", imageName: "Talking Woman"),
                        CharacterPoseItem(id: UUID(), name: "Sitting", imageName: "Sitting Woman"),
                        CharacterPoseItem(id: UUID(), name: "Sleeping", imageName: "Sleeping"),
                        CharacterPoseItem(id: UUID(), name: "Falling", imageName: "Falling"),
                        CharacterPoseItem(id: UUID(), name: "Buffering", imageName: "Buffering")
                    ]
                ),
                CharacterItem(
                    id: UUID(),
                    name: "Character 5",
                    imageName: "Asian man",
                    filmId: nil,
                    pose: [
                        CharacterPoseItem(id: UUID(), name: "Arms stretched", imageName: "Arms stretched"),
                        CharacterPoseItem(id: UUID(), name: "Talking", imageName: "Talking Man"),
                        CharacterPoseItem(id: UUID(), name: "Sitting", imageName: "Sitting Man"),
                        CharacterPoseItem(id: UUID(), name: "Laying Down", imageName: "Lying down"),
                        CharacterPoseItem(id: UUID(), name: "Waving", imageName: "Waving Man"),
                        CharacterPoseItem(id: UUID(), name: "Joining Hands", imageName: "Joining hands")
                    ]
                ),
                CharacterItem(
                    id: UUID(),
                    name: "Character 6",
                    imageName: "Man in a jersey",
                    filmId: nil,
                    pose: [
                        CharacterPoseItem(id: UUID(), name: "Arms stretched", imageName: "Arms stretched"),
                        CharacterPoseItem(id: UUID(), name: "Talking", imageName: "Talking Man"),
                        CharacterPoseItem(id: UUID(), name: "Sitting", imageName: "Sitting Man"),
                        CharacterPoseItem(id: UUID(), name: "Laying Down", imageName: "Lying down"),
                        CharacterPoseItem(id: UUID(), name: "Waving", imageName: "Waving Man"),
                        CharacterPoseItem(id: UUID(), name: "Joining Hands", imageName: "Joining hands")
                    ]
                )
            ]
        }
    }
}
