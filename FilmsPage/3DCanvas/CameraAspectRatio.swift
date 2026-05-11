//
//  CameraAspectRatio.swift
//  FilmsPage
//
//  Per-camera aspect ratio presets. Mirrors the existing enum pattern
//  used by ToolType, AnimationType, etc.
//

import Foundation
import CoreGraphics

// MARK: - CameraAspectRatio

enum CameraAspectRatio: String, CaseIterable, Codable {
    case sixteenByNine     = "16:9"
    case fourByThree       = "4:3"
    case oneByOne          = "1:1"
    case twoThirtyFiveByOne = "2.35:1"
    case nineBySixteen     = "9:16"

    // MARK: - Computed Properties

    /// Width / height as a Float.
    var ratio: Float {
        switch self {
        case .sixteenByNine:      return 16.0 / 9.0
        case .fourByThree:        return 4.0 / 3.0
        case .oneByOne:           return 1.0
        case .twoThirtyFiveByOne: return 2.35
        case .nineBySixteen:      return 9.0 / 16.0
        }
    }

    /// Human-readable label for the UI.
    var displayName: String { rawValue }

    /// Preview snapshot resolution derived from a base area of 129600px²
    /// (360×360 equivalent) so all thumbnails have equal visual area
    /// regardless of aspect ratio.
    var snapshotSize: CGSize {
        let baseArea: Float = 129_600 // 360 * 360
        let w = sqrt(baseArea * ratio)
        let h = w / ratio
        return CGSize(width: CGFloat(w), height: CGFloat(h))
    }

    /// The default aspect ratio for new cameras and backward-compatible loads.
    static var `default`: CameraAspectRatio { .sixteenByNine }
}
