//
//  SceneItem.swift
//  FilmsPage
//
//  Created by SDC-USER on 10/12/25.
//
import Foundation

struct SceneItem: Identifiable, Hashable {
    let id: UUID = UUID()
    var title: String
    var imageName: String
}

