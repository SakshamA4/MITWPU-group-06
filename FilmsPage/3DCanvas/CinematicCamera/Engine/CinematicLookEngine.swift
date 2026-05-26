//
//  CinematicLookEngine.swift
//  FilmsPage
//
//  Cinematic look color processing engine. Applies creative color
//  grading parameters from CinematicLook presets to rendered frames.
//  Separates creative grading from technical lens/sensor simulation.
//
//  Pipeline order:
//    1. Warmth / Tint (color temperature shift)
//    2. Contrast (S-curve with configurable midpoint)
//    3. Highlight Rolloff (soft shoulder compression)
//    4. Shadow Lift (black level adjustment)
//    5. Saturation
//    6. Split Toning (highlight/shadow color cast)
//    7. LUT Application (optional, via CIColorCube)
//    8. Grain overlay (optional)
//
//  All operations use CoreImage for GPU-accelerated processing.
//  LUT application uses CIColorCubeWithColorSpace for accuracy.
//

import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

// MARK: - CinematicLookEngine

/// GPU-accelerated cinematic color grading engine.
/// Processes rendered frames through a creative look pipeline that
/// layers on top of the technical camera/lens simulation.
final class CinematicLookEngine {
    
    // MARK: - Properties
    
    /// Shared CoreImage context for GPU processing.
    private let ciContext: CIContext
    
    /// Cached LUT color cube data keyed by look ID.
    private var lutCache: [String: Data] = [:]
    
    /// Current interpolation state for smooth look transitions.
    private var transitionState: LookTransitionState?
    
    // MARK: - Initialisation
    
    init(ciContext: CIContext? = nil) {
        self.ciContext = ciContext ?? CIContext(options: [
            .useSoftwareRenderer: false,
            .highQualityDownsample: true,
            .cacheIntermediates: false
        ])
    }
    
    // MARK: - Main Processing Pipeline
    
    /// Applies a cinematic look to a rendered frame.
    /// - Parameters:
    ///   - image: Source CIImage from the render pipeline.
    ///   - look: The cinematic look parameters to apply.
    ///   - lutData: Optional parsed LUT data for custom look application.
    ///   - intensity: Overall look intensity (0 = bypass, 1 = full).
    /// - Returns: Processed CIImage with creative grading applied.
    func processLook(
        _ image: CIImage,
        look: CinematicLook,
        lutData: LUTData? = nil,
        intensity: Float = 1.0
    ) -> CIImage {
        guard intensity > 0.001 else { return image }
        
        var result = image
        
        // 1. Warmth and tint
        result = applyWarmthTint(result, warmth: look.warmth, tint: look.tint)
        
        // 2. Contrast with S-curve
        result = applyContrast(result, amount: look.contrast)
        
        // 3. Highlight rolloff
        result = applyHighlightRolloff(result, amount: look.highlightRolloff)
        
        // 4. Shadow liftKKK
        result = applyShadowLift(result, amount: look.shadowLift)
        
        // 5. Saturation
        result = applySaturation(result, amount: look.saturation)
        
        // 6. Split toning
        let hlStrength = max(look.highlightTintR, max(look.highlightTintG, look.highlightTintB))
        let shStrength = max(look.shadowTintR, max(look.shadowTintG, look.shadowTintB))
        result = applySplitToning(
            result,
            highlightColor: CIColor(red: CGFloat(look.highlightTintR), green: CGFloat(look.highlightTintG), blue: CGFloat(look.highlightTintB)),
            shadowColor: CIColor(red: CGFloat(look.shadowTintR), green: CGFloat(look.shadowTintG), blue: CGFloat(look.shadowTintB)),
            highlightStrength: hlStrength,
            shadowStrength: shStrength
        )
        
        // 7. LUT application (if provided)
        if let lutData = lutData {
            result = applyLUT(result, lutData: lutData, intensity: look.lutIntensity)
        }
        
        // Blend with original based on overall intensity
        if intensity < 0.999 {
            result = blendImages(base: image, overlay: result, amount: intensity)
        }
        
        return result
    }
    
    // MARK: - Warmth and Tint
    
