//
//  BackgroundData.swift
//  FilmsPage
//
//  Created by SDC-USER on 08/12/25.
//
import Foundation

struct BackgroundData {
    
    static var allBackgrounds: [BackgroundItem] = [
        BackgroundItem(title: "Framed sunset",    imageName: "Framed sunset"),
        BackgroundItem(title: "Stairwell",        imageName: "Stairwell"),
        BackgroundItem(title: "Forest Landscape", imageName: "Forest Landscape"),
        BackgroundItem(title: "Temple",           imageName: "Temple"),
        BackgroundItem(title: "Dining Area",      imageName: "Dining Area"),
        BackgroundItem(title: "Open terrace",     imageName: "Open terrace"),
        BackgroundItem(title: "Industrial Hall",  imageName: "Industrial Hall"),
        BackgroundItem(title: "Backyard",         imageName: "Backyard")
    ]
    
    static func addBackground(_ item: BackgroundItem) {
        allBackgrounds.append(item)
    }
}

