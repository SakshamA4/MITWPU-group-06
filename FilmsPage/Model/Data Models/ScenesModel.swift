//
//  ScenesModel.swift
//  FilmsPage
//
//  Created by SDC-USER on 17/12/25.
//


import Foundation

struct ScenesModel: Codable, Equatable, Hashable {
    let id: UUID
    let name: String
    let image: String 

    init(id: UUID = UUID(), name: String, image: String) {
        self.id = id
        self.name = name
        self.image = image
    }
}

