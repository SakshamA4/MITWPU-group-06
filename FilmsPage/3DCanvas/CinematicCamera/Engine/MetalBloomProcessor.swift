//
//  MetalBloomProcessor.swift
//  FilmsPage
//
//  Swift wrapper for the CinematicBloomShader Metal compute kernels.
//  Manages two-pass bloom pipeline: extract+blurH → blurV+composite.
//

import Foundation
import Metal

// MARK: - MetalBloomProcessor

/// Manages the two-pass Metal bloom/halation/grain pipeline.
final class MetalBloomProcessor {
    
    // MARK: - Properties
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let extractBlurHPipeline: MTLComputePipelineState
    private let blurVCompositePipeline: MTLComputePipelineState
    private let uniformBuffer: MTLBuffer
    
    /// Intermediate texture for the horizontal blur pass.
    private var intermediateTexture: MTLTexture?
    private var lastWidth: Int = 0
    private var lastHeight: Int = 0
    
    let isAvailable: Bool
    
    // MARK: - Uniform Mirror
    
    struct BloomUniforms {
        var bloomStrength: Float = 0.3
        var bloomThreshold: Float = 0.7
        var bloomRadius: Float = 8.0
        var halationStrength: Float = 0
        var halationRadius: Float = 16.0
        var grainIntensity: Float = 0
        var grainSize: Float = 1.5
        var time: Float = 0
        var exposureBoost: Float = 0
        var padding1: Float = 0
        var padding2: Float = 0
        var padding3: Float = 0
    }
    
    // MARK: - Initialisation
    
    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary(),
              let extractFn = library.makeFunction(name: "bloomExtractAndBlurH"),
              let compositeFn = library.makeFunction(name: "bloomBlurVAndComposite"),
              let extractPipeline = try? device.makeComputePipelineState(function: extractFn),
              let compositePipeline = try? device.makeComputePipelineState(function: compositeFn) else {
            self.device = MTLCreateSystemDefaultDevice()!
            self.commandQueue = self.device.makeCommandQueue()!
            self.extractBlurHPipeline = try! self.device.makeComputePipelineState(
                function: self.device.makeDefaultLibrary()!.makeFunction(name: "")!
            )
            self.blurVCompositePipeline = self.extractBlurHPipeline
            self.uniformBuffer = self.device.makeBuffer(length: 1)!
            self.isAvailable = false
            return nil
        }
        
        self.device = device
        self.commandQueue = queue
        self.extractBlurHPipeline = extractPipeline
        self.blurVCompositePipeline = compositePipeline
        
