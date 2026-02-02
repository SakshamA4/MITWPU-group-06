//
//  FilmCharacterService.swift
//  FilmsPage
//
//  Created by SDC-USER on 02/02/26.
//

import Foundation

final class FilmCharacterService {

    static let shared = FilmCharacterService()
    private let storageKey = StorageKeys.filmCharacters
    private var isInitialized = false

    // MARK: - Film Characters (Per Film)
    private var filmCharacters: [FilmCharacter] = [] {
        didSet {
            guard isInitialized else { return }
            save()
            NotificationCenter.default.post(
                name: NSNotification.Name(NotificationNames.filmCharactersUpdated),
                object: nil
            )
        }
    }
    
    enum StorageKeys {
        static let characters = "characters_library"
        static let filmCharacters = "film_characters"
    }
    enum NotificationNames {
        static let charactersUpdated = "charactersUpdated"
        static let filmCharactersUpdated = "filmCharactersUpdated"
    }


    private init() {
        load()
        isInitialized = true
    }

    // MARK: - Public API

    /// Get all characters for a specific film
    func getCharacters(forFilmId filmId: UUID) -> [FilmCharacter] {
        filmCharacters.filter { $0.filmId == filmId }
    }

    /// Get a specific film character
    func getFilmCharacter(by id: UUID) -> FilmCharacter? {
        filmCharacters.first { $0.id == id }
    }
    
    func getCharacterCount(forFilmId filmId: UUID) -> Int {
        getCharacters(forFilmId: filmId).count
    }

    /// Add a character template to a film
    func addCharacter(
        template: CharacterItem,
        filmId: UUID,
        nameOverride: String? = nil
    ) {
        let filmCharacter = FilmCharacter(
            id: UUID(),
            filmId: filmId,
            characterTemplateId: template.id,
            nameOverride: nameOverride ?? template.name,
            heightInCms: nil,
            selectedPoseId: template.pose.first?.id
        )

        filmCharacters.append(filmCharacter)
    }

    /// Update a film character
    func updateCharacter(_ character: FilmCharacter) {
        guard let index = filmCharacters.firstIndex(where: { $0.id == character.id }) else {
            return
        }
        filmCharacters[index] = character
    }

    /// Remove a character from a film
    func deleteCharacter(by id: UUID) {
        filmCharacters.removeAll { $0.id == id }
    }

    /// Remove all characters belonging to a film
    func deleteCharacters(forFilmId filmId: UUID) {
        filmCharacters.removeAll { $0.filmId == filmId }
    }

    // MARK: - Helpers (Very Useful)

    /// Resolve the library character for a film character
    func getTemplate(for filmCharacter: FilmCharacter) -> CharacterItem? {
        CharacterService.shared.getCharacter(by: filmCharacter.characterTemplateId)
    }

    /// Resolve selected pose model filename
    func getSelectedPoseModelName(for filmCharacter: FilmCharacter) -> String? {
        guard
            let template = getTemplate(for: filmCharacter),
            let poseId = filmCharacter.selectedPoseId
        else { return nil }

        return template.pose.first { $0.id == poseId }?.modelFilename
    }

    // MARK: - Persistence

    private func save() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(filmCharacters)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("❌ Failed to save film characters:", error)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            filmCharacters = []
            return
        }

        do {
            let decoder = JSONDecoder()
            filmCharacters = try decoder.decode([FilmCharacter].self, from: data)
        } catch {
            print("❌ Failed to load film characters:", error)
            filmCharacters = []
        }
    }
}
