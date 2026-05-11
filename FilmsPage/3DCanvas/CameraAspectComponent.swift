//
//  CameraAspectComponent.swift
//  FilmsPage
//
//  ECS component attached to camera root entities to track their
//  per-camera aspect ratio. Mirrors the pattern of CameraVisualComponent.
//

import RealityKit

// MARK: - CameraAspectComponent

struct CameraAspectComponent: Component {
    var aspectRatio: CameraAspectRatio = .default
}
