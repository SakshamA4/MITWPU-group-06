//
//  cameraModel.swift
//  FilmsPage
//
//  Created by SDC-USER on 10/12/25.
//
import Foundation

// MARK: - Item

struct CameraLibraryItem: Hashable, Identifiable {
    let id = UUID()
    let name: String
    let imageName: String
    let description: String
}

// MARK: - Section Type

enum CameraLibrarySectionType: Int, CaseIterable {
    case cameras
    case movements
    case staticShots

    var title: String {
        switch self {
        case .cameras:      return "Cameras"
        case .movements:    return "Camera Movements"
        case .staticShots:  return "Static Shots"
        }
    }
}

// MARK: - Section Model

struct CameraLibrarySection: Hashable, Identifiable {
    let id = UUID()
    let type: CameraLibrarySectionType
    let items: [CameraLibraryItem]
}

