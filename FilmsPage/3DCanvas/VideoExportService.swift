//
//  VideoExportService.swift
//  FilmsPage
//
//  Reusable AVAssetWriter-based MP4 export pipeline.
//  Supports single-shot and multi-shot (Export All) rendering.
//  Video-only, clean frames (no HUD overlays).
//

import AVFoundation
import UIKit
import RealityKit

// MARK: - Export Settings

struct ExportSettings {

    enum Resolution: String, CaseIterable, Identifiable {
        case hd720  = "720p"
        case hd1080 = "1080p"
        case uhd4K  = "4K"

        var id: String { rawValue }

        var size: CGSize {
            switch self {
            case .hd720:  return CGSize(width: 1280, height: 720)
            case .hd1080: return CGSize(width: 1920, height: 1080)
            case .uhd4K:  return CGSize(width: 3840, height: 2160)
            }
        }
    }

    enum FPS: Int, CaseIterable, Identifiable {
        case fps24 = 24
        case fps30 = 30
        case fps60 = 60

        var id: Int { rawValue }
        var label: String { "\(rawValue)" }
        var timescale: Int32 { Int32(rawValue) }
    }

    enum Quality: String, CaseIterable, Identifiable {
        case high   = "High"
        case medium = "Medium"

        var id: String { rawValue }

        /// AVVideoCompressionProperties bitrate multiplier
        var compressionQuality: Float {
            switch self {
            case .high:   return 1.0
            case .medium: return 0.6
            }
        }
    }

    var resolution: Resolution = .hd1080
    var fps: FPS = .fps24
    var quality: Quality = .high
}

// MARK: - Export Progress

struct ExportProgress {
    let currentShotIndex: Int
    let totalShots: Int
    let currentFrame: Int
    let totalFrames: Int
    let overallProgress: Float   // 0.0 – 1.0
    let shotName: String
}

// MARK: - VideoExportService

final class VideoExportService {

    // MARK: - Callbacks (set by caller before export)

    /// Positions all entities at the given master time.
    var evaluateTimeline: ((Float) -> Void)?

    /// Sets the active camera to the given item's POV.
    var prepareForCapture: ((CanvasViewController.SceneCameraItem?) -> Void)?

    /// Captures a frame from the given camera's POV.
    var captureFrameAsync: ((CanvasViewController.SceneCameraItem?,
                             @escaping (UIImage?) -> Void) -> Void)?

    /// Camera item lookup by shot.
    var cameraItemForShot: ((Shot) -> CanvasViewController.SceneCameraItem?)?

    /// Progress updates (called on main queue).
    var onProgress: ((ExportProgress) -> Void)?

    /// Completion (called on main queue). URL is nil on cancel/failure.
    var onComplete: ((URL?, Error?) -> Void)?

    // MARK: - State

    private var isCancelled = false
    private var writer: AVAssetWriter?

    // MARK: - Public API

    func cancel() {
        isCancelled = true
        writer?.cancelWriting()
    }

    /// Export a single shot to MP4.
    func exportShot(_ shot: Shot, settings: ExportSettings) {
        exportShots([shot], settings: settings, filePrefix: "Shot\(shot.index + 1)")
    }

    /// Export all shots sequentially into a single MP4.
    func exportAllShots(_ shots: [Shot], settings: ExportSettings) {
        exportShots(shots, settings: settings, filePrefix: "AllShots")
    }

    // MARK: - Core Pipeline

