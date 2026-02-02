import Foundation

// MARK: - Main Character in Library

struct CharacterItem: Codable {
    var id: UUID
    var name: String
    var imageName: String
    var pose: [CharacterPoseItem]
}

struct FilmCharacter: Codable {
    var id: UUID
    var filmId: UUID

    // Reference to library character
    var characterTemplateId: UUID

    // Editable per film
    var nameOverride: String?
    var heightInCms: Float?
    var selectedPoseId: UUID?
}


struct CharacterPoseItem: Codable {
    var id: UUID?
    var name: String
    var imageName: String
    var modelFilename: String?
}
