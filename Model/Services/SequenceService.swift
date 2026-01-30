//
//  SequenceService.swift
//  FilmsPage
//
//  Created by SDC-USER on 17/12/25.
//

import Foundation

class SequenceService {
    static let shared = SequenceService()
    private let storageKey = StorageKeys.sequences
    private var isInitialized = false

    private var sequences: [Sequence] = [] {
        didSet {
            guard isInitialized else { return }
            save()
            NotificationCenter.default.post(name: NSNotification.Name(NotificationNames.sequencesUpdated), object: nil)
        }
    }

    private init() {
        load()
        isInitialized = true
    }

    // MARK: - CRUD Operations
    
    func getSequences() -> [Sequence] {
        return sequences
    }
    
    func getSequences(forFilmId filmId: UUID) -> [Sequence] {
        return sequences.filter { $0.filmId == filmId }
    }
    
    func getSequence(by id: UUID) -> Sequence? {
        return sequences.first { $0.id == id }
    }
    
    func addSequence(_ sequence: Sequence) {
        sequences.append(sequence)
    }
    
    func updateSequence(_ sequence: Sequence) {
        if let index = sequences.firstIndex(where: { $0.id == sequence.id }) {
            sequences[index] = sequence
        }
    }
    
    func deleteSequence(at index: Int) {
        guard index < sequences.count else { return }
        sequences.remove(at: index)
    }
    
    func deleteSequence(by id: UUID) {
        sequences.removeAll { $0.id == id }
    }
    
    func deleteSequences(forFilmId filmId: UUID) {
        sequences.removeAll { $0.filmId == filmId }
    }
    
    func getSequenceCount(forFilmId filmId: UUID) -> Int {
        return sequences.filter { $0.filmId == filmId }.count
    }
    
    func getSequenceIds(forFilmId filmId: UUID) -> [UUID] {
        return sequences.filter { $0.filmId == filmId }.map { $0.id }
    }

    // MARK: - Persistence
    
    private func save() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(sequences)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save sequences: \(error)")
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            do {
                let decoder = JSONDecoder()
                sequences = try decoder.decode([Sequence].self, from: data)
            } catch {
                print("Failed to load sequences: \(error)")
            }
        }
    }
}