    /// Shifts colour temperature using a colour matrix transform.
    /// Positive warmth = warmer (amber shift), negative = cooler (blue shift).
    /// Tint adjusts green-magenta axis.
    private func applyWarmthTint(_ image: CIImage, warmth: Float, tint: Float) -> CIImage {
        guard abs(warmth) > 0.001 || abs(tint) > 0.001 else { return image }
        
        // Temperature shift via colour matrix
        // Warmth: boost red, reduce blue
        // Tint: boost green (positive) or magenta (negative)
        let rGain: Float = 1.0 + warmth * 0.15
        let gGain: Float = 1.0 + tint * 0.08
        let bGain: Float = 1.0 - warmth * 0.12
        
        let filter = CIFilter.colorMatrix()
        filter.inputImage = image
        filter.rVector = CIVector(x: CGFloat(rGain), y: 0, z: 0, w: 0)
        filter.gVector = CIVector(x: 0, y: CGFloat(gGain), z: 0, w: 0)
        filter.bVector = CIVector(x: 0, y: 0, z: CGFloat(bGain), w: 0)
        filter.aVector = CIVector(x: 0, y: 0, z: 0, w: 1)
        filter.biasVector = CIVector(x: 0, y: 0, z: 0, w: 0)
        
        return filter.outputImage ?? image
    }
    
    // MARK: - Contrast (S-Curve)
    
    /// Applies an S-curve contrast adjustment.
    /// Uses tone curve filter for smooth, filmic contrast.
    private func applyContrast(_ image: CIImage, amount: Float) -> CIImage {
        guard abs(amount) > 0.001 else { return image }
        
        // Map contrast (-1...1) to curve control points
        let lift = max(0, -amount * 0.08)
        let shadow = 0.25 - amount * 0.06
        let mid = 0.5
        let highlight = 0.75 + amount * 0.06
        let gain = min(1.0, 1.0 + amount * 0.08)
        
        let filter = CIFilter.toneCurve()
        filter.inputImage = image
        filter.point0 = CGPoint(x: 0.0, y: CGFloat(lift))
        filter.point1 = CGPoint(x: 0.25, y: CGFloat(shadow))
        filter.point2 = CGPoint(x: 0.5, y: CGFloat(mid))
        filter.point3 = CGPoint(x: 0.75, y: CGFloat(highlight))
        filter.point4 = CGPoint(x: 1.0, y: CGFloat(gain))
        
        return filter.outputImage ?? image
    }
    
    // MARK: - Highlight Rolloff
    
    /// Softly compresses highlights for a filmic shoulder.
    /// Higher values create a gentler transition into clipping.
    private func applyHighlightRolloff(_ image: CIImage, amount: Float) -> CIImage {
        guard amount > 0.001 else { return image }
        
        // Use highlight/shadow adjust for soft rolloff
        let filter = CIFilter.highlightShadowAdjust()
        filter.inputImage = image
        filter.highlightAmount = 1.0 - amount * 0.6
        filter.shadowAmount = 0.0
        
        return filter.outputImage ?? image
    }
    
    // MARK: - Shadow Lift
    
    /// Raises black levels for a faded/filmic shadow feel.
    /// Amount 0 = true black, 1 = heavily lifted shadows.
    private func applyShadowLift(_ image: CIImage, amount: Float) -> CIImage {
        guard amount > 0.001 else { return image }
        
        let liftValue = amount * 0.12
        
        let filter = CIFilter.toneCurve()
        filter.inputImage = image
        filter.point0 = CGPoint(x: 0.0, y: CGFloat(liftValue))
        filter.point1 = CGPoint(x: 0.25, y: CGFloat(0.25 + liftValue * 0.5))
        filter.point2 = CGPoint(x: 0.5, y: 0.5)
        filter.point3 = CGPoint(x: 0.75, y: 0.75)
        filter.point4 = CGPoint(x: 1.0, y: 1.0)
        
        return filter.outputImage ?? image
    }
    
    // MARK: - Saturation
    
    /// Adjusts overall colour saturation.
    /// 0 = fully desaturated, 1 = normal, >1 = boosted.
    private func applySaturation(_ image: CIImage, amount: Float) -> CIImage {
        guard abs(amount - 1.0) > 0.001 else { return image }
        
        let filter = CIFilter.colorControls()
        filter.inputImage = image
        filter.saturation = amount
        filter.brightness = 0
        filter.contrast = 1
        
        return filter.outputImage ?? image
    }
    
