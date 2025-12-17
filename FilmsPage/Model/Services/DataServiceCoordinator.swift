//
//  DataServiceCoordinator.swift
//  FilmsPage
//
//  Created by SDC-USER on 17/12/25.
//

import Foundation

/// Coordinator class that coordinates between services
/// Use this for operations that span multiple services (e.g., updating film counts)
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
}
