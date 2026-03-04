//
//  FilmService.swift
//  FilmsPage
//

import Foundation

class FilmService {
    static let shared = FilmService()
    private let storageKey = StorageKeys.films
    private var isInitialized = false

    private var films: [Film] = [] {
        didSet {
            guard isInitialized else { return }
            save()
            NotificationCenter.default.post(name: NSNotification.Name(NotificationNames.filmsUpdated), object: nil)
        }
    }

    private init() {
        load()
        isInitialized = true
        save()
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

    func addFilm(_ film: Film) {
        films.append(film)
    }

    func updateFilm(_ film: Film) {
        if let index = films.firstIndex(where: { $0.id == film.id }) {
            films[index] = film
            save()
            NotificationCenter.default.post(name: NSNotification.Name(NotificationNames.filmsUpdated), object: nil)
        }
    }

    func deleteFilm(at index: Int) {
        guard index < films.count else { return }
        films.remove(at: index)
    }

    func deleteFilm(_ film: Film) {
        films.removeAll { $0.id == film.id }
    }

    func getFilm(by id: UUID) -> Film? {
        return films.first { $0.id == id }
    }

    // MARK: - Update Film Counts

    @objc private func updateFilmCounts() {
        guard isInitialized else { return }

        let sequenceService = SequenceService.shared
        let sceneService = SceneService.shared

        for i in 0..<films.count {
            let filmId = films[i].id
            films[i].sequences = sequenceService.getSequenceCount(forFilmId: filmId)
            films[i].characters = FilmCharacterService.shared.getCharacterCount(forFilmId: filmId)
            let sequenceIds = sequenceService.getSequenceIds(forFilmId: filmId)
            films[i].scenes = sceneService.getSceneCount(forSequenceIds: sequenceIds)
        }
    }

    // MARK: - Persistence

    private func save() {
        do {
            let data = try JSONEncoder().encode(films)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save films: \(error)")
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            do {
                films = try JSONDecoder().decode([Film].self, from: data)
            } catch {
                print("Failed to load films: \(error)")
            }
        }

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
    }
}