        let uniformSize = MemoryLayout<BloomUniforms>.stride
        guard let buffer = device.makeBuffer(length: uniformSize, options: .storageModeShared) else {
            self.uniformBuffer = device.makeBuffer(length: 1)!
            self.isAvailable = false
            return nil
        }
        self.uniformBuffer = buffer
        self.isAvailable = true
    }
    
    // MARK: - Processing
    
    /// Processes bloom, halation, and grain in two GPU passes.
    /// - Parameters:
    ///   - inputTexture: Source texture (post lens-processing).
    ///   - outputTexture: Final composited output.
    ///   - uniforms: Bloom/halation/grain parameters.
    /// - Returns: True if processing succeeded.
    @discardableResult
    func process(
        inputTexture: MTLTexture,
        outputTexture: MTLTexture,
        uniforms: BloomUniforms
    ) -> Bool {
        guard isAvailable else { return false }
        
        // Ensure intermediate texture exists and matches dimensions
        let width = inputTexture.width
        let height = inputTexture.height
        if intermediateTexture == nil || lastWidth != width || lastHeight != height {
            intermediateTexture = makeIntermediateTexture(width: width, height: height)
            lastWidth = width
            lastHeight = height
        }
        
        guard let intermediate = intermediateTexture else { return false }
        
        // Update uniforms
        var mutableUniforms = uniforms
        memcpy(uniformBuffer.contents(), &mutableUniforms, MemoryLayout<BloomUniforms>.stride)
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return false }
        
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroups = MTLSize(
            width: (width + 15) / 16,
            height: (height + 15) / 16,
            depth: 1
        )
        
        // Pass 1: Extract bright pixels + horizontal blur
        if let encoder = commandBuffer.makeComputeCommandEncoder() {
            encoder.setComputePipelineState(extractBlurHPipeline)
            encoder.setTexture(inputTexture, index: 0)
            encoder.setTexture(intermediate, index: 1)
            encoder.setBuffer(uniformBuffer, offset: 0, index: 0)
            encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
            encoder.endEncoding()
        }
        
        // Pass 2: Vertical blur + composite with original
        if let encoder = commandBuffer.makeComputeCommandEncoder() {
            encoder.setComputePipelineState(blurVCompositePipeline)
            encoder.setTexture(inputTexture, index: 0)    // Original
            encoder.setTexture(intermediate, index: 1)     // Bloom H-blurred
            encoder.setTexture(outputTexture, index: 2)    // Final output
            encoder.setBuffer(uniformBuffer, offset: 0, index: 0)
            encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
            encoder.endEncoding()
        }
        
        commandBuffer.commit()
        return true
    }
    
    /// Synchronous processing — waits for GPU completion.
    @discardableResult
    func processSync(
        inputTexture: MTLTexture,
        outputTexture: MTLTexture,
        uniforms: BloomUniforms
    ) -> Bool {
        guard isAvailable else { return false }
        
        let width = inputTexture.width
        let height = inputTexture.height
        if intermediateTexture == nil || lastWidth != width || lastHeight != height {
            intermediateTexture = makeIntermediateTexture(width: width, height: height)
            lastWidth = width
            lastHeight = height
        }
        
        guard let intermediate = intermediateTexture else { return false }
        
        var mutableUniforms = uniforms
        memcpy(uniformBuffer.contents(), &mutableUniforms, MemoryLayout<BloomUniforms>.stride)
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return false }
        
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroups = MTLSize(
            width: (width + 15) / 16,
            height: (height + 15) / 16,
            depth: 1
        )
        
        if let encoder = commandBuffer.makeComputeCommandEncoder() {
            encoder.setComputePipelineState(extractBlurHPipeline)
            encoder.setTexture(inputTexture, index: 0)
            encoder.setTexture(intermediate, index: 1)
            encoder.setBuffer(uniformBuffer, offset: 0, index: 0)
            encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
            encoder.endEncoding()
        }
        
        if let encoder = commandBuffer.makeComputeCommandEncoder() {
            encoder.setComputePipelineState(blurVCompositePipeline)
            encoder.setTexture(inputTexture, index: 0)
            encoder.setTexture(intermediate, index: 1)
            encoder.setTexture(outputTexture, index: 2)
            encoder.setBuffer(uniformBuffer, offset: 0, index: 0)
            encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
            encoder.endEncoding()
        }
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        return true
    }
    
    // MARK: - Uniform Helpers
    
    /// Creates bloom uniforms from a CinematicLook.
    static func makeUniforms(
        from look: CinematicLook,
        time: Float = 0
    ) -> BloomUniforms {
        return BloomUniforms(
            bloomStrength: look.bloomIntensity,
            bloomThreshold: 0.65,
            bloomRadius: 8.0 + look.bloomIntensity * 12.0,
            halationStrength: look.halationIntensity,
            halationRadius: 16.0 + look.halationIntensity * 16.0,
            grainIntensity: look.grainIntensity,
            grainSize: look.grainSize,
            time: time,
            exposureBoost: 0,
            padding1: 0,
            padding2: 0,
            padding3: 0
        )
    }
    
    // MARK: - Private
    
    private func makeIntermediateTexture(width: Int, height: Int) -> MTLTexture? {
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
}
