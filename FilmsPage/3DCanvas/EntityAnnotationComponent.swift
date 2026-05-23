//
//  EntityAnnotationComponent.swift
//  FilmsPage
//
//  Stores a custom user-facing name and notes for any entity on the canvas.
//  Attached as an ECS component so it persists with the scene and travels
//  with the entity through undo/redo and save/load.
//

import RealityKit
import Foundation

// MARK: - EntityAnnotationComponent

/// User-editable metadata attached to any entity on the canvas.
/// Provides a custom display name and free-form notes field.
struct EntityAnnotationComponent: Component, Codable {
    
    /// Custom name given by the user. Empty = use default entity name.
    var customName: String
    
    /// Free-form notes / description written by the user.
    var notes: String
    
    /// When the annotation was last modified.
    var lastModified: Date
    
    init(customName: String = "", notes: String = "") {
        self.customName = customName
        self.notes = notes
        self.lastModified = Date()
    }
    
    /// Returns the display name: custom name if set, otherwise nil.
    var displayName: String? {
        customName.isEmpty ? nil : customName
    }
    
    /// Whether this annotation has any user content.
    var hasContent: Bool {
        !customName.isEmpty || !notes.isEmpty
    }
}
