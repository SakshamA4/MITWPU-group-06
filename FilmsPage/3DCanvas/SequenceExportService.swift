//
//  SequenceExportService.swift
//  FilmsPage
//
//  Multi-scene sequence export: loads each scene's JSON into an offscreen
//  CanvasViewController, derives its shots, renders frames into a single
//  continuous AVAssetWriter session, and produces one MP4.
//
//  ARCHITECTURE:
//  ─────────────────────────────────────────────────────────────────────────
//  • Uses an offscreen CanvasViewController (added as a child VC) as the
//    render target — same pattern as ShotPlayerViewController.
//  • Each scene is loaded sequentially via ScenePersistenceService.load().
//  • Shots are derived via ShotDerived.derive() and rendered using the
//    same evaluate→wait→snapshot→pixelBuffer→append pipeline as
//    VideoExportService.
//  • All scenes write into a single AVAssetWriter with continuous CMTime.
//  • 0.5s black frame gaps are inserted between scenes.
//  • If a scene fails to load, black frames are inserted for a default
//    duration (5s) and export continues.
//  ─────────────────────────────────────────────────────────────────────────

import AVFoundation
import UIKit
import RealityKit

final class SequenceExportService {

    // MARK: - Types

    struct SceneEntry {
        let sceneID: UUID
        let sceneName: String
    }

    // MARK: - Configuration

    var scenes: [SceneEntry] = []
    var settings = ExportSettings()

    /// The view controller that will host the offscreen render VC as a child.
    weak var presentingVC: UIViewController?

    // MARK: - Callbacks

    var onProgress: ((ExportProgress) -> Void)?
    var onComplete: ((URL?, Error?) -> Void)?

    // MARK: - State

    private var isCancelled = false
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?

    /// Offscreen CanvasViewController used for rendering.
    private var renderVC: CanvasViewController?

    /// Global frame counter across all scenes (for continuous CMTime).
    private var globalFrameIndex = 0
    private var totalEstimatedFrames = 0

    /// Background serial queue for pixel buffer + disk writes.
    private let writeQueue = DispatchQueue(label: "com.filmspage.sequenceexport.write",
                                            qos: .userInitiated)

    /// Per-frame render settle delay (2 render frames ≈ 35ms).
    private let frameRenderDelay: TimeInterval = 0.035

    /// Black gap between scenes (seconds).
    private let interSceneGapDuration: TimeInterval = 0.5

    /// Default duration for a scene that fails to load.
    private let failedSceneDuration: TimeInterval = 5.0

    /// Camera settle delay after switching scenes.
    private let cameraSettleDelay: TimeInterval = 0.300

    // MARK: - Public API

    func cancel() {
        isCancelled = true
        writer?.cancelWriting()
        print("🚫 [SeqExport] Cancelled by user")
    }

