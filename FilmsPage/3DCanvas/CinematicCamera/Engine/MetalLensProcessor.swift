//
//  MetalLensProcessor.swift
//  FilmsPage
//
//  Swift wrapper for the CinematicLensShader Metal compute kernel.
//  Manages pipeline state, uniform buffers, and texture dispatch
//  for realtime lens simulation processing.
//

import Foundation
import Metal
import MetalKit

// MARK: - MetalLensProcessor

/// Manages Metal compute pipeline for cinematic lens distortion processing.
/// Thread-safe for use from the render loop.
final class MetalLensProcessor {
    
    // MARK: - Properties
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLComputePipelineState
    private let uniformBuffer: MTLBuffer
    
    /// Whether the processor initialised successfully.
    let isAvailable: Bool
    
    // MARK: - Uniform Mirror
    
    /// CPU-side uniform struct matching the Metal shader layout.
    /// Must match LensUniforms in CinematicLensShader.metal exactly.
    struct LensUniforms {
        var distortionK1: Float = 0
        var distortionK2: Float = 0
        var vignetteStrength: Float = 0
        var vignetteStart: Float = 0.6
        var edgeSoftness: Float = 0
        var chromaticAberration: Float = 0
        var breathingShift: Float = 0
        var bloomStrength: Float = 0
        var halationStrength: Float = 0
        var flareIntensity: Float = 0
        var anamorphicSqueeze: Float = 1.0
        var anamorphicStreak: Float = 0
        var grainAmount: Float = 0
        var aspectRatio: Float = 1.778
        var sensorCropX: Float = 1.0
        var sensorCropY: Float = 1.0
    }
    
    // MARK: - Initialisation
    
    init?() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            self.device = MTLCreateSystemDefaultDevice()!
            self.commandQueue = self.device.makeCommandQueue()!
            self.pipelineState = try! self.device.makeComputePipelineState(
                function: self.device.makeDefaultLibrary()!.makeFunction(name: "")!
            )
            self.uniformBuffer = self.device.makeBuffer(length: 1)!
            self.isAvailable = false
            return nil
        }
        
        self.device = device
        
        guard let queue = device.makeCommandQueue() else {
            self.commandQueue = device.makeCommandQueue()!
            self.pipelineState = try! device.makeComputePipelineState(
                function: device.makeDefaultLibrary()!.makeFunction(name: "")!
            )
            self.uniformBuffer = device.makeBuffer(length: 1)!
            self.isAvailable = false
            return nil
        }
        self.commandQueue = queue
        
        guard let library = device.makeDefaultLibrary(),
              let function = library.makeFunction(name: "cinematicLensKernel"),
              let pipeline = try? device.makeComputePipelineState(function: function) else {
            self.pipelineState = try! device.makeComputePipelineState(
                function: device.makeDefaultLibrary()!.makeFunction(name: "cinematicLensKernel")!
            )
            self.uniformBuffer = device.makeBuffer(length: 1)!
            self.isAvailable = false
            return nil
        }
        
        self.pipelineState = pipeline
        
        let uniformSize = MemoryLayout<LensUniforms>.stride
        guard let buffer = device.makeBuffer(length: uniformSize, options: .storageModeShared) else {
            self.uniformBuffer = device.makeBuffer(length: 1)!
            self.isAvailable = false
            return nil
        }
        self.uniformBuffer = buffer
        self.isAvailable = true
    }
    
    // MARK: - Processing
    
    /// Processes a texture through the lens simulation pipeline.
    /// - Parameters:
    ///   - inputTexture: Source texture from the render pipeline.
    ///   - outputTexture: Destination texture for processed result.
    ///   - uniforms: Lens simulation parameters.
    /// - Returns: True if processing was dispatched successfully.
    @discardableResult
    func process(
        inputTexture: MTLTexture,
        outputTexture: MTLTexture,
        uniforms: LensUniforms
    ) -> Bool {
        guard isAvailable else { return false }
        
        // Update uniform buffer
        var mutableUniforms = uniforms
        memcpy(uniformBuffer.contents(), &mutableUniforms, MemoryLayout<LensUniforms>.stride)
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return false
        }
        
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(inputTexture, index: 0)
        encoder.setTexture(outputTexture, index: 1)
        encoder.setBuffer(uniformBuffer, offset: 0, index: 0)
        
        // Calculate threadgroup sizes
        let threadgroupSize = MTLSize(
            width: min(16, pipelineState.maxTotalThreadsPerThreadgroup),
            height: min(16, pipelineState.maxTotalThreadsPerThreadgroup / 16),
            depth: 1
        )
        
        let threadgroups = MTLSize(
            width: (outputTexture.width + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (outputTexture.height + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )
        
        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()
        commandBuffer.commit()
        
        return true
    }
    
    /// Synchronous processing — waits for GPU completion.
    /// Use only for export/screenshot, not realtime preview.
    @discardableResult
    func processSync(
        inputTexture: MTLTexture,
        outputTexture: MTLTexture,
        uniforms: LensUniforms
    ) -> Bool {
        guard isAvailable else { return false }
        
        var mutableUniforms = uniforms
        memcpy(uniformBuffer.contents(), &mutableUniforms, MemoryLayout<LensUniforms>.stride)
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return false
        }
        
        encoder.setComputePipelineState(pipelineState)
        encoder.setTexture(inputTexture, index: 0)
        encoder.setTexture(outputTexture, index: 1)
        encoder.setBuffer(uniformBuffer, offset: 0, index: 0)
        
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroups = MTLSize(
            width: (outputTexture.width + threadgroupSize.width - 1) / threadgroupSize.width,
            height: (outputTexture.height + threadgroupSize.height - 1) / threadgroupSize.height,
            depth: 1
        )
        
        encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return true
    }
    
    // MARK: - Texture Creation
    
    /// Creates a texture suitable for lens processing output.
    func makeOutputTexture(width: Int, height: Int) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .private
        return device.makeTexture(descriptor: descriptor)
    }
    
    // MARK: - Uniform Helpers
    
    /// Creates uniforms from a LensOpticalProfile and additional parameters.
    static func makeUniforms(
        from profile: LensOpticalProfile,
        anamorphicSqueeze: Float = 1.0,
        breathingShift: Float = 0.0,
        sensorCropX: Float = 1.0,
        sensorCropY: Float = 1.0,
        aspectRatio: Float = 1.778
    ) -> LensUniforms {
        return LensUniforms(
            distortionK1: profile.distortionK1,
            distortionK2: profile.distortionK2,
            vignetteStrength: profile.vignetteStrength,
            vignetteStart: profile.vignetteFalloffStart,
            edgeSoftness: profile.edgeSoftness,
            chromaticAberration: profile.chromaticAberration,
            breathingShift: breathingShift,
            bloomStrength: profile.bloomStrength,
            halationStrength: profile.halationStrength,
            flareIntensity: profile.flareIntensity,
            anamorphicSqueeze: anamorphicSqueeze,
            anamorphicStreak: profile.anamorphicFlareStreak,
            grainAmount: 0,
            aspectRatio: aspectRatio,
            sensorCropX: sensorCropX,
            sensorCropY: sensorCropY
        )
    }
}
