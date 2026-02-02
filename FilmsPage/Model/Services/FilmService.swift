//
//  FilmService.swift
//  FilmsPage
//
//  Created by SDC-USER on 17/12/25.
//

import Foundation

class FilmService {
    static let shared = FilmService()
    private let storageKey = StorageKeys.films
    private let favStorageKey = StorageKeys.favFilm
    private var isInitialized = false

    private var films: [Film] = [] {
        didSet {
            guard isInitialized else { return }
            save()
            NotificationCenter.default.post(name: NSNotification.Name(NotificationNames.filmsUpdated), object: nil)
        }
    }
    
    private var favFilm: Film? = nil {
        didSet {
            guard isInitialized else { return }
            saveFavFilm()
            NotificationCenter.default.post(name: NSNotification.Name(NotificationNames.favFilmUpdated), object: nil)
        }
    }

    private init() {
        load()
        isInitialized = true
        save()
        saveFavFilm()
        setupObservers()
    }
    
    // MARK: - Observers for Count Updates
    
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
            name: NSNotification.Name(NotificationNames.filmCharactersUpdated),
            object: nil
        )
    }

    // MARK: - Films CRUD Operations
    
    func getFilms() -> [Film] {
        return films
    }
    
    func getFavFilm() -> Film? {
        return favFilm
    }
    
    func setFavFilm(_ film: Film) {
        favFilm = film
    }
    
    func addFilm(_ film: Film) {
        films.append(film)
    }
    
    func updateFilm(_ film: Film) {
        if let index = films.firstIndex(where: { $0.id == film.id }) {
            films[index] = film
        }

        if favFilm?.id == film.id {
            favFilm = film
        }
    }

    func deleteFilm(at index: Int) {
        guard index < films.count else { return }
        films.remove(at: index)
    }
    
    func deleteFilm(_ film: Film) {
        // If deleting favourite film, clear it
        if favFilm?.id == film.id {
            favFilm = nil
        }

        films.removeAll { $0.id == film.id }
    }
    
    func clearFavIfNeeded() {
        if let fav = favFilm, !films.contains(where: { $0.id == fav.id }) {
            favFilm = films.first
        }
    }


    
    func getFilm(by id: UUID) -> Film? {
        return films.first { $0.id == id }
    }
    
    // MARK: - Update Film Counts
    
    @objc private func updateFilmCounts() {
        guard isInitialized else { return }
        
        let sequenceService = SequenceService.shared
        let sceneService = SceneService.shared
        let characterService = FilmCharacterService.shared
        
        for i in 0..<films.count {
            let filmId = films[i].id
            films[i].sequences = sequenceService.getSequenceCount(forFilmId: filmId)
            films[i].characters = FilmCharacterService.shared.getCharacterCount(forFilmId: filmId)
            let sequenceIds = sequenceService.getSequenceIds(forFilmId: filmId)
            films[i].scenes = sceneService.getSceneCount(forSequenceIds: sequenceIds)
        }
        
        if var fav = favFilm {
            fav.sequences = sequenceService.getSequenceCount(forFilmId: fav.id)
            fav.characters = FilmCharacterService.shared.getCharacterCount(forFilmId: fav.id)

            let sequenceIds = sequenceService.getSequenceIds(forFilmId: fav.id)
            fav.scenes = sceneService.getSceneCount(forSequenceIds: sequenceIds)
            favFilm = fav
        }
    }

    // MARK: - Persistence
    
    private func save() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(films)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save films: \(error)")
        }
    }
    
    private func saveFavFilm() {
        guard let fav = favFilm else { return }
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(fav)
            UserDefaults.standard.set(data, forKey: favStorageKey)
        } catch {
            print("Failed to save favourite film: \(error)")
        }
    }

    private func load() {
        // Load films
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            do {
                let decoder = JSONDecoder()
                films = try decoder.decode([Film].self, from: data)
            } catch {
                print("Failed to load films: \(error)")
            }
        }
        
        // Load favourite film
        if let data = UserDefaults.standard.data(forKey: favStorageKey) {
            do {
                let decoder = JSONDecoder()
                favFilm = try decoder.decode(Film.self, from: data)
            } catch {
                print("Failed to load favourite film: \(error)")
            }
        }
        
        // Initialize with default data if empty
        if films.isEmpty {
            films = [
                Film(
                    id: UUID(),
                    name: "Sample Film",
                    sequences: 0,
                    scenes: 0,
                    time: "0",
                    characters: 0,
                    props: 3,
                    image: "Image"
                ),
                Film(
                    id: UUID(),
                    name: "Templates",
                    sequences: 0,
                    scenes: 0,
                    time: "0",
                    characters: 0,
                    image: "Image"
                )
            ]
        }
        
        if favFilm == nil {
            favFilm = Film(
                id: UUID(),
                name: "Favourite Film",
                sequences: 0,
                scenes: 0,
                time: "0",
                characters: 0,
                image: "FilmImage"
            )
        }
    }
}
