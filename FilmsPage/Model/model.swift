//
//  model.swift
//  FilmsPage
//
//  Created by SDC-USER on 24/11/25.
//

import Foundation
import UIKit

struct favFilms {
    var id: Int
    var name : String
    var sequences: Int
    var scenes: Int
    var time : String
    var characters: Int
    var image : String
}

struct otherFilms {
    var name: String
    var image: [String]
}
struct Film {
    var id: Int
    var name : String
    var sequences: Int
    var scenes: Int
    var time : String
    var characters: Int
    var image : [String]
//    var favorite: Bool
}
struct Sequences {
    var name: String
    var image: [String]
}

struct Scenes {
    var name: String
    var image: [String]
}

struct Characters {
    var name: String
    var image: [String]
}

struct Props {
    var name: String
    var image: [String]
}
