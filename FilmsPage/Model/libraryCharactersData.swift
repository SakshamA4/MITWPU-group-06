//
//  libraryCharactersData.swift
//  FilmsPage
//
//  Created by SDC-USER on 11/12/25.
//
//import Foundation
//
//
//struct CharactersDataStore {
//    
//    // Characters shown in the grid on the left screen
//    static var characters: [CharacterItem] = [
//        CharacterItem(
//            name: "Man in a Suit",
//            imageName: "Man in a suit",
//            shirtColorHex: "#FFFFFF",
//            pantColorHex: "#000000",
//            heightInCms: 180,
//            pose: [
//            CharacterPoseItem(name: "Sleeping", imageName: "Sleeping")
//            ]
//        ),
//        CharacterItem(
//            name: "Asian man",
//            imageName: "Asian man",
//            shirtColorHex: "#FFFFFF",
//            pantColorHex: "#000000",
//            heightInCms: 178,
//            pose: [
//            CharacterPoseItem(name: "Sleeping", imageName: "Sleeping")
//            ]
//        ),
//        CharacterItem(
//            name: "Man in a jersey",
//            imageName: "Man in a jersey",
//            shirtColorHex: "#FFFFFF",
//            pantColorHex: "#000000",
//            heightInCms: 175,
//            pose: [
//            CharacterPoseItem(name: "Sleeping", imageName: "Sleeping")
//            ]
//        ),
//        CharacterItem(
//            name: "Woman 1",
//            imageName: "Woman 1",
//            shirtColorHex: "#FFFFFF",
//            pantColorHex: "#000000",
//            heightInCms: 165,
//            pose: [
//            CharacterPoseItem(name: "Sleeping", imageName: "Sleeping")
//            ]
//        ),
//        CharacterItem(
//            name: "Woman 2",
//            imageName: "Woman 2",
//            shirtColorHex: "#FFFFFF",
//            pantColorHex: "#000000",
//            heightInCms: 167,
//            pose: [
//            CharacterPoseItem(name: "Sleeping", imageName: "Sleeping")
//            ]
//        ),
//        CharacterItem(
//            name: "Woman 3",
//            imageName: "Woman 3",
//            shirtColorHex: "#FFFFFF",
//            pantColorHex: "#000000",
//            heightInCms: 168,
//            pose: [
//            CharacterPoseItem(name: "Sleeping", imageName: "Sleeping")
//            ]
//        )
//    ]
//    
//    // Poses shown in the horizontal “Character Poses” strip
//    private(set) static var poses: [CharacterPoseItem] = [
//        CharacterPoseItem(name: "Waving Man",     imageName: "pose_waving"),
//        CharacterPoseItem(name: "Joining hands",  imageName: "pose_joining_hands"),
//        CharacterPoseItem(name: "Lying down",     imageName: "pose_lying_down"),
//        CharacterPoseItem(name: "Talking Man",    imageName: "pose_talking"),
//        CharacterPoseItem(name: "Arms stretched", imageName: "pose_arms_stretched"),
//        CharacterPoseItem(name: "Sitting Man",    imageName: "pose_sitting")
//    ]
//    
//    // MARK: - Add / Update
//    
//    static func addCharacter(_ character: CharacterItem) {
//        characters.append(character)
//    }
//    
//    static func addPose(_ pose: CharacterPoseItem) {
//        poses.append(pose)
//    }
//    
//    static func updateCharacter(at index: Int, with updated: CharacterItem) {
//        guard characters.indices.contains(index) else { return }
//        characters[index] = updated
//    }
//}
