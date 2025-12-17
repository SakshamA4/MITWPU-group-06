//
//  DataServiceCoordinator.swift
//  FilmsPage
//
//  Created by SDC-USER on 17/12/25.
//

import Foundation

/// Coordinator class that provides backward-compatible API and coordinates between services
/// Use this for operations that span multiple services
class DataServiceCoordinator {
    static let shared = DataServiceCoordinator()
    
    // Service references for convenience
    let filmService = FilmService.shared
    let sequenceService = SequenceService.shared
    let sceneService = SceneService.shared
    let characterService = CharacterService.shared
    let propService = PropService.shared
    
    private init() {
        // Listen for changes and update counts
        setupObservers()
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateFilmCounts),
            name: NSNotification.Name(NotificationNames.sequencesUpdated),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateFilmCounts),
            name: NSNotification.Name(NotificationNames.scenesUpdated),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateFilmCounts),
            name: NSNotification.Name(NotificationNames.charactersUpdated),
            object: nil
        )
    }
    
    // MARK: - Update Film Counts
    
    @objc func updateFilmCounts() {
        filmService.updateFilmCounts(
            sequenceCountForFilm: { filmId in
                self.sequenceService.getSequenceCount(forFilmId: filmId)
            },
            characterCountForFilm: { filmId in
                self.characterService.getCharacterCount(forFilmId: filmId)
            },
            sceneCountForFilm: { filmId in
                let sequenceIds = self.sequenceService.getSequenceIds(forFilmId: filmId)
                return self.sceneService.getSceneCount(forSequenceIds: sequenceIds)
            }
        )
    }
    
    // MARK: - Backward Compatible API (Matches old DataStore methods)
    
    // Films
    func getOtherFilms() -> [Film] {
        return filmService.getFilms()
    }
    
    func getFavFilms() -> Film? {
        return filmService.getFavFilm()
    }
    
    func createNewFilm(newFilm: Film) {
        filmService.addFilm(newFilm)
    }
    
    // Sequences
    func getSequence() -> [Sequence] {
        return sequenceService.getSequences()
    }
    
    func getSequenceByFilmID(filmId: UUID) -> [Sequence] {
        return sequenceService.getSequences(forFilmId: filmId)
    }
    
    func createNewSequence(newSequence: Sequence) {
        sequenceService.addSequence(newSequence)
    }
    
    // Scenes
    func getScenes(sequenceId: UUID) -> [Scene] {
        return sceneService.getScenes(forSequenceId: sequenceId)
    }
    
    func createNewScene(newScene: Scene) {
        sceneService.addScene(newScene)
    }
    
    // Characters
    func getCharacters() -> [CharacterItem] {
        return characterService.getCharacters()
    }
    
    func getCharactersByFilmId(filmId: UUID) -> [CharacterItem] {
        return characterService.getCharacters(forFilmId: filmId)
    }
    
    func addCharacter(newCharacter: CharacterItem) {
        characterService.addCharacter(newCharacter)
    }
    
    func getPoses(forCharacter characterId: UUID) -> [CharacterPoseItem]? {
        let poses = characterService.getPoses(forCharacterId: characterId)
        return poses.isEmpty ? nil : poses
    }
    
    // Props
    func getProps() -> [PropItem] {
        return propService.getProps()
    }
    
    func getPropsbyFilmId(filmId: UUID) -> [PropItem] {
        return propService.getProps(forFilmId: filmId)
    }
    
    func attachPropToFilm(propId: UUID, filmId: UUID) {
        propService.attachPropToFilm(propId: propId, filmId: filmId)
    }
    
    // MARK: - Legacy Support
    
    /// Call this once at app startup if migrating from old DataStore
    func loadData() {
        // Services load automatically on init, this is for backward compatibility
        updateFilmCounts()
    }
    
    func saveData() {
        // Services save automatically on changes, this is for backward compatibility
    }
}

// MARK: - Backward Compatibility Alias
/// This typealias allows existing code using DataStore.shared to work with minimal changes
/// After migration, gradually update ViewControllers to use individual services directly
typealias DataStore = DataServiceCoordinator
