//
//  CinematicTimelineIntegration.swift
//  FilmsPage
//
//  Bridges cinematic camera system with Timeline engine.
//  Keyframeable properties for camera parameters.
//

import Foundation
import RealityKit

// MARK: - CinematicKeyframeProperty

enum CinematicKeyframeProperty: String, Codable, CaseIterable, Identifiable {
    case focalLength       = "cine.focalLength"
    case aperture          = "cine.aperture"
    case focusDistance      = "cine.focusDistance"
    case lookIntensity     = "cine.lookIntensity"
    case lookWarmth        = "cine.lookWarmth"
    case lookContrast      = "cine.lookContrast"
    case lookSaturation    = "cine.lookSaturation"
    case motionIntensity   = "cine.motionIntensity"
    case bloomIntensity    = "cine.bloomIntensity"
    case halationIntensity = "cine.halationIntensity"
    case vignetteIntensity = "cine.vignetteIntensity"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .focalLength:       return "Focal Length"
        case .aperture:          return "Aperture"
        case .focusDistance:      return "Focus Distance"
        case .lookIntensity:     return "Look Intensity"
        case .lookWarmth:        return "Warmth"
        case .lookContrast:      return "Contrast"
        case .lookSaturation:    return "Saturation"
        case .motionIntensity:   return "Motion Intensity"
        case .bloomIntensity:    return "Bloom"
        case .halationIntensity: return "Halation"
        case .vignetteIntensity: return "Vignette"
        }
    }
    
    var valueRange: ClosedRange<Float> {
        switch self {
        case .focalLength:  return 10...300
        case .aperture:     return 1.4...22
        case .focusDistance: return 0.3...100
        default:            return 0...1
        }
    }
}

// MARK: - Interpolation

enum CinematicInterpolation: String, Codable, CaseIterable, Hashable {
    case linear = "Linear"
    case smooth = "Smooth"
    case step   = "Step"
    
    func evaluate(_ t: Float) -> Float {
        switch self {
        case .linear: return t
        case .smooth: return t * t * (3 - 2 * t)
        case .step:   return t < 1.0 ? 0.0 : 1.0
        }
    }
}

// MARK: - CinematicKeyframe

struct CinematicKeyframe: Codable, Hashable, Identifiable {
    let id: String
    var time: Float
    var property: CinematicKeyframeProperty
    var value: Float
    var interpolation: CinematicInterpolation
    
    init(time: Float, property: CinematicKeyframeProperty, value: Float,
         interpolation: CinematicInterpolation = .smooth) {
        self.id = UUID().uuidString
        self.time = time
        self.property = property
        self.value = value
        self.interpolation = interpolation
    }
}

// MARK: - Timeline Track

struct CinematicTimelineTrack: Codable, Identifiable, Hashable {
    let id: String
    let property: CinematicKeyframeProperty
    var keyframes: [CinematicKeyframe]
    var isEnabled: Bool = true
    
    init(property: CinematicKeyframeProperty) {
        self.id = UUID().uuidString
        self.property = property
        self.keyframes = []
    }
    
    func evaluate(at time: Float) -> Float? {
        guard isEnabled, !keyframes.isEmpty else { return nil }
        let sorted = keyframes.sorted { $0.time < $1.time }
        
        guard let first = sorted.first else { return nil }
        if time <= first.time { return first.value }
        guard let last = sorted.last else { return nil }
        if time >= last.time { return last.value }
        
        for i in 0..<(sorted.count - 1) {
            let a = sorted[i], b = sorted[i + 1]
            if time >= a.time && time <= b.time {
                let duration = b.time - a.time
                guard duration > 0 else { return a.value }
                let t = (time - a.time) / duration
                return a.value + (b.value - a.value) * a.interpolation.evaluate(t)
            }
        }
        return last.value
    }
    
    mutating func setKeyframe(at time: Float, value: Float,
                               interpolation: CinematicInterpolation = .smooth) {
        keyframes.removeAll { abs($0.time - time) < 0.001 }
        keyframes.append(CinematicKeyframe(time: time, property: property,
                                            value: value, interpolation: interpolation))
    }
}

// MARK: - Timeline Evaluator

final class CinematicTimelineEvaluator {
    var tracks: [CinematicTimelineTrack] = []
    
    func evaluate(at time: Float) -> [CinematicKeyframeProperty: Float] {
        var result: [CinematicKeyframeProperty: Float] = [:]
        for track in tracks {
            if let value = track.evaluate(at: time) {
                result[track.property] = value
            }
        }
        return result
    }
    
    func apply(at time: Float, to pipeline: CinematicRenderPipeline, cameraRoot: Entity) {
        let values = evaluate(at: time)
        for (property, value) in values {
            switch property {
            case .focalLength:
                if var lens = cameraRoot.components[CineLensComponent.self] {
                    lens.selectedFocalLengthMM = value
                    cameraRoot.components.set(lens)
                }
                pipeline.configure(focalLength: value)
            case .aperture:
                var focus = cameraRoot.components[CameraFocusComponent.self] ?? CameraFocusComponent()
                focus.aperture = value
                cameraRoot.components.set(focus)
            case .focusDistance:
                var focus = cameraRoot.components[CameraFocusComponent.self] ?? CameraFocusComponent()
                focus.focusDistance = value
                cameraRoot.components.set(focus)
            case .lookIntensity:
                break // Look intensity not yet supported by pipeline.configure()
            case .motionIntensity:
                if var motion = cameraRoot.components[CineMotionComponent.self] {
                    motion.intensityMultiplier = value
                    cameraRoot.components.set(motion)
                }
            default:
                break
            }
        }
    }
    
    func ensureTrack(for property: CinematicKeyframeProperty) -> Int {
        if let idx = tracks.firstIndex(where: { $0.property == property }) { return idx }
        tracks.append(CinematicTimelineTrack(property: property))
        return tracks.count - 1
    }
}
