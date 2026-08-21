//
//  CinematicRenderPipeline.swift
//  FilmsPage
//
//  Central coordinator for the cinematic camera post-processing pipeline.
//  Orchestrates the full processing chain:
//    Sensor → Lens → Look → Bloom/Halation → Motion → Final Output
//
//  Integrates with both live preview (async) and export (sync) paths.
//  Thread-safe for use from the RealityKit render loop.
//

import Foundation
import Metal
import CoreImage
import UIKit
import simd

// MARK: - CinematicRenderPipeline

/// Central coordinator that orchestrates all cinematic post-processing.
/// Owns and manages the sub-engines (sensor, lens, look, bloom, motion)
/// and provides a unified interface for both preview and export rendering.
@MainActor
final class CinematicRenderPipeline {
    
    // MARK: - Sub-Engines
    
    let sensorEngine: SensorSimulationEngine
    let lensEngine: LensSimulationEngine
    let lookEngine: CinematicLookEngine
    let motionEngine: CameraMotionEngine
    
    /// Metal processors (nil if Metal is unavailable).
    private(set) var metalLensProcessor: MetalLensProcessor?
    private(set) var metalBloomProcessor: MetalBloomProcessor?
    
    /// CoreImage context shared across the pipeline.
    private let ciContext: CIContext
    
    // MARK: - State
    
    /// Current pipeline configuration snapshot.
    private(set) var currentConfig: PipelineConfiguration
    
    /// Whether Metal GPU processing is available.
    var isMetalAvailable: Bool {
        return metalLensProcessor?.isAvailable == true
    }
    
    /// Pipeline processing statistics for performance monitoring.
    private(set) var lastFrameStats: FrameStatistics = .zero
    
    // MARK: - Initialisation
    
    init() {
        self.sensorEngine = SensorSimulationEngine.shared
        self.lensEngine = LensSimulationEngine.shared
        self.lookEngine = CinematicLookEngine()
        self.motionEngine = CameraMotionEngine.shared
        self.currentConfig = PipelineConfiguration()
        
        // Create shared CIContext with Metal device if available
        if let device = MTLCreateSystemDefaultDevice() {
            self.ciContext = CIContext(mtlDevice: device, options: [
                .cacheIntermediates: false,
                .highQualityDownsample: true
            ])
        } else {
            self.ciContext = CIContext(options: [
                .useSoftwareRenderer: false,
                .cacheIntermediates: false
            ])
        }
        
        // Attempt to initialise Metal processors
        self.metalLensProcessor = MetalLensProcessor()
        self.metalBloomProcessor = MetalBloomProcessor()
    }
    
    // MARK: - Configuration
    
    /// Updates the pipeline configuration with new camera/lens/look selections.
    func configure(
        cameraBody: CinemaCameraBody? = nil,
        lensFamily: CinemaLensFamily? = nil,
        focalLength: Float? = nil,
        look: CinematicLook? = nil,
        motionStyle: CameraMotionStyle? = nil,
        aspectRatio: CinemaAspectRatioPreset? = nil
    ) {
        if let body = cameraBody {
            currentConfig.cameraBody = body
        }
        if let lens = lensFamily {
            currentConfig.lensFamily = lens
        }
        if let fl = focalLength {
            currentConfig.focalLength = fl
        }
        if let l = look {
            currentConfig.look = l
        }
        if let motion = motionStyle {
            currentConfig.motionStyle = motion
        }
        if let ar = aspectRatio {
            currentConfig.aspectRatio = ar
        }
        
        // Recalculate derived values
        recalculateDerivedValues()
    }
    
    // MARK: - FOV Calculation
    
    /// Returns the current effective FOV in degrees for RealityKit camera.
    /// Accounts for sensor size, focal length, crop factor, and breathing.
    func currentFOV(focusDistance: Float = 5.0) -> Float {
        guard let body = currentConfig.cameraBody else {
            return 60.0 // Default FOV
        }
        
        let sensor = body.sensor
        let focalLength = currentConfig.focalLength
        
        // Base FOV from sensor + focal length
        var fov = sensorEngine.horizontalFOV(
            sensorWidthMM: sensor.sensorWidthMM,
            focalLengthMM: focalLength
        )
        
        // Apply focus breathing if lens is configured
        if let lens = currentConfig.lensFamily {
            let profile = lens.opticalProfile(forFocalLength: focalLength)
            fov = sensorEngine.applyBreathing(
                baseFOV: fov,
                focusDistance: focusDistance,
                breathingAmount: profile.breathingAmount,
                mode: .cinematic
            )
        }
        
        return fov
    }
    
