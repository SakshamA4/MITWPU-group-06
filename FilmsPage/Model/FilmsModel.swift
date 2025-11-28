//
//  model.swift
//  FilmsPage
//
//  Created by SDC-USER on 24/11/25.
//

import Foundation
import UIKit


struct Film {
    var id: UUID
    var name : String
    var sequences: Int
    var scenes: Int
    var time : String
    var characters: Int
    var image : String
}


struct Sequence {
    var id: UUID
    var name: String
    var image: String
    var filmId: UUID
}

struct Character {
    var id: UUID
    var name: String
    var image: String
}

struct Prop {
    
    var id: UUID
    var name: String
    var image: String
}

struct Scene {
    
    var id: UUID
    var name: String
    var image: String
    var SequenceId: UUID

}

