//
//  Constants.swift
//  FilmsPage
//
//  Created by SDC-USER on 17/12/25.
//

import Foundation

// Storage Keys for UserDefaults
enum StorageKeys {
    static let films = "films_storage"
    static let favFilm = "fav_film_storage"
    static let sequences = "sequences_storage"
    static let scenes = "scenes_storage"
    static let characters = "characters_storage"
    static let props = "props_storage"
    static let poses = "poses_storage"

    // Onboarding / Tutorial
    static let tutorialStep       = "tutorial_current_step"
    static let tutorialCompleted  = "pre_canvas_tutorial_completed"
    static let tutorialFilmID     = "tutorial_film_id"
    static let tutorialSequenceID = "tutorial_sequence_id"
    static let tutorialSceneID    = "tutorial_scene_id"
}

// Notification Names
enum NotificationNames {
    static let filmsUpdated = "filmsUpdated"
    static let favFilmUpdated = "favFilmUpdated"
    static let sequencesUpdated = "sequencesUpdated"
    static let scenesUpdated = "scenesUpdated"
    static let charactersUpdated = "charactersUpdated"
    static let filmCharactersUpdated = "filmCharactersUpdated"
    static let propsUpdated = "propsUpdated"
    static let posesUpdated = "posesUpdated"

    // Onboarding / Tutorial
    static let tutorialStepChanged        = "tutorialStepChanged"
    static let tutorialNavigateToFilm     = "tutorialNavigateToFilm"
    static let tutorialNavigateToSequence = "tutorialNavigateToSequence"
}