    private func exportShots(_ shots: [Shot], settings: ExportSettings, filePrefix: String) {
        isCancelled = false

        let size = settings.resolution.size
        let fps  = settings.fps.timescale

        // Compute total frames across all shots
        let shotFrameCounts = shots.map { max(1, Int(ceil($0.duration * Float(fps)))) }
        let totalFrames     = shotFrameCounts.reduce(0, +)

        // Output URL
        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(filePrefix)_\(Int(Date().timeIntervalSince1970)).mp4")
        try? FileManager.default.removeItem(at: outURL)

        // AVAssetWriter setup
        guard let writer = try? AVAssetWriter(outputURL: outURL, fileType: .mp4) else {
            DispatchQueue.main.async { self.onComplete?(nil, NSError(domain: "Export", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Could not create video writer."])) }
            return
        }
        self.writer = writer

        // Bitrate: base = 10 Mbps for 1080p @ 24fps, scale proportionally
        let pixelCount  = Float(size.width * size.height)
        let basePixels  = Float(1920 * 1080)
        let baseBitrate = Float(10_000_000)
        let bitrate     = baseBitrate * (pixelCount / basePixels)
                          * (Float(fps) / 24.0)
                          * settings.quality.compressionQuality

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: Int(bitrate),
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoMaxKeyFrameIntervalKey: fps * 2,  // keyframe every 2s
            ] as [String: Any],
        ]

        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey  as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height),
            ]
        )

        writer.add(videoInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        // Begin sequential render
        var globalFrameIndex = 0

        func renderShot(shotIdx: Int) {
            guard shotIdx < shots.count else {
                // All shots done — finalize
                videoInput.markAsFinished()
                writer.finishWriting { [weak self] in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        if self.isCancelled {
                            try? FileManager.default.removeItem(at: outURL)
                            self.onComplete?(nil, nil)
                        } else if writer.status == .completed {
                            self.onComplete?(outURL, nil)
                        } else {
                            self.onComplete?(nil, writer.error)
                        }
                    }
                }
                return
            }

            let shot       = shots[shotIdx]
            let frameCount = shotFrameCounts[shotIdx]

            // Set camera for this shot
            let camItem = self.cameraItemForShot?(shot)

            func renderFrame(localIdx: Int) {
                guard !self.isCancelled else {
                    videoInput.markAsFinished()
                    writer.cancelWriting()
                    try? FileManager.default.removeItem(at: outURL)
                    DispatchQueue.main.async { self.onComplete?(nil, nil) }
                    return
                }

                guard localIdx < frameCount else {
                    // This shot is done — move to next
                    renderShot(shotIdx: shotIdx + 1)
                    return
                }

                // Progress
                let progress = ExportProgress(
                    currentShotIndex: shotIdx,
                    totalShots: shots.count,
                    currentFrame: globalFrameIndex + 1,
                    totalFrames: totalFrames,
                    overallProgress: Float(globalFrameIndex) / Float(max(1, totalFrames)),
                    shotName: shot.displayName
                )
                DispatchQueue.main.async { self.onProgress?(progress) }

                // Evaluate timeline at this frame's time
                let masterTime = shot.startTime + Float(localIdx) / Float(fps)
                DispatchQueue.main.async {
                    self.evaluateTimeline?(masterTime)
                    self.prepareForCapture?(camItem)
                }

                // Capture frame (allow 1 frame for render pipeline to flush)
                let captureDelay: TimeInterval = 0.016  // ~1 frame at 60fps
                DispatchQueue.main.asyncAfter(deadline: .now() + captureDelay) { [weak self] in
                    guard let self = self, !self.isCancelled else { return }

                    let doCapture = self.captureFrameAsync ?? { _, cb in cb(nil) }
                    doCapture(camItem) { [weak self] image in
                        guard let self = self, !self.isCancelled else { return }

                        if let img = image, let pb = self.createPixelBuffer(from: img, size: size) {
                            // Wait for input to be ready
                            while !videoInput.isReadyForMoreMediaData {
                                Thread.sleep(forTimeInterval: 0.002)
                            }
                            let pts = CMTime(value: CMTimeValue(globalFrameIndex), timescale: fps)
                            adaptor.append(pb, withPresentationTime: pts)
                        }

                        globalFrameIndex += 1

                        // Render next frame on main queue
                        DispatchQueue.main.async {
                            renderFrame(localIdx: localIdx + 1)
                        }
                    }
                }
            }

            renderFrame(localIdx: 0)
        }

        renderShot(shotIdx: 0)
    }

    // MARK: - Pixel Buffer

    /// Optimized pixel buffer creation using BGRA (native Metal format).
    private func createPixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
        guard let cgImage = image.cgImage else { return nil }

        var pb: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width), Int(size.height),
            kCVPixelFormatType_32BGRA,
            attrs as CFDictionary,
            &pb
        )
        guard status == kCVReturnSuccess, let buf = pb else { return nil }

        CVPixelBufferLockBaseAddress(buf, [])
        defer { CVPixelBufferUnlockBaseAddress(buf, []) }

        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(buf),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buf),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue |
                        CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return nil }

        ctx.draw(cgImage, in: CGRect(origin: .zero, size: size))
        return buf
    }
}
