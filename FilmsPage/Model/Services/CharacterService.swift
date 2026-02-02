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
        

        if characters.isEmpty {
            characters = [
                CharacterItem(
                    id: UUID(),
                    name: "Woman",
                    imageName: "woman1_img",
                    filmId: nil,
                    pose: [
                        CharacterPoseItem(id: UUID(), name: "Standing", imageName: "woman1_img", modelFilename: "woman1"),
                        CharacterPoseItem(id: UUID(), name: "Sitting", imageName: "Woman1Sit_img", modelFilename: "Woman1Sit"),
                        CharacterPoseItem(id: UUID(), name: "Lying", imageName: "Woman1MegLay_img", modelFilename: "Woman1MegLay"),
                        CharacterPoseItem(id: UUID(), name: "On a Call", imageName: "Woman1MegOnCall_img", modelFilename: "Woman1MegOnCall")
                    ]
                ),
                CharacterItem(
                    id: UUID(),
                    name: "Man",
                    imageName: "man1_img",
                    filmId: nil,
                    pose: [
                        CharacterPoseItem(id: UUID(), name: "Standing", imageName: "man1_img", modelFilename: "man1"),
                        CharacterPoseItem(id: UUID(), name: "Lying", imageName: "Man1LyingIdle_img", modelFilename: "Man1LyingIdle"),
                        CharacterPoseItem(id: UUID(), name: "Sitting", imageName: "Man1SittingIdle_img", modelFilename: "Man1SittingIdle"),
                        CharacterPoseItem(id: UUID(), name: "On a Call", imageName: "Man1OnCall_img", modelFilename: "Man1OnCall")
                    ]
                )
            ]
        }
    }
}
