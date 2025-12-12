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

struct scenes {
    var name: String
    var image: [String]
}

struct characters {
    var name: String
    var image: [String]
}

struct props {
    var name: String
    var image: [String]
}



