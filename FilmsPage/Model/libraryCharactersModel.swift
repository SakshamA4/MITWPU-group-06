import Foundation

// MARK: - Main Character in Library

struct CharacterItem {
    var id: UUID?
    var name: String
    var imageName: String
    
    // Editable properties for the Edit Character screen
    var shirtColorHex: String?  // e.g. "#FFFFFF"
    var pantColorHex: String?   // e.g. "#000000"
    var heightInCms: Float?
    var filmId: UUID?    // e.g. 170.0
    var pose: [CharacterPoseItem]

}

// MARK: - Character Pose (for the horizontal poses row)

struct CharacterPoseItem: Codable {
    var id: UUID?
    var name: String
    var imageName: String
}