    func startExport() {
        guard !scenes.isEmpty else {
            onComplete?(nil, NSError(domain: "SeqExport", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No scenes to export."]))
            return
        }

        isCancelled = false
        globalFrameIndex = 0

        let size = settings.resolution.size
        let fps = settings.fps.timescale

        // Rough estimate: 5 seconds per scene average for progress reporting
        totalEstimatedFrames = scenes.count * 5 * Int(fps)

        // Output URL
        let safeName = scenes.first?.sceneName.replacingOccurrences(of: " ", with: "_") ?? "Sequence"
        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Sequence_\(safeName)_\(Int(Date().timeIntervalSince1970)).mp4")
        try? FileManager.default.removeItem(at: outURL)

        // AVAssetWriter setup
        guard let writer = try? AVAssetWriter(outputURL: outURL, fileType: .mp4) else {
            print("❌ [SeqExport] Could not create AVAssetWriter")
            DispatchQueue.main.async {
                self.onComplete?(nil, NSError(domain: "SeqExport", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Could not create video writer."]))
            }
            return
        }
        self.writer = writer

        // Bitrate
        let pixelCount = Float(size.width * size.height)
        let basePixels = Float(1920 * 1080)
        let baseBitrate = Float(10_000_000)
        let bitrate = baseBitrate * (pixelCount / basePixels)
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

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = false
        self.videoInput = input

        let pixelAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height),
            ]
        )
        self.adaptor = pixelAdaptor

        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        print("🎬 [SeqExport] Started: \(scenes.count) scene(s), \(settings.resolution.rawValue) @ \(settings.fps.rawValue)fps")

        // Create offscreen render VC
        setupOffscreenRenderVC()

        // Begin sequential scene rendering
        DispatchQueue.main.async { [weak self] in
            self?.renderScene(at: 0, outURL: outURL)
        }
    }

    // MARK: - Offscreen Render VC

    private func setupOffscreenRenderVC() {
        let vc = CanvasViewController()
        vc.sceneName = "ExportRender"
        renderVC = vc

        // Add as child VC with a 1x1 offscreen frame so the ARView has a valid Metal context
        if let parent = presentingVC {
            parent.addChild(vc)
            vc.view.frame = CGRect(x: -1, y: -1, width: 1, height: 1)
            parent.view.addSubview(vc.view)
            vc.didMove(toParent: parent)
        }
    }

    private func teardownOffscreenRenderVC() {
        renderVC?.willMove(toParent: nil)
        renderVC?.view.removeFromSuperview()
        renderVC?.removeFromParent()
        renderVC = nil
    }

    // MARK: - Scene-by-Scene Rendering

    private func renderScene(at sceneIndex: Int, outURL: URL) {
        guard !isCancelled else { finishCancelled(outURL); return }
        guard let writer = writer, writer.status == .writing else {
            failExport(outURL, error: writer?.error)
            return
        }

        // All scenes done — finalize
        guard sceneIndex < scenes.count else {
            print("🎬 [SeqExport] All \(scenes.count) scene(s) rendered. Finalizing...")
            finishWriting(outURL)
            return
        }

        let entry = scenes[sceneIndex]
        print("🎬 [SeqExport] ── Scene \(sceneIndex + 1)/\(scenes.count): \"\(entry.sceneName)\" ──")

        // Report progress
        reportProgress(sceneIndex: sceneIndex, shotName: entry.sceneName, statusMessage: "Loading scene…")

        // Load scene JSON into the render VC
        guard let vc = renderVC else {
            failExport(outURL, error: NSError(domain: "SeqExport", code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Render VC not available."]))
            return
        }

        vc.currentSceneID = entry.sceneID
        vc.sceneName = entry.sceneName

        // Check if scene has a save
        guard ScenePersistenceService.shared.hasSave(for: entry.sceneID) else {
            print("⚠️ [SeqExport] No save for scene \(entry.sceneName) — inserting black gap")
            insertBlackFrames(duration: failedSceneDuration, outURL: outURL) { [weak self] in
                self?.insertInterSceneGap(outURL: outURL) {
                    self?.renderScene(at: sceneIndex + 1, outURL: outURL)
                }
            }
            return
        }

        Task { @MainActor [weak self] in
            guard let self = self, !self.isCancelled else { return }

            await ScenePersistenceService.shared.load(into: vc, sceneID: entry.sceneID)

            // Derive shots
            let shots = ShotDerived.derive(from: vc.timeline, cameraItems: vc.sceneCameraItems)
            let fps = self.settings.fps.timescale
            let size = self.settings.resolution.size

            if shots.isEmpty {
                // No shots — evaluate timeline at t=0, render a single 2-second segment
                print("⚠️ [SeqExport] No shots in scene \(entry.sceneName) — rendering 2s static")
                vc.evaluateTimeline(at: 0)
                self.insertBlackFrames(duration: 2.0, outURL: outURL) { [weak self] in
                    self?.insertInterSceneGap(outURL: outURL) {
                        self?.renderScene(at: sceneIndex + 1, outURL: outURL)
                    }
                }
                return
            }

            // Update total frame estimate now that we know actual shot durations
            let sceneFrames = shots.reduce(0) { $0 + max(1, Int(ceil($1.duration * Float(fps)))) }
            // Adjust total estimate
            let remainingScenes = self.scenes.count - sceneIndex - 1
            self.totalEstimatedFrames = self.globalFrameIndex + sceneFrames + remainingScenes * 5 * Int(fps)

            // Render shots sequentially
            self.renderShotLoop(
                shotIdx: 0, shots: shots, sceneIndex: sceneIndex,
                fps: fps, size: size, outURL: outURL
            )
        }
    }

    // MARK: - Shot Render Loop

    private func renderShotLoop(
        shotIdx: Int, shots: [Shot], sceneIndex: Int,
        fps: Int32, size: CGSize, outURL: URL
    ) {
        guard !isCancelled else { finishCancelled(outURL); return }
        guard let writer = writer, writer.status == .writing else {
            failExport(outURL, error: writer?.error)
            return
        }

        // All shots in this scene rendered
        guard shotIdx < shots.count else {
            // Insert inter-scene black gap, then advance to next scene
            insertInterSceneGap(outURL: outURL) { [weak self] in
                self?.renderScene(at: sceneIndex + 1, outURL: outURL)
            }
            return
        }

        let shot = shots[shotIdx]
        let frameCount = max(1, Int(ceil(shot.duration * Float(fps))))

        guard let vc = renderVC else { return }

        // Set camera for this shot
        let camItem = vc.sceneCameraItems.first { $0.cameraRoot.name == shot.cameraName }
            ?? vc.sceneCameraItems.first(where: { $0.id == shot.cameraID })
        if let cam = camItem {
            vc.setActiveCamera(cam.camera)
        }

        // Evaluate at shot start
        vc.evaluateTimeline(at: shot.startTime)

        reportProgress(sceneIndex: sceneIndex, shotName: "\(scenes[sceneIndex].sceneName) — \(shot.displayName)",
                       statusMessage: "Rendering…")

        // Settle delay
        let settle = shotIdx > 0 ? cameraSettleDelay : 0.1
        DispatchQueue.main.asyncAfter(deadline: .now() + settle) { [weak self] in
            self?.renderFrameLoop(
                localIdx: 0, frameCount: frameCount, shot: shot,
                shotIdx: shotIdx, shots: shots, sceneIndex: sceneIndex,
                fps: fps, size: size, outURL: outURL
            )
        }
    }

    // MARK: - Per-Frame Render Loop

    private func renderFrameLoop(
        localIdx: Int, frameCount: Int, shot: Shot,
        shotIdx: Int, shots: [Shot], sceneIndex: Int,
        fps: Int32, size: CGSize, outURL: URL
    ) {
        guard !isCancelled else { finishCancelled(outURL); return }
        guard let writer = writer, writer.status == .writing else {
            failExport(outURL, error: writer?.error)
            return
        }

        // Shot complete
        guard localIdx < frameCount else {
            renderShotLoop(
                shotIdx: shotIdx + 1, shots: shots, sceneIndex: sceneIndex,
                fps: fps, size: size, outURL: outURL
            )
            return
        }

        guard let vc = renderVC else { return }

        let currentGlobalIdx = globalFrameIndex

        // Report progress
        reportProgress(sceneIndex: sceneIndex,
                       shotName: "\(scenes[sceneIndex].sceneName) — \(shot.displayName)")

        // Evaluate timeline
        let masterTime = shot.startTime + Float(localIdx) / Float(fps)
        vc.evaluateTimeline(at: masterTime)

        // Wait for RealityKit flush
        DispatchQueue.main.asyncAfter(deadline: .now() + frameRenderDelay) { [weak self] in
            guard let self = self, !self.isCancelled else {
                self?.finishCancelled(outURL)
                return
            }

            // Capture frame
            vc.arView.snapshot(saveToHDR: false) { [weak self] image in
                guard let self = self, !self.isCancelled else { return }

                self.writeQueue.async { [weak self] in
                    guard let self = self, !self.isCancelled,
                          let videoInput = self.videoInput,
                          let adaptor = self.adaptor else { return }

                    autoreleasepool {
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
                    }

                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.globalFrameIndex = currentGlobalIdx + 1
                        self.renderFrameLoop(
                            localIdx: localIdx + 1, frameCount: frameCount, shot: shot,
                            shotIdx: shotIdx, shots: shots, sceneIndex: sceneIndex,
                            fps: fps, size: size, outURL: outURL
                        )
                    }
                }
            }
        }
    }

    // MARK: - Black Frame Gaps

    private func insertInterSceneGap(outURL: URL, completion: @escaping () -> Void) {
        guard !isCancelled else { finishCancelled(outURL); return }
        insertBlackFrames(duration: interSceneGapDuration, outURL: outURL, completion: completion)
    }

    private func insertBlackFrames(duration: TimeInterval, outURL: URL, completion: @escaping () -> Void) {
        let fps = settings.fps.timescale
        let size = settings.resolution.size
        let frameCount = max(1, Int(ceil(duration * Double(fps))))

        writeQueue.async { [weak self] in
            guard let self = self, !self.isCancelled,
                  let videoInput = self.videoInput,
                  let adaptor = self.adaptor else {
                DispatchQueue.main.async { completion() }
                return
            }

            for i in 0..<frameCount {
                guard !self.isCancelled else { break }

                autoreleasepool {
                    if let blackPB = self.createBlackPixelBuffer(size: size) {
                        var waitCount = 0
                        while !videoInput.isReadyForMoreMediaData {
                            Thread.sleep(forTimeInterval: 0.005)
                            waitCount += 1
                            if waitCount > 200 { break }
                        }

                        let pts = CMTime(value: CMTimeValue(self.globalFrameIndex), timescale: fps)
                        adaptor.append(blackPB, withPresentationTime: pts)
                        self.globalFrameIndex += 1
                    }
                }
            }

            DispatchQueue.main.async { completion() }
        }
    }

    // MARK: - Progress Reporting

    private func reportProgress(sceneIndex: Int, shotName: String, statusMessage: String? = nil) {
        let progress = ExportProgress(
            currentShotIndex: sceneIndex,
            totalShots: scenes.count,
            currentFrame: globalFrameIndex,
            totalFrames: max(1, totalEstimatedFrames),
            overallProgress: Float(globalFrameIndex) / Float(max(1, totalEstimatedFrames)),
            shotName: shotName,
            statusMessage: statusMessage
        )
        onProgress?(progress)
    }

    // MARK: - Finalization

    private func finishWriting(_ outURL: URL) {
        guard let writer = writer, let videoInput = videoInput else { return }
        videoInput.markAsFinished()
        writer.finishWriting { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.teardownOffscreenRenderVC()

                if self.isCancelled {
                    try? FileManager.default.removeItem(at: outURL)
                    self.onComplete?(nil, nil)
                } else if writer.status == .completed {
                    let fileSize = (try? FileManager.default.attributesOfItem(atPath: outURL.path)[.size] as? Int) ?? 0
                    print("✅ [SeqExport] Complete: \(outURL.lastPathComponent) (\(fileSize) bytes)")
                    self.onComplete?(outURL, nil)
                } else {
                    print("❌ [SeqExport] Failed: \(writer.error?.localizedDescription ?? "unknown")")
                    self.onComplete?(nil, writer.error)
                }
            }
        }
    }

    private func finishCancelled(_ outURL: URL) {
        writer?.cancelWriting()
        try? FileManager.default.removeItem(at: outURL)
        DispatchQueue.main.async { [weak self] in
            self?.teardownOffscreenRenderVC()
            self?.onComplete?(nil, nil)
        }
    }

    private func failExport(_ outURL: URL, error: Error?) {
        guard !isCancelled else { return }
        isCancelled = true
        writer?.cancelWriting()
        try? FileManager.default.removeItem(at: outURL)
        DispatchQueue.main.async { [weak self] in
            self?.teardownOffscreenRenderVC()
            self?.onComplete?(nil, error ?? NSError(domain: "SeqExport", code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Video writer failed during sequence export."]))
        }
    }

    // MARK: - Pixel Buffer Creation

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
        if let base = CVPixelBufferGetBaseAddress(buf) {
            memset(base, 0, CVPixelBufferGetBytesPerRow(buf) * Int(size.height))
        }
        CVPixelBufferUnlockBaseAddress(buf, [])
        return buf
    }
}