    // MARK: - Split Toning
    
    /// Applies colour tinting to highlights and shadows separately.
    /// Creates the classic teal-and-orange or cool-shadow/warm-highlight look.
    private func applySplitToning(
        _ image: CIImage,
        highlightColor: CIColor,
        shadowColor: CIColor,
        highlightStrength: Float,
        shadowStrength: Float
    ) -> CIImage {
        guard highlightStrength > 0.001 || shadowStrength > 0.001 else { return image }
        
        var result = image
        
        // Shadow toning: blend shadow colour into dark areas
        if shadowStrength > 0.001 {
            let shadowTint = CIImage(color: shadowColor).cropped(to: image.extent)
            
            let multiply = CIFilter.multiplyCompositing()
            multiply.inputImage = shadowTint
            multiply.backgroundImage = result
            
            if let tinted = multiply.outputImage {
                result = blendImages(base: result, overlay: tinted, amount: shadowStrength * 0.3)
            }
        }
        
        // Highlight toning: blend highlight colour into bright areas
        if highlightStrength > 0.001 {
            let highlightTint = CIImage(color: highlightColor).cropped(to: image.extent)
            
            let screen = CIFilter.screenBlendMode()
            screen.inputImage = highlightTint
            screen.backgroundImage = result
            
            if let tinted = screen.outputImage {
                result = blendImages(base: result, overlay: tinted, amount: highlightStrength * 0.25)
            }
        }
        
        return result
    }
    
    // MARK: - LUT Application
    
    /// Applies a 3D LUT via CIColorCubeWithColorSpace for accurate grading.
    /// LUT data is cached after first parse for realtime performance.
    func applyLUT(_ image: CIImage, lutData: LUTData, intensity: Float = 1.0) -> CIImage {
        guard intensity > 0.001 else { return image }
        
        let cacheKey = "\(lutData.size)_\(lutData.table.count)"
        
        let cubeData: Data
        if let cached = lutCache[cacheKey] {
            cubeData = cached
        } else {
            cubeData = generateColorCubeData(from: lutData)
            lutCache[cacheKey] = cubeData
        }
        
        guard let filter = CIFilter(name: "CIColorCubeWithColorSpace") else {
            return image
        }
        
        filter.setValue(image, forKey: kCIInputImageKey)
        filter.setValue(lutData.size, forKey: "inputCubeDimension")
        filter.setValue(cubeData, forKey: "inputCubeData")
        filter.setValue(CGColorSpaceCreateDeviceRGB(), forKey: "inputColorSpace")
        
        guard let lutResult = filter.outputImage else { return image }
        
        if intensity < 0.999 {
            return blendImages(base: image, overlay: lutResult, amount: intensity)
        }
        
        return lutResult
    }
    
    // MARK: - Look Blending / Transitions
    
    /// Interpolates between two cinematic looks for smooth transitions.
    /// - Parameters:
    ///   - from: Source look parameters.
    ///   - to: Destination look parameters.
    ///   - progress: Interpolation factor (0 = from, 1 = to).
    /// - Returns: A blended CinematicLook with interpolated parameters.
    func interpolateLooks(
        from: CinematicLook,
        to: CinematicLook,
        progress: Float
    ) -> CinematicLook {
        let t = max(0.0, min(1.0, progress))
        let inv = 1.0 - t
        
        return CinematicLook(
            id: to.id,
            name: t < 0.5 ? from.name : to.name,
            category: to.category,
            character: t < 0.5 ? from.character : to.character,
            warmth: from.warmth * inv + to.warmth * t,
            tint: from.tint * inv + to.tint * t,
            saturation: from.saturation * inv + to.saturation * t,
            contrast: from.contrast * inv + to.contrast * t,
            highlightRolloff: from.highlightRolloff * inv + to.highlightRolloff * t,
            shadowLift: from.shadowLift * inv + to.shadowLift * t,
            bloomIntensity: from.bloomIntensity * inv + to.bloomIntensity * t,
            halationIntensity: from.halationIntensity * inv + to.halationIntensity * t,
            grainIntensity: from.grainIntensity * inv + to.grainIntensity * t,
            grainSize: from.grainSize * inv + to.grainSize * t,
            shadowTintR: from.shadowTintR * inv + to.shadowTintR * t,
            shadowTintG: from.shadowTintG * inv + to.shadowTintG * t,
            shadowTintB: from.shadowTintB * inv + to.shadowTintB * t,
            highlightTintR: from.highlightTintR * inv + to.highlightTintR * t,
            highlightTintG: from.highlightTintG * inv + to.highlightTintG * t,
            highlightTintB: from.highlightTintB * inv + to.highlightTintB * t,
            lutFileReference: t < 0.5 ? from.lutFileReference : to.lutFileReference,
            lutIntensity: from.lutIntensity * inv + to.lutIntensity * t
        )
    }
    