    // MARK: - Motion
    
    /// Returns the current camera motion offset for procedural shake.
    /// Call each frame with the current time to get smooth motion.
    func currentMotionOffset(time: TimeInterval) -> MotionOffset {
        return motionEngine.generateMotionOffset(
            style: currentConfig.motionStyle,
            time: Float(time),
            seed: 0
        )
    }
    
    // MARK: - Frame Processing (CoreImage Path)
    
    /// Processes a rendered frame through the full cinematic pipeline.
    /// Uses CoreImage for look processing, Metal for lens/bloom if available.
    /// - Parameters:
    ///   - image: Source CIImage from scene snapshot.
    ///   - time: Current animation time (for grain/motion variation).
    ///   - intensity: Overall cinematic effect intensity (0–1).
    /// - Returns: Processed CIImage ready for display.
    func processFrame(
        _ image: CIImage,
        time: TimeInterval,
        intensity: Float = 1.0
    ) -> CIImage {
        guard intensity > 0.001 else { return image }
        
        let startTime = CACurrentMediaTime()
        var result = image
        
        // 1. Apply cinematic look (warmth, contrast, saturation, etc.)
        if let look = currentConfig.look {
            let activeLook = lookEngine.isTransitioning
                ? (lookEngine.currentTransitionLook() ?? look)
                : look
            
            result = lookEngine.processLook(
                result,
                look: activeLook,
                lutData: currentConfig.activeLUTData,
                intensity: intensity
            )
        }
        
        // Record stats
        let endTime = CACurrentMediaTime()
        lastFrameStats = FrameStatistics(
            totalMs: (endTime - startTime) * 1000,
            lookProcessingMs: (endTime - startTime) * 1000,
            lensProcessingMs: 0,
            bloomProcessingMs: 0,
            isMetalAccelerated: isMetalAvailable
        )
        
        return result
    }
    
    // MARK: - Full Metal Processing
    
    /// Processes a frame through the full Metal pipeline (lens + bloom).
    /// For use when Metal textures are available directly.
    /// - Parameters:
    ///   - inputTexture: Source Metal texture.
    ///   - outputTexture: Destination Metal texture.
    ///   - time: Current time for animation.
    /// - Returns: True if processing succeeded.
    func processMetalFrame(
        inputTexture: MTLTexture,
        outputTexture: MTLTexture,
        time: Float
    ) -> Bool {
        guard isMetalAvailable else { return false }
        
        let startTime = CACurrentMediaTime()
        
        // Create intermediate texture for lens → bloom chain
        guard let lensOutput = metalLensProcessor?.makeOutputTexture(
            width: inputTexture.width,
            height: inputTexture.height
        ) else { return false }
        
        // Step 1: Lens distortion pass
        let lensUniforms = buildLensUniforms()
        let lensStart = CACurrentMediaTime()
        metalLensProcessor?.process(
            inputTexture: inputTexture,
            outputTexture: lensOutput,
            uniforms: lensUniforms
        )
        let lensEnd = CACurrentMediaTime()
        
        // Step 2: Bloom/halation/grain pass
        let bloomUniforms = buildBloomUniforms(time: time)
        let bloomStart = CACurrentMediaTime()
        metalBloomProcessor?.process(
            inputTexture: lensOutput,
            outputTexture: outputTexture,
            uniforms: bloomUniforms
        )
        let bloomEnd = CACurrentMediaTime()
        
        let endTime = CACurrentMediaTime()
        lastFrameStats = FrameStatistics(
            totalMs: (endTime - startTime) * 1000,
            lookProcessingMs: 0,
            lensProcessingMs: (lensEnd - lensStart) * 1000,
            bloomProcessingMs: (bloomEnd - bloomStart) * 1000,
            isMetalAccelerated: true
        )
        
        return true
    }
    
    // MARK: - Export Processing (Synchronous)
    
