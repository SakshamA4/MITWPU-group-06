//  WalkAnimationComponent.swift
//  3DCanvas

import RealityKit

/// Stamped onto a character entity while a walk clip is actively playing.
/// Guards against re-starting the skeleton cycle every tick.
struct WalkAnimationComponent: Component {
    var controller: AnimationPlaybackController
}
