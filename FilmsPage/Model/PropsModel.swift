//
//  libraryPropsModel.swift
//  FilmsPage
//
//  Created by SDC-USER on 11/12/25.
//
import Foundation

struct PropItem: Codable {
    var id: UUID?
    var name: String
    var imageName: String
    var filmId: [UUID?]?
    var description: String
    var surfaceTexture: String?
    var colour: String?
}
