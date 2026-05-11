//
//  VideoExportService.swift
//  FilmsPage
//
//  Reusable AVAssetWriter-based MP4 export pipeline.
//  Supports single-shot and multi-shot (Export All) rendering.
//  Video-only, clean frames (no HUD overlays).
//
//  OPTIMIZATION NOTES:
//  ───────────────────────────────────────────────────────────────────────
//  • All scene evaluation + capture happens synchronously on the main thread
//    so RealityKit's render pipeline is fully flushed before snapshot.
//  • Pixel buffer creation + AVAssetWriter append happen on a background
//    serial queue so the main thread is never blocked by I/O.
//  • For the ShotPlayer path (ARView visible), we use arView.snapshot()
//    directly — no scene cloning.
//  • A generous inter-frame yield (2 render frames) ensures RealityKit
//    has fully committed the scene state before capture.
//  ───────────────────────────────────────────────────────────────────────

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

    /// Positions all entities at the given master time. Called on main thread.
    var evaluateTimeline: ((Float) -> Void)?

    /// Sets the active camera to the given item's POV. Called on main thread.
    var prepareForCapture: ((CanvasViewController.SceneCameraItem?) -> Void)?

    /// Captures a frame. The closure captures from the live ARView directly.
    /// For export we prefer the direct arView.snapshot path.
    var captureFrameAsync: ((CanvasViewController.SceneCameraItem?,
                             @escaping (UIImage?) -> Void) -> Void)?

    /// Direct ARView reference for optimized snapshot path.
    weak var arView: ARView?

    /// Camera item lookup by shot.
    var cameraItemForShot: ((Shot) -> CanvasViewController.SceneCameraItem?)?

    /// Progress updates (called on main queue).
    var onProgress: ((ExportProgress) -> Void)?

    /// Completion (called on main queue). URL is nil on cancel/failure.
    var onComplete: ((URL?, Error?) -> Void)?

    // MARK: - State

    private var isCancelled = false
    private var writer: AVAssetWriter?

    /// Background serial queue for pixel buffer creation + disk writes.
    private let writeQueue = DispatchQueue(label: "com.filmspage.videoexport.write",
                                            qos: .userInitiated)

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
                AVVideoMaxKeyFrameIntervalKey: fps * 2,
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

        print("🎬 Export started: \(shots.count) shots, \(totalFrames) frames, \(settings.resolution.rawValue) @ \(settings.fps.rawValue)fps")

        // ── Sequential frame render ──────────────────────────────────────────
        //
        // Pattern: main thread evaluates scene → waits 2 frames for RealityKit
        // to flush → captures snapshot → sends image to background writeQueue
        // for pixel buffer creation + AVAssetWriter append → signals main thread
        // to render next frame.
        //
        // This avoids:
        //  • Thread.sleep on main thread
        //  • Scene cloning per frame
        //  • Race conditions between evaluate and capture

        var globalFrameIndex = 0
        var lastCamItem: CanvasViewController.SceneCameraItem?

        func renderShot(shotIdx: Int) {
            guard !self.isCancelled else { self.finishCancelled(writer, outURL); return }
            guard shotIdx < shots.count else {
                self.finishWriting(writer, videoInput, outURL)
                return
            }

            let shot       = shots[shotIdx]
            let frameCount = shotFrameCounts[shotIdx]
            let camItem    = self.cameraItemForShot?(shot)
            lastCamItem    = camItem

            // Set camera once per shot (not per frame)
            self.prepareForCapture?(camItem)

            renderFrame(localIdx: 0, shot: shot, shotIdx: shotIdx,
                        frameCount: frameCount, camItem: camItem,
                        fps: fps, size: size, totalFrames: totalFrames,
                        shots: shots, shotFrameCounts: shotFrameCounts,
                        globalFrameIndex: &globalFrameIndex,
                        videoInput: videoInput, adaptor: adaptor,
                        writer: writer, outURL: outURL,
                        nextShot: { renderShot(shotIdx: shotIdx + 1) })
        }

        // Kick off on main thread
        DispatchQueue.main.async { renderShot(shotIdx: 0) }
    }

    // MARK: - Per-Frame Render (runs on main thread)

    private func renderFrame(
        localIdx: Int, shot: Shot, shotIdx: Int,
        frameCount: Int, camItem: CanvasViewController.SceneCameraItem?,
        fps: Int32, size: CGSize, totalFrames: Int,
        shots: [Shot], shotFrameCounts: [Int],
        globalFrameIndex: inout Int,
        videoInput: AVAssetWriterInput,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        writer: AVAssetWriter, outURL: URL,
        nextShot: @escaping () -> Void
    ) {
        guard !isCancelled else { finishCancelled(writer, outURL); return }
        guard localIdx < frameCount else { nextShot(); return }

        // Capture the current global index by value (avoid inout in escaping closure)
        let currentGlobalIdx = globalFrameIndex
        globalFrameIndex += 1

        // 1. Report progress
        let progress = ExportProgress(
            currentShotIndex: shotIdx,
            totalShots: shots.count,
            currentFrame: currentGlobalIdx + 1,
            totalFrames: totalFrames,
            overallProgress: Float(currentGlobalIdx) / Float(max(1, totalFrames)),
            shotName: shot.displayName
        )
        onProgress?(progress)

        // 2. Evaluate timeline (synchronous on main thread)
        let masterTime = shot.startTime + Float(localIdx) / Float(fps)
        evaluateTimeline?(masterTime)

        // 3. Wait 2 render frames (~33ms) for RealityKit to fully commit the scene.
        //    This is the key optimization — we do NOT block; we yield to the run loop.
        let renderDelay: TimeInterval = 0.035

        DispatchQueue.main.asyncAfter(deadline: .now() + renderDelay) { [weak self] in
            guard let self = self, !self.isCancelled else {
                self?.finishCancelled(writer, outURL)
                return
            }

            // 4. Capture frame using direct ARView snapshot (avoids scene cloning!)
            self.captureCurrentFrame(camItem: camItem) { [weak self] image in
                guard let self = self, !self.isCancelled else { return }

                // 5. Pixel buffer creation + write on background queue
                //    This frees the main thread immediately for the next frame.
                self.writeQueue.async { [weak self] in
                    guard let self = self, !self.isCancelled else { return }

                    if let img = image {
                        if let pb = self.createPixelBuffer(from: img, size: size) {
                            // Wait for writer to be ready (background queue — safe to block here)
                            var waitCount = 0
                            while !videoInput.isReadyForMoreMediaData {
                                Thread.sleep(forTimeInterval: 0.005)
                                waitCount += 1
                                if waitCount > 200 { break }  // 1s timeout
                            }
                            let pts = CMTime(value: CMTimeValue(currentGlobalIdx), timescale: fps)
                            adaptor.append(pb, withPresentationTime: pts)
                        }
                    } else {
                        // Frame capture failed — append a black frame to maintain timing
                        if let pb = self.createBlackPixelBuffer(size: size) {
                            var waitCount = 0
                            while !videoInput.isReadyForMoreMediaData {
                                Thread.sleep(forTimeInterval: 0.005)
                                waitCount += 1
                                if waitCount > 200 { break }
                            }
                            let pts = CMTime(value: CMTimeValue(currentGlobalIdx), timescale: fps)
                            adaptor.append(pb, withPresentationTime: pts)
                        }
                    }

                    // 6. Schedule next frame back on main thread
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        // Use a local mutable copy for the recursive call
                        var nextGlobalIdx = currentGlobalIdx + 1
                        // We already incremented before entering the closure,
                        // so just pass the next local index
                        self.renderFrameTrampoline(
                            localIdx: localIdx + 1, shot: shot, shotIdx: shotIdx,
                            frameCount: frameCount, camItem: camItem,
                            fps: fps, size: size, totalFrames: totalFrames,
                            shots: shots, shotFrameCounts: shotFrameCounts,
                            globalFrameIndex: nextGlobalIdx,
                            videoInput: videoInput, adaptor: adaptor,
                            writer: writer, outURL: outURL,
                            nextShot: nextShot
                        )
                    }
                }
            }
        }
    }

    /// Trampoline to avoid `inout` in escaping closures.
    /// Takes globalFrameIndex by value and manages it internally.
    private func renderFrameTrampoline(
        localIdx: Int, shot: Shot, shotIdx: Int,
        frameCount: Int, camItem: CanvasViewController.SceneCameraItem?,
        fps: Int32, size: CGSize, totalFrames: Int,
        shots: [Shot], shotFrameCounts: [Int],
        globalFrameIndex: Int,
        videoInput: AVAssetWriterInput,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        writer: AVAssetWriter, outURL: URL,
        nextShot: @escaping () -> Void
    ) {
        guard !isCancelled else { finishCancelled(writer, outURL); return }
        guard localIdx < frameCount else { nextShot(); return }

        let currentGlobalIdx = globalFrameIndex

        // 1. Report progress
        let progress = ExportProgress(
            currentShotIndex: shotIdx,
            totalShots: shots.count,
            currentFrame: currentGlobalIdx + 1,
            totalFrames: totalFrames,
            overallProgress: Float(currentGlobalIdx) / Float(max(1, totalFrames)),
            shotName: shot.displayName
        )
        onProgress?(progress)

        // 2. Evaluate timeline
        let masterTime = shot.startTime + Float(localIdx) / Float(fps)
        evaluateTimeline?(masterTime)

        // 3. Wait for render
        let renderDelay: TimeInterval = 0.035

        DispatchQueue.main.asyncAfter(deadline: .now() + renderDelay) { [weak self] in
            guard let self = self, !self.isCancelled else {
                self?.finishCancelled(writer, outURL)
                return
            }

            // 4. Capture
            self.captureCurrentFrame(camItem: camItem) { [weak self] image in
                guard let self = self, !self.isCancelled else { return }

                // 5. Write on background
                self.writeQueue.async { [weak self] in
                    guard let self = self, !self.isCancelled else { return }

                    let pb: CVPixelBuffer?
                    if let img = image {
                        pb = self.createPixelBuffer(from: img, size: size)
                    } else {
                        pb = self.createBlackPixelBuffer(size: size)
                    }

                    if let pb = pb {
                        var waitCount = 0
                        while !videoInput.isReadyForMoreMediaData {
                            Thread.sleep(forTimeInterval: 0.005)
                            waitCount += 1
                            if waitCount > 200 { break }
                        }
                        let pts = CMTime(value: CMTimeValue(currentGlobalIdx), timescale: fps)
                        adaptor.append(pb, withPresentationTime: pts)
                    }

                    // 6. Next frame
                    DispatchQueue.main.async { [weak self] in
                        self?.renderFrameTrampoline(
                            localIdx: localIdx + 1, shot: shot, shotIdx: shotIdx,
                            frameCount: frameCount, camItem: camItem,
                            fps: fps, size: size, totalFrames: totalFrames,
                            shots: shots, shotFrameCounts: shotFrameCounts,
                            globalFrameIndex: currentGlobalIdx + 1,
                            videoInput: videoInput, adaptor: adaptor,
                            writer: writer, outURL: outURL,
                            nextShot: nextShot
                        )
                    }
                }
            }
        }
    }

    // MARK: - Capture Strategy

    /// Uses direct ARView.snapshot when possible (fast, no cloning).
    /// Falls back to captureFrameAsync (which may clone the scene).
    private func captureCurrentFrame(
        camItem: CanvasViewController.SceneCameraItem?,
        completion: @escaping (UIImage?) -> Void
    ) {
        // Prefer direct ARView snapshot — no scene cloning, much faster.
        if let arView = arView {
            arView.snapshot(saveToHDR: false) { image in
                DispatchQueue.main.async { completion(image) }
            }
            return
        }

        // Fallback to the caller-provided capture closure.
        if let capture = captureFrameAsync {
            capture(camItem, completion)
        } else {
            completion(nil)
        }
    }

    // MARK: - Finalization

    private func finishWriting(_ writer: AVAssetWriter,
                                _ input: AVAssetWriterInput,
                                _ outURL: URL) {
        input.markAsFinished()
        writer.finishWriting { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if self.isCancelled {
                    try? FileManager.default.removeItem(at: outURL)
                    self.onComplete?(nil, nil)
                } else if writer.status == .completed {
                    print("✅ Export complete: \(outURL.lastPathComponent)")
                    self.onComplete?(outURL, nil)
                } else {
                    print("❌ Export failed: \(writer.error?.localizedDescription ?? "unknown")")
                    self.onComplete?(nil, writer.error)
                }
            }
        }
    }

    private func finishCancelled(_ writer: AVAssetWriter, _ outURL: URL) {
        writer.cancelWriting()
        try? FileManager.default.removeItem(at: outURL)
        DispatchQueue.main.async { self.onComplete?(nil, nil) }
    }

    // MARK: - Pixel Buffer Creation

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

    /// Creates a black pixel buffer as fallback for failed captures.
    private func createBlackPixelBuffer(size: CGSize) -> CVPixelBuffer? {
        var pb: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
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
        // Zero-fill = black
        if let base = CVPixelBufferGetBaseAddress(buf) {
            memset(base, 0, CVPixelBufferGetBytesPerRow(buf) * Int(size.height))
        }
        CVPixelBufferUnlockBaseAddress(buf, [])
        return buf
    }
}