    /// Synchronously processes a frame for video export.
    /// Blocks until GPU processing is complete.
    func processFrameForExport(
        _ image: CIImage,
        time: TimeInterval
    ) -> UIImage? {
        let processed = processFrame(image, time: time, intensity: 1.0)
        
        let extent = processed.extent
        guard let cgImage = ciContext.createCGImage(processed, from: extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - Look Transitions
    
    /// Begins a smooth transition to a new cinematic look.
    func transitionToLook(_ newLook: CinematicLook, duration: TimeInterval = 0.5) {
        guard let currentLook = currentConfig.look else {
            currentConfig.look = newLook
            return
        }
        
        lookEngine.beginTransition(from: currentLook, to: newLook, duration: duration)
        currentConfig.look = newLook
    }
    
    // MARK: - Framing Information
    
    /// Returns the framing rect for the current sensor + aspect ratio combination.
    func framingRect(in viewportSize: CGSize) -> CGRect {
        guard let body = currentConfig.cameraBody else {
            return CGRect(origin: .zero, size: viewportSize)
        }
        
        let sensorAspect = body.sensor.sensorWidthMM / body.sensor.sensorHeightMM
        let targetAspect = currentConfig.aspectRatio.ratio
        
        return sensorEngine.calculateFramingRect(
            sensorAspect: sensorAspect,
            targetAspect: targetAspect,
            viewportSize: viewportSize
        )
    }
    
    /// Returns a human-readable summary of the current camera configuration.
    var configurationSummary: String {
        let camera = currentConfig.cameraBody?.modelName ?? "No Camera"
        let lens = currentConfig.lensFamily?.familyName ?? "No Lens"
        let fl = String(format: "%.0fmm", currentConfig.focalLength)
        let look = currentConfig.look?.name ?? "No Look"
        let ar = currentConfig.aspectRatio.displayName
        
        return "\(camera) • \(lens) \(fl) • \(look) • \(ar)"
    }
    
    // MARK: - Cache Management
    
    /// Clears all cached data (LUT caches, intermediate textures).
    func clearCaches() {
        lookEngine.clearCache()
    }
    
    // MARK: - Private Helpers
    
    private func recalculateDerivedValues() {
        // Recalculate crop factor relative to full frame
        if let body = currentConfig.cameraBody {
            currentConfig.effectiveCropFactor = sensorEngine.cropFactor(
                sensorWidthMM: body.sensor.sensorWidthMM
            )
        }
    }
    
    private func buildLensUniforms() -> MetalLensProcessor.LensUniforms {
        guard let lens = currentConfig.lensFamily else {
            return MetalLensProcessor.LensUniforms()
        }
        
        let profile = lens.opticalProfile(forFocalLength: currentConfig.focalLength)
        let squeeze: Float = lens.anamorphicMode.squeezeRatio
        
        return MetalLensProcessor.makeUniforms(
            from: profile,
            anamorphicSqueeze: squeeze,
            breathingShift: 0,
            sensorCropX: currentConfig.effectiveCropFactor,
            sensorCropY: currentConfig.effectiveCropFactor,
            aspectRatio: currentConfig.aspectRatio.ratio
        )
    }
    
    private func buildBloomUniforms(time: Float) -> MetalBloomProcessor.BloomUniforms {
        guard let look = currentConfig.look else {
            return MetalBloomProcessor.BloomUniforms()
        }
        
        return MetalBloomProcessor.makeUniforms(from: look, time: time)
    }
}

// MARK: - PipelineConfiguration

/// Snapshot of the current cinematic pipeline configuration.
struct PipelineConfiguration {
    var cameraBody: CinemaCameraBody?
    var lensFamily: CinemaLensFamily?
    var focalLength: Float = 50.0
    var look: CinematicLook?
    var motionStyle: CameraMotionStyle = .tripod
    var aspectRatio: CinemaAspectRatioPreset = .scope239
    var activeLUTData: LUTData?
    
    /// Derived: effective crop factor relative to full frame.
    var effectiveCropFactor: Float = 1.0
    
    /// Whether any cinematic processing is active.
    var isActive: Bool {
        return cameraBody != nil || lensFamily != nil || look != nil
    }
}

// MARK: - FrameStatistics

/// Performance metrics for a single processed frame.
struct FrameStatistics {
    let totalMs: Double
    let lookProcessingMs: Double
    let lensProcessingMs: Double
    let bloomProcessingMs: Double
    let isMetalAccelerated: Bool
    
    static let zero = FrameStatistics(
        totalMs: 0, lookProcessingMs: 0,
        lensProcessingMs: 0, bloomProcessingMs: 0,
        isMetalAccelerated: false
    )
    
    var debugDescription: String {
        let accel = isMetalAccelerated ? "Metal" : "CPU"
        return String(format: "Frame: %.1fms (Look: %.1f, Lens: %.1f, Bloom: %.1f) [%@]",
                      totalMs, lookProcessingMs, lensProcessingMs, bloomProcessingMs, accel)
    }
}
