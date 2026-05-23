//
//  MetalDoFProcessor.swift
//  FilmsPage
//
//  Swift wrapper for the CinematicDoFShader Metal kernels.
//  Manages pipeline states, texture allocation, and provides
//  both full-quality (2-pass) and preview (1-pass) DoF modes.
//

import Metal
import MetalKit
import CoreImage

// MARK: - DoF Quality Mode

enum DoFQualityMode {
    case preview    // Single-pass quick blur
    case highQuality // Two-pass CoC + gather blur
}

// MARK: - MetalDoFProcessor

final class MetalDoFProcessor {
    
    // MARK: - Properties
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let cocPipeline: MTLComputePipelineState
    private let blurPipeline: MTLComputePipelineState
    private let quickPipeline: MTLComputePipelineState
    
    /// Intermediate CoC texture (reused across frames)
    private var cocTexture: MTLTexture?
    private var cachedWidth: Int = 0
    private var cachedHeight: Int = 0
    
    // MARK: - Uniforms
    
    struct DoFUniforms {
        var focalLengthMM: Float = 50.0
        var aperture: Float = 2.8
        var focusDistanceM: Float = 3.0
        var sensorWidthMM: Float = 36.0
        var imageWidth: Float = 1920
        var imageHeight: Float = 1080
        var maxBlurRadius: Float = 20.0
        var bokehRoundness: Float = 0.85
        var cocScale: Float = 1.0
        var foregroundBleed: Float = 0.3
    }
    
    // MARK: - Init
    
    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary() else {
            return nil
        }
        
        self.device = device
        self.commandQueue = queue
        
        guard let cocFunc = library.makeFunction(name: "computeCoC"),
              let blurFunc = library.makeFunction(name: "applyDoFBlur"),
              let quickFunc = library.makeFunction(name: "applyQuickDoF") else {
            return nil
        }
        
        do {
            self.cocPipeline = try device.makeComputePipelineState(function: cocFunc)
            self.blurPipeline = try device.makeComputePipelineState(function: blurFunc)
            self.quickPipeline = try device.makeComputePipelineState(function: quickFunc)
        } catch {
            print("❌ DoF pipeline creation failed: \(error)")
            return nil
        }
    }
    
    // MARK: - Process
    
    /// Applies depth-of-field blur to the source texture.
    func process(
        source: MTLTexture,
        depth: MTLTexture?,
        output: MTLTexture,
        focalLengthMM: Float,
        aperture: Float,
        focusDistanceM: Float,
        sensorWidthMM: Float,
        quality: DoFQualityMode = .preview
    ) {
        let width = source.width
        let height = source.height
        
        var uniforms = DoFUniforms(
            focalLengthMM: focalLengthMM,
            aperture: aperture,
            focusDistanceM: focusDistanceM,
            sensorWidthMM: sensorWidthMM,
            imageWidth: Float(width),
            imageHeight: Float(height),
            maxBlurRadius: quality == .preview ? 12.0 : 24.0,
            bokehRoundness: 0.85,
            cocScale: 1.0,
            foregroundBleed: 0.3
        )
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        
        let threadgroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadgroups = MTLSize(
            width: (width + 15) / 16,
            height: (height + 15) / 16,
            depth: 1
        )
        
        switch quality {
        case .preview:
            // Single-pass quick DoF
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
            encoder.setComputePipelineState(quickPipeline)
            encoder.setTexture(source, index: 0)
            encoder.setTexture(output, index: 1)
            encoder.setBytes(&uniforms, length: MemoryLayout<DoFUniforms>.stride, index: 0)
            encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
            encoder.endEncoding()
            
        case .highQuality:
            // Ensure intermediate texture
            ensureCoCTexture(width: width, height: height)
            guard let cocTex = cocTexture else { return }
            
            let depthSource = depth ?? source // Fallback to source luminance if no depth
            
            // Pass 1: Compute CoC map
            if let encoder = commandBuffer.makeComputeCommandEncoder() {
                encoder.setComputePipelineState(cocPipeline)
                encoder.setTexture(depthSource, index: 0)
                encoder.setTexture(cocTex, index: 1)
                encoder.setBytes(&uniforms, length: MemoryLayout<DoFUniforms>.stride, index: 0)
                encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
                encoder.endEncoding()
            }
            
            // Pass 2: Gather blur
            if let encoder = commandBuffer.makeComputeCommandEncoder() {
                encoder.setComputePipelineState(blurPipeline)
                encoder.setTexture(source, index: 0)
                encoder.setTexture(cocTex, index: 1)
                encoder.setTexture(output, index: 2)
                encoder.setBytes(&uniforms, length: MemoryLayout<DoFUniforms>.stride, index: 0)
                encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupSize)
                encoder.endEncoding()
            }
        }
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    // MARK: - Texture Management
    
    private func ensureCoCTexture(width: Int, height: Int) {
        guard width != cachedWidth || height != cachedHeight else { return }
        
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba16Float,
            width: width,
            height: height,
            mipmapped: false
        )
        desc.usage = [.shaderRead, .shaderWrite]
        desc.storageMode = .private
        
        cocTexture = device.makeTexture(descriptor: desc)
        cachedWidth = width
        cachedHeight = height
    }
}