    /// Begins a smooth transition between two looks over a given duration.
    func beginTransition(from: CinematicLook, to: CinematicLook, duration: TimeInterval) {
        transitionState = LookTransitionState(
            fromLook: from,
            toLook: to,
            duration: duration,
            startTime: CACurrentMediaTime()
        )
    }
    
    /// Returns the current interpolated look during a transition.
    /// Returns nil if no transition is active.
    func currentTransitionLook() -> CinematicLook? {
        guard let state = transitionState else { return nil }
        
        let elapsed = CACurrentMediaTime() - state.startTime
        let progress = Float(min(elapsed / state.duration, 1.0))
        
        if progress >= 1.0 {
            transitionState = nil
            return state.toLook
        }
        
        // Ease-in-out cubic for smooth transitions
        let eased = easeCubic(progress)
        return interpolateLooks(from: state.fromLook, to: state.toLook, progress: eased)
    }
    
    /// Whether a look transition is currently in progress.
    var isTransitioning: Bool {
        return transitionState != nil
    }
    
    // MARK: - Cache Management
    
    /// Clears the LUT colour cube cache.
    func clearCache() {
        lutCache.removeAll()
    }
    
    /// Pre-caches LUT data for instant switching.
    func precacheLUT(_ lutData: LUTData) {
        let cacheKey = "\(lutData.size)_\(lutData.table.count)"
        if lutCache[cacheKey] == nil {
            lutCache[cacheKey] = generateColorCubeData(from: lutData)
        }
    }
    
    // MARK: - Private Helpers
    
    /// Generates packed RGBA float data for CIColorCube from LUTData.
    private func generateColorCubeData(from lutData: LUTData) -> Data {
        let size = lutData.size
        let count = size * size * size
        var floatData = [Float](repeating: 0, count: count * 4)
        
        for i in 0..<min(count, lutData.table.count) {
            let rgb = lutData.table[i]
            floatData[i * 4 + 0] = rgb.x  // R
            floatData[i * 4 + 1] = rgb.y  // G
            floatData[i * 4 + 2] = rgb.z  // B
            floatData[i * 4 + 3] = 1.0    // A
        }
        
        return Data(bytes: floatData, count: floatData.count * MemoryLayout<Float>.size)
    }
    
    /// Blends two CIImages using dissolve.
    private func blendImages(base: CIImage, overlay: CIImage, amount: Float) -> CIImage {
        let filter = CIFilter.dissolveTransition()
        filter.inputImage = base
        filter.targetImage = overlay
        filter.time = amount
        return filter.outputImage ?? overlay
    }
    
    /// Interpolates between two CIColors.
    private func interpolateColor(_ a: CIColor, _ b: CIColor, t: Float) -> CIColor {
        let inv = CGFloat(1.0 - t)
        let tCG = CGFloat(t)
        return CIColor(
            red: a.red * inv + b.red * tCG,
            green: a.green * inv + b.green * tCG,
            blue: a.blue * inv + b.blue * tCG,
            alpha: a.alpha * inv + b.alpha * tCG
        )
    }
    
    /// Cubic ease-in-out for smooth transitions.
    private func easeCubic(_ t: Float) -> Float {
        if t < 0.5 {
            return 4.0 * t * t * t
        } else {
            let f = 2.0 * t - 2.0
            return 0.5 * f * f * f + 1.0
        }
    }
}

// MARK: - LookTransitionState

/// Internal state for smooth look transitions.
private struct LookTransitionState {
    let fromLook: CinematicLook
    let toLook: CinematicLook
    let duration: TimeInterval
    let startTime: TimeInterval
}
