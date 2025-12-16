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
    var name : String
    var sequences: Int = 0
    var scenes: Int = 0
    var time : String = "00:00:00"
    var characters: Int = 0
    var props: Int = 0
    var image : String
}


struct Sequence: Codable {
    var id: UUID
    var name: String
    var image: String
    var filmId: UUID
}

struct Character {
    var id: UUID
    var name: String
    var image: String
    var filmId: UUID = UUID()
    var pose: [Pose]
}

struct Pose: Codable {
    var id: UUID
    var name: String
    var image: String
}


struct Prop {
    
    var id: UUID
    var name: String
    var image: String
    var filmId: UUID?
}

struct Scene: Codable {
    
    var id: UUID
    var name: String
    var image: String
    var SequenceId: UUID

}

