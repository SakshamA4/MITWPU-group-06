//
//  model.swift
//  FilmsPage
//
//  Created by SDC-USER on 24/11/25.
//

import Foundation
import UIKit


struct Film {
    var id: Int
    var name : String
    var sequences: Int
    var scenes: Int
    var time : String
    var characters: Int
    var image : [String]
}


struct Sequence {
    var name: String
    var image: [String]
}

struct Character {
    var name: String
    var image: [String]
}

struct Prop {
    var name: String
    var image: [String]
}



