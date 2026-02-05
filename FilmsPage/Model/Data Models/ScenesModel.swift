//
//  ScenesModel.swift
//  FilmsPage
//
//  Created by SDC-USER on 17/12/25.
//


import Foundation


struct ScenesModel: Codable, Equatable, Hashable, Identifiable {
    let id: UUID
    var name: String // Changed to var to allow renaming
    var image: String?
    var notes: String? 
    
    
    init(id: UUID = UUID(), name: String, image: String, notes: String? = "") {
        self.id = id
        self.name = name
        self.image = image
        self.notes = notes
    }
}
