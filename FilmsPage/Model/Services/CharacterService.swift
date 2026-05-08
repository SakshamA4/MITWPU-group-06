//
//  CharacterService.swift
//  FilmsPage
//
//  Created by SDC-USER on 17/12/25.
//
import Foundation

final class CharacterService {

    static let shared = CharacterService()
    private let storageKey = StorageKeys.characters
    private var isInitialized = false

    // MARK: - Library Characters ONLY
    private var characters: [CharacterItem] = [] {
        didSet {
            guard isInitialized else { return }
            save()
            NotificationCenter.default.post(
                name: NSNotification.Name(NotificationNames.charactersUpdated),
                object: nil
            )
        }
    }

    private init() {
        load()
        isInitialized = true
    }

    // MARK: - Public API

    /// All characters available in the global library
    func getCharacters() -> [CharacterItem] {
        characters
    }

    /// Fetch a single library character
    func getCharacter(by id: UUID) -> CharacterItem? {
        characters.first { $0.id == id }
    }

    /// Add a new character to the LIBRARY (not films)
    func addCharacter(_ character: CharacterItem) {
        characters.append(character)
    }

    /// Update a library character
    func updateCharacter(_ character: CharacterItem) {
        guard let index = characters.firstIndex(where: { $0.id == character.id }) else {
            return
        }
        characters[index] = character
    }

    /// Delete a character from the LIBRARY
    func deleteCharacter(by id: UUID) {
        characters.removeAll { $0.id == id }
    }

    /// Convenience: get poses for a character template
    func getPoses(forCharacterId characterId: UUID) -> [CharacterPoseItem] {
        characters.first { $0.id == characterId }?.pose ?? []
    }

    // MARK: - Persistence

    private func save() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(characters)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("❌ Failed to save character library:", error)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            do {
                let decoder = JSONDecoder()
                characters = try decoder.decode([CharacterItem].self, from: data)
                return
            } catch {
                print("❌ Failed to load character library:", error)
            }
        }

        // MARK: - Default Library Characters
        characters = [
            CharacterItem(
                id: UUID(),
                name: "Woman",
                imageName: "woman1_img",
                pose: [
                    CharacterPoseItem(id: UUID(), name: "Standing", imageName: "woman1_img", modelFilename: "woman_walks"),
                    CharacterPoseItem(id: UUID(), name: "Sitting", imageName: "Woman1Sit_img", modelFilename: "Woman1Sit"),
                    CharacterPoseItem(id: UUID(), name: "Lying", imageName: "Woman1MegLay_img", modelFilename: "Woman1MegLay"),
                    CharacterPoseItem(id: UUID(), name: "On a Call", imageName: "Woman1MegOnCall_img", modelFilename: "Woman1MegOnCall")
                ]
            ),
            CharacterItem(
                id: UUID(),
                name: "Man",
                imageName: "man1_img",
                pose: [
                    CharacterPoseItem(id: UUID(), name: "Standing", imageName: "man1_img", modelFilename: "LewisR"),
                    CharacterPoseItem(id: UUID(), name: "Lying", imageName: "Man1LyingIdle_img", modelFilename: "Man1LyingIdle"),
                    CharacterPoseItem(id: UUID(), name: "Sitting", imageName: "Man1SittingIdle_img", modelFilename: "Man1SittingIdle"),
                    CharacterPoseItem(id: UUID(), name: "On a Call", imageName: "Man1OnCall_img", modelFilename: "Man1OnCall")
                ]
            )
        ]
    }
}
