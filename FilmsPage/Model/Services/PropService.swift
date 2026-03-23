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
    
    func removeProp(_ propId: UUID, fromFilmId filmId: UUID) {
        guard let index = props.firstIndex(where: { $0.id == propId }) else { return }

        props[index].filmId = props[index].filmId?
            .compactMap { $0 }
            .filter { $0 != filmId }
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
                PropItem(id: UUID(), name: "Chair", imageName: "chair_img", filmId: nil, description: "Standard chair", modelFileName: "chair"),
                PropItem(id: UUID(), name: "Table", imageName: "Table_img", filmId: nil, description: "Standard table", modelFileName: "Table"),
                PropItem(id: UUID(), name: "Lamp", imageName: "lamp_img", filmId: nil, description: "Desk lamp", modelFileName: "lamp"),
                PropItem(id: UUID(), name: "Robot", imageName: "robot_img", filmId: nil, description: "Toy robot", modelFileName: "Robot"),
                PropItem(id: UUID(), name: "Flower Vase", imageName: "flowerVase_img", filmId: nil, description: "Flower vase", modelFileName: "flowerVase"),
                PropItem(id: UUID(), name: "Plant", imageName: "Plant_img", filmId: nil, description: "House Plant", modelFileName: "Plant"),
                PropItem(id: UUID(), name: "Wardrobe", imageName: "wardrobe_img", filmId: nil, description: "Wardrobe", modelFileName: "wardrobe"),
                PropItem(id: UUID(), name: "Ball", imageName: "ball_img", filmId: nil, description: "Sports ball", modelFileName: "ball")
            ]
        }
    }
}
