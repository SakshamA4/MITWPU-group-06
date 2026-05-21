//
//  model.swift
//  FilmsPage
//
//  Created by SDC-USER on 24/11/25.
//

import Foundation
import UIKit

struct Film: Codable {
    var id: UUID
    var name: String
    var sequences: Int = 0
    var scenes: Int = 0
    var time: String = "00:00:00"
    var characters: Int = 0
    var props: Int = 0
    var image: String
    var notes: String = ""
    let createdDate: Date
}

struct Sequence: Codable {
    var id: UUID
    var name: String
    var image: String
    var filmId: UUID
}

struct Scene: Codable, Equatable, Hashable, Identifiable {
    let id: UUID
    var name: String
    var image: String?
    var sequenceId: UUID
    var notes: String?

    init(id: UUID = UUID(), name: String, image: String? = "Image", sequenceId: UUID, notes: String? = "") {
        self.id = id
        self.name = name
        self.sequenceId = sequenceId
        self.notes = notes
        self.image = image
    }
}
