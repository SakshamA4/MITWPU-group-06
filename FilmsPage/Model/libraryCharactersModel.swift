import Foundation

// MARK: - Main Character in Library

struct CharacterItem {
    var name: String
    var imageName: String
    
    // Editable properties for the Edit Character screen
    var shirtColorHex: String   // e.g. "#FFFFFF"
    var pantColorHex: String    // e.g. "#000000"
    var heightInCms: Float      // e.g. 170.0
}

// MARK: - Character Pose (for the horizontal poses row)

struct CharacterPoseItem {
    var name: String
    var imageName: String
}
