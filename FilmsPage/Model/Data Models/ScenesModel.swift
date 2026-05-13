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
    var sequenceID: UUID?      // nil = not in any sequence
    var sequenceName: String?  // display name of the sequence
    
    
    init(id: UUID = UUID(), name: String, image: String, notes: String? = "",
         sequenceID: UUID? = nil, sequenceName: String? = nil) {
        self.id = id
        self.name = name
        self.image = image
        self.notes = notes
        self.sequenceID = sequenceID
        self.sequenceName = sequenceName
    }
}
