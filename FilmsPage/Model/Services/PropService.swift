//
//  PropService.swift
//  FilmsPage
//
//  Created by SDC-USER on 17/12/25.
//

import Foundation

class PropService {
    static let shared = PropService()
    private let storageKey = StorageKeys.props
    private var isInitialized = false

    private var props: [PropItem] = [] {
        didSet {
            guard isInitialized else { return }
            save()
            NotificationCenter.default.post(name: NSNotification.Name(NotificationNames.propsUpdated), object: nil)
        }
    }

    private init() {
        load()
        isInitialized = true
    }

    // MARK: - CRUD Operations
    
    func getProps() -> [PropItem] {
        return props
    }
    
    func getProps(forFilmId filmId: UUID) -> [PropItem] {
        return props.filter { prop in
            guard let filmIds = prop.filmId else { return false }
            return filmIds.compactMap { $0 }.contains(filmId)
        }
    }
    
    func getProp(by id: UUID) -> PropItem? {
        return props.first { $0.id == id }
    }
    
    func addProp(_ prop: PropItem) {
        props.append(prop)
    }
    
    func updateProp(_ prop: PropItem) {
        if let propId = prop.id,
           let index = props.firstIndex(where: { $0.id == propId }) {
            props[index] = prop
        }
    }
    
    func deleteProp(at index: Int) {
        guard index < props.count else { return }
        props.remove(at: index)
    }
    
    func deleteProp(by id: UUID) {
        props.removeAll { $0.id == id }
    }
    
    func attachPropToFilm(propId: UUID, filmId: UUID) {
        guard let index = props.firstIndex(where: { $0.id == propId }) else { return }
        
        if props[index].filmId == nil {
            props[index].filmId = [filmId]
        } else {
            let existingIds = props[index].filmId?.compactMap { $0 } ?? []
            if !existingIds.contains(filmId) {
                props[index].filmId?.append(filmId)
            }
        }
    }
    
    func detachPropFromFilm(propId: UUID, filmId: UUID) {
        guard let index = props.firstIndex(where: { $0.id == propId }) else { return }
        props[index].filmId?.removeAll { $0 == filmId }
    }
    
    func getPropCount(forFilmId filmId: UUID) -> Int {
        return getProps(forFilmId: filmId).count
    }

    // MARK: - Persistence
    
    private func save() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(props)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save props: \(error)")
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            do {
                let decoder = JSONDecoder()
                props = try decoder.decode([PropItem].self, from: data)
            } catch {
                print("Failed to load props: \(error)")
            }
        }
        
        // Initialize with default template props (no filmId - templates)
        if props.isEmpty {
            props = [
                PropItem(
                    id: UUID(),
                    name: "Plant",
                    imageName: "Plant",
                    filmId: nil,
                    description: "A decorative indoor plant used to add freshness and life to a scene."
                ),
                PropItem(
                    id: UUID(),
                    name: "Bookshelf",
                    imageName: "Bookshelf",
                    filmId: nil,
                    description: "A wooden bookshelf filled with books, ideal for study rooms or living spaces."
                ),
                PropItem(
                    id: UUID(),
                    name: "Fridge",
                    imageName: "Fridge",
                    filmId: nil,
                    description: "A modern refrigerator commonly placed in kitchens for storing food and drinks."
                ),
                PropItem(
                    id: UUID(),
                    name: "Wardrobe",
                    imageName: "Wardrobe",
                    filmId: nil,
                    description: "A tall wardrobe used for storing clothes, suitable for bedrooms."
                ),
                PropItem(
                    id: UUID(),
                    name: "Handbag",
                    imageName: "Handbag",
                    filmId: nil,
                    description: "A stylish handbag that characters can carry or place in indoor scenes."
                ),
                PropItem(
                    id: UUID(),
                    name: "Flower Vase",
                    imageName: "Flower Vase",
                    filmId: nil,
                    description: "A decorative flower vase used to enhance tables, shelves, or room corners."
                ),
                PropItem(
                    id: UUID(),
                    name: "Bag Pack",
                    imageName: "Bag Pack",
                    filmId: nil,
                    description: "A casual backpack suitable for travel, school, or outdoor scenes."
                ),
                PropItem(
                    id: UUID(),
                    name: "Shoe Rack",
                    imageName: "Shoe Rack",
                    filmId: nil,
                    description: "A compact rack designed to neatly store shoes near entrances or rooms."
                )
            ]
        }
    }
}
