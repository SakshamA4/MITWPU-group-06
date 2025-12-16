//
//  BackgroundData.swift
//  FilmsPage
//
//  Created by SDC-USER on 08/12/25.
//
import Foundation

struct BackgroundData {
    
    static var allBackgrounds: [BackgroundItem] = [
        BackgroundItem(title: "Framed sunset",    imageName: "Image"),
        BackgroundItem(title: "Stairwell",        imageName: "Image"),
        BackgroundItem(title: "Forest Landscape", imageName: "Image"),
        BackgroundItem(title: "Temple",           imageName: "Image"),
        BackgroundItem(title: "Dining Area",      imageName: "Image"),
        BackgroundItem(title: "Open terrace",     imageName: "Image"),
        BackgroundItem(title: "Industrial Hall",  imageName: "Image"),
        BackgroundItem(title: "Backyard",         imageName: "Image")
    ]
    
    static func addBackground(_ item: BackgroundItem) {
        allBackgrounds.append(item)
    }
}

