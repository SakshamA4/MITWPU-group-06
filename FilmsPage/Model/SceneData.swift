//
//  SceneData.swift
//  FilmsPage
//
//  Created by SDC-USER on 10/12/25.
//
import Foundation

struct SceneData {
    
    static var allScenes: [SceneItem] = [
        SceneItem(title: "Framed sunset",    imageName: "Image"),
        SceneItem(title: "Stairwell",        imageName: "Image"),
        SceneItem(title: "Forest Landscape", imageName: "Image"),
        SceneItem(title: "Temple",           imageName: "Image"),
        SceneItem(title: "Dining Area",      imageName: "Image"),
        SceneItem(title: "Open terrace",     imageName: "Image"),
        SceneItem(title: "Industrial Hall",  imageName: "Image"),
        SceneItem(title: "Backyard",         imageName: "Image")
    ]
    
    static func addScene(_ item: SceneItem) {
        allScenes.append(item)
    }
}

