//
//  Constants.swift
//  FilmsPage
//
//  Created by SDC-USER on 17/12/25.
//

import Foundation

// MARK: - Storage Keys for UserDefaults
enum StorageKeys {
    static let films = "films_storage"
    static let favFilm = "fav_film_storage"
    static let sequences = "sequences_storage"
    static let scenes = "scenes_storage"
    static let characters = "characters_storage"
    static let props = "props_storage"
    static let poses = "poses_storage"
}

// MARK: - Notification Names
enum NotificationNames {
    static let filmsUpdated = "filmsUpdated"
    static let favFilmUpdated = "favFilmUpdated"
    static let sequencesUpdated = "sequencesUpdated"
    static let scenesUpdated = "scenesUpdated"
    static let charactersUpdated = "charactersUpdated"
    static let propsUpdated = "propsUpdated"
    static let posesUpdated = "posesUpdated"
}
