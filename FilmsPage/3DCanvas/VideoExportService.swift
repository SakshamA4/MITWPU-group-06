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
    /// Optional status message (e.g. "Switching camera...")
    let statusMessage: String?

    init(currentShotIndex: Int, totalShots: Int, currentFrame: Int,
         totalFrames: Int, overallProgress: Float, shotName: String,
         statusMessage: String? = nil) {
        self.currentShotIndex = currentShotIndex
        self.totalShots = totalShots
        self.currentFrame = currentFrame
        self.totalFrames = totalFrames
        self.overallProgress = overallProgress
        self.shotName = shotName
        self.statusMessage = statusMessage
    }
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

    /// Settle time after switching cameras between shots (allows RealityKit to
    /// composite the new camera view). 200ms ≈ 6 render frames @ 30fps.
    private let cameraSettleDelay: TimeInterval = 0.200

    /// Per-frame render settle delay (2 render frames ≈ 35ms).
    private let frameRenderDelay: TimeInterval = 0.035

    // MARK: - Public API

    func cancel() {
        isCancelled = true
        writer?.cancelWriting()
        print("🚫 Export cancelled by user")
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
            print("❌ [Export] Could not create AVAssetWriter at \(outURL.path)")
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
                AVVideoMaxKeyFrameIntervalKey: fps * 2
            ] as [String: Any]
        ]

        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey  as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height)
            ]
        )

        writer.add(videoInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        print("🎬 [Export] Started: \(shots.count) shot(s), \(totalFrames) frames, \(settings.resolution.rawValue) @ \(settings.fps.rawValue)fps")
        print("🎬 [Export] Output: \(outURL.lastPathComponent)")
        print("🎬 [Export] Writer status: \(writer.status.rawValue)")

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

        // ── renderShot: called once per shot ──
        func renderShot(shotIdx: Int) {
            guard !self.isCancelled else { self.finishCancelled(writer, outURL); return }
            guard shotIdx < shots.count else {
                // All shots rendered — finalize
                print("🎬 [Export] All \(shots.count) shot(s) rendered. Finalizing...")
                self.finishWriting(writer, videoInput, outURL)
                return
            }

            // Check writer health before proceeding to next shot
            guard writer.status == .writing else {
                print("❌ [Export] Writer not in writing state (\(writer.status.rawValue)) before shot \(shotIdx). Error: \(writer.error?.localizedDescription ?? "none")")
                self.failExport(writer, outURL, error: writer.error)
                return
            }

            let shot       = shots[shotIdx]
            let frameCount = shotFrameCounts[shotIdx]
            let camItem    = self.cameraItemForShot?(shot)

            print("🎬 [Export] ── Shot \(shotIdx + 1)/\(shots.count): \"\(shot.displayName)\" ──")
            print("   Camera: \(shot.cameraName), Duration: \(shot.duration)s, Frames: \(frameCount)")
            print("   StartTime: \(shot.startTime)s, GlobalFrameOffset: \(globalFrameIndex)")

            // Report "switching camera" progress for multi-shot exports
            if shots.count > 1 {
                let progress = ExportProgress(
                    currentShotIndex: shotIdx,
                    totalShots: shots.count,
                    currentFrame: globalFrameIndex,
                    totalFrames: totalFrames,
                    overallProgress: Float(globalFrameIndex) / Float(max(1, totalFrames)),
                    shotName: shot.displayName,
                    statusMessage: "Setting up camera…"
                )
                self.onProgress?(progress)
            }

            // Set camera for this shot
            self.prepareForCapture?(camItem)

            // Evaluate timeline at shot start so the scene is positioned correctly
            // before we start capturing frames
            self.evaluateTimeline?(shot.startTime)

            // Settle delay: for multi-shot exports, give RealityKit time to
            // composite the new camera view after switching. For single-shot,
            // skip the extra delay since the camera was already active.
            let needsSettle = shots.count > 1 && shotIdx > 0
            let settleTime = needsSettle ? self.cameraSettleDelay : 0.0

            print("   Settle delay: \(Int(settleTime * 1000))ms")

            DispatchQueue.main.asyncAfter(deadline: .now() + settleTime) { [weak self] in
                guard let self = self, !self.isCancelled else {
                    self?.finishCancelled(writer, outURL)
                    return
                }

                self.renderFrameLoop(
                    localIdx: 0, shot: shot, shotIdx: shotIdx,
                    frameCount: frameCount, camItem: camItem,
                    fps: fps, size: size, totalFrames: totalFrames,
                    shots: shots, shotFrameCounts: shotFrameCounts,
                    globalFrameIndex: globalFrameIndex,
                    videoInput: videoInput, adaptor: adaptor,
                    writer: writer, outURL: outURL,
                    nextShot: { nextGlobalIdx in
                        globalFrameIndex = nextGlobalIdx
                        renderShot(shotIdx: shotIdx + 1)
                    }
                )
            }
        }

        // Kick off on main thread
        DispatchQueue.main.async { renderShot(shotIdx: 0) }
    }

    // MARK: - Per-Frame Render Loop (runs on main thread)
    //
    // Unified render loop that avoids the original renderFrame/renderFrameTrampoline
    // duplication. Uses a value-type globalFrameIndex (not inout) to avoid escaping
    // closure issues.

    private func renderFrameLoop(
        localIdx: Int, shot: Shot, shotIdx: Int,
        frameCount: Int, camItem: CanvasViewController.SceneCameraItem?,
        fps: Int32, size: CGSize, totalFrames: Int,
        shots: [Shot], shotFrameCounts: [Int],
        globalFrameIndex: Int,
        videoInput: AVAssetWriterInput,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        writer: AVAssetWriter, outURL: URL,
        nextShot: @escaping (Int) -> Void
    ) {
        // ── Guard: cancellation ──
        guard !isCancelled else { finishCancelled(writer, outURL); return }

        // ── Guard: shot complete → advance to next shot ──
        guard localIdx < frameCount else {
            print("   ✅ Shot \(shotIdx + 1) complete. globalFrame=\(globalFrameIndex)")
            nextShot(globalFrameIndex)
            return
        }

        // ── Guard: writer health ──
        guard writer.status == .writing else {
            print("❌ [Export] Writer failed at shot \(shotIdx + 1), frame \(localIdx). Status=\(writer.status.rawValue), Error: \(writer.error?.localizedDescription ?? "none")")
            failExport(writer, outURL, error: writer.error)
            return
        }

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

        // 2. Evaluate timeline at this frame's master time (synchronous on main thread)
        let masterTime = shot.startTime + Float(localIdx) / Float(fps)
        evaluateTimeline?(masterTime)

        // 3. Wait for RealityKit to commit the scene (2 render frames ≈ 35ms).
        //    We yield to the run loop instead of blocking the main thread.
        DispatchQueue.main.asyncAfter(deadline: .now() + frameRenderDelay) { [weak self] in
            guard let self = self, !self.isCancelled else {
                self?.finishCancelled(writer, outURL)
                return
            }

            // 4. Capture frame using direct ARView snapshot (avoids scene cloning)
            self.captureCurrentFrame(camItem: camItem) { [weak self] image in
                guard let self = self, !self.isCancelled else { return }

                // 5. Pixel buffer creation + write on background queue.
                //    This frees the main thread immediately for the next frame.
                self.writeQueue.async { [weak self] in
                    guard let self = self, !self.isCancelled else { return }

                    // Check writer status before attempting append
                    guard writer.status == .writing else {
                        print("❌ [Export] Writer not writing at frame \(currentGlobalIdx). Status=\(writer.status.rawValue)")
                        DispatchQueue.main.async {
                            self.failExport(writer, outURL, error: writer.error)
                        }
                        return
                    }

                    // Use autorelease pool to prevent memory buildup during long exports
                    autoreleasepool {
                        let pb: CVPixelBuffer?
                        if let img = image {
                            pb = Self.createPixelBuffer(from: img, size: size)
                        } else {
                            // Frame capture failed — append a black frame to maintain timing
                            print("⚠️ [Export] Nil frame at globalIdx=\(currentGlobalIdx), using black fallback")
                            pb = Self.createBlackPixelBuffer(size: size)
                        }

                        if let pb = pb {
                            // Wait for writer input to be ready (background queue — safe to block)
                            var waitCount = 0
                            while !videoInput.isReadyForMoreMediaData {
                                Thread.sleep(forTimeInterval: 0.005)
                                waitCount += 1
                                if waitCount > 200 {
                                    print("⚠️ [Export] Writer input stalled for 1s at frame \(currentGlobalIdx)")
                                    break
                                }
                            }

                            let pts = CMTime(value: CMTimeValue(currentGlobalIdx), timescale: fps)
                            let success = adaptor.append(pb, withPresentationTime: pts)

                            if !success {
                                print("❌ [Export] Failed to append frame \(currentGlobalIdx) at pts=\(pts.seconds)s. Writer status=\(writer.status.rawValue), Error: \(writer.error?.localizedDescription ?? "none")")
                            }

                            // Log every 30th frame to avoid spam, but always log first/last
                            if currentGlobalIdx == 0 || currentGlobalIdx % 30 == 0 || localIdx == frameCount - 1 {
                                print("📝 [Export] Frame \(currentGlobalIdx)/\(totalFrames) | shot \(shotIdx + 1) localFrame \(localIdx)/\(frameCount) | pts=\(String(format: "%.3f", pts.seconds))s | ok=\(success)")
                            }
                        } else {
                            print("❌ [Export] Could not create pixel buffer at frame \(currentGlobalIdx)")
                        }
                    }

                    // 6. Schedule next frame back on main thread
                    DispatchQueue.main.async { [weak self] in
                        self?.renderFrameLoop(
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
            print("⚠️ [Export] No arView and no captureFrameAsync — returning nil frame")
            completion(nil)
        }
    }

    // MARK: - Finalization

    private func finishWriting(_ writer: AVAssetWriter,
                                _ input: AVAssetWriterInput,
                                _ outURL: URL) {
        print("🎬 [Export] Finalizing writer... status=\(writer.status.rawValue)")
        input.markAsFinished()
        writer.finishWriting { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if self.isCancelled {
                    print("🚫 [Export] Cancelled — cleaning up temp file")
                    try? FileManager.default.removeItem(at: outURL)
                    self.onComplete?(nil, nil)
                } else if writer.status == .completed {
                    // Verify file exists and has content
                    let fileSize = (try? FileManager.default.attributesOfItem(atPath: outURL.path)[.size] as? Int) ?? 0
                    print("✅ [Export] Complete: \(outURL.lastPathComponent) (\(fileSize) bytes)")
                    self.onComplete?(outURL, nil)
                } else {
                    print("❌ [Export] Failed: \(writer.error?.localizedDescription ?? "unknown")")
                    self.onComplete?(nil, writer.error)
                }
            }
        }
    }

    private func finishCancelled(_ writer: AVAssetWriter, _ outURL: URL) {
        print("🚫 [Export] Finishing cancelled export — cleaning up")
        writer.cancelWriting()
        try? FileManager.default.removeItem(at: outURL)
        DispatchQueue.main.async { self.onComplete?(nil, nil) }
    }

    /// Called when the writer enters a failed state mid-export.
    private func failExport(_ writer: AVAssetWriter, _ outURL: URL, error: Error?) {
        guard !isCancelled else { return }  // Don't double-report
        isCancelled = true  // Prevent further frame processing
        print("❌ [Export] Writer failed — aborting. Error: \(error?.localizedDescription ?? "unknown")")
        writer.cancelWriting()
        try? FileManager.default.removeItem(at: outURL)
        DispatchQueue.main.async {
            self.onComplete?(nil, error ?? NSError(domain: "Export", code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Video writer failed during export."]))
        }
    }

    // MARK: - Pixel Buffer Creation

    /// Optimized pixel buffer creation using BGRA (native Metal format).
    /// Exposed as `static` so SequenceExportCoordinator can reuse the same
    /// conversion logic without duplicating code.
    static func createPixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
        guard let cgImage = image.cgImage else { return nil }

        var pb: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any]
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
    /// Exposed as `static` so SequenceExportCoordinator can reuse it.
    static func createBlackPixelBuffer(size: CGSize) -> CVPixelBuffer? {
        var pb: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
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
