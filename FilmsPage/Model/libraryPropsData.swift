//
//  libraryPropsData.swift
//  FilmsPage
//
//  Created by SDC-USER on 11/12/25.
//
import Foundation

struct PropsDataStore {
    
    // Static list of props shown in the Props screen
    static var items: [PropItem] = [
        PropItem(
            name: "Handbag",
            imageName: "Image",
            description: "A stylish handbag used as a personal accessory or prop for characters."
        ),
        PropItem(
            name: "Bookshelf",
            imageName: "Image",
            description: "A classic bookshelf used to decorate interiors or signify intellect."
        ),
        PropItem(
            name: "Fridge",
            imageName: "Image",
            description: "Common household appliance used to set kitchen or living space scenes."
        ),
        PropItem(
            name: "Flower Vase",
            imageName: "Image",
            description: "Adds aesthetic appeal and color to indoor scenes."
        ),
        PropItem(
            name: "Plant",
            imageName: "Image",
            description: "Used to bring freshness and life to a room setting."
        ),
        PropItem(
            name: "Wardrobe",
            imageName: "Image",
            description: "Functional furniture piece often used in bedroom or dressing scenes."
        ),
        PropItem(
            name: "Bag Pack",
            imageName: "Image",
            description: "Casual bag used to portray students, travelers, or modern characters."
        ),
        PropItem(
            name: "Shoe Rack",
            imageName: "Image",
            description: "Simple furniture prop used in hallway or home entryway scenes."
        ),
        PropItem(
            name: "Butter",
            imageName: "Image",
            description: "Casual bag used to portray students, travelers, or modern characters."
        )
    ]
    
    // MARK: - Add new props dynamically if needed
    static func addProp(name: String, imageName: String, description: String) {
        let newProp = PropItem(name: name, imageName: imageName, description: description)
        items.append(newProp)
    }
}
