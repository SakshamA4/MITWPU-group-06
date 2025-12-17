//
//  libraryPropsModel.swift
//  FilmsPage
//
//  Created by SDC-USER on 11/12/25.
//
import Foundation

struct PropItem {
    var id: UUID?
    let name: String
    let imageName: String
    var filmId: UUID?
    let description: String
    var surfaceTexture: String?
    var colour: String?
}
