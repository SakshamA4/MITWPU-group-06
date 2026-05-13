//
//  SequenceExportCoordinator.swift
//  FilmsPage
//
//  Exports an ordered sequence of scenes into one continuous MP4 by reusing
//  the real CanvasViewController + ScenePersistenceService + VideoExportService
//  pipeline.  No headless ARView, no duplicated restore logic.
//

import AVFoundation
import UIKit
import RealityKit

final class SequenceExportCoordinator {

    // MARK: - Types

    struct SequenceSceneEntry {
        let sceneID: UUID
        let sceneName: String
    }

    // MARK: - Injected Dependencies

    private let scenes: [SequenceSceneEntry]
    private let settings: ExportSettings
    private let canvas: CanvasViewController
    private let onProgress: (ExportProgress) -> Void
    private let onCompletion: (Result<URL, Error>) -> Void

    // MARK: - Writer State

    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var outURL: URL?

    private var globalFrameIndex: Int = 0
    private var totalEstimatedFrames: Int = 1
    private var isCancelled = false

    private let writeQueue = DispatchQueue(label: "com.filmspage.seqcoord.write", qos: .userInitiated)
    private let frameRenderDelay: TimeInterval = 0.035
    private let cameraSettleDelay: TimeInterval = 0.300
    private let interSceneGapSeconds: Double = 0.5

    // MARK: - Init

    init(scenes: [SequenceSceneEntry],
         settings: ExportSettings,
         canvas: CanvasViewController,
         onProgress: @escaping (ExportProgress) -> Void,
         onCompletion: @escaping (Result<URL, Error>) -> Void) {
        self.scenes = scenes
        self.settings = settings
        self.canvas = canvas
        self.onProgress = onProgress
        self.onCompletion = onCompletion
    }

    // MARK: - Public

    func start() {
        guard !scenes.isEmpty else {
            onCompletion(.failure(NSError(domain: "SeqCoord", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No scenes to export."])))
            return
        }

        isCancelled = false
        globalFrameIndex = 0

        let size = settings.resolution.size
        let fps = settings.fps.timescale

        // Estimate total frames (2s per scene as baseline, refined per-scene)
        let perSceneEstimate = 2 * Int(fps)
        let gapFrames = max(0, scenes.count - 1) * Int(ceil(interSceneGapSeconds * Double(fps)))
        totalEstimatedFrames = scenes.count * perSceneEstimate + gapFrames

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Sequence_\(Int(Date().timeIntervalSince1970)).mp4")
        try? FileManager.default.removeItem(at: url)
        self.outURL = url

        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else {
            onCompletion(.failure(NSError(domain: "SeqCoord", code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Could not create video writer."])))
            return
        }
        self.writer = writer

        // Bitrate: same formula as VideoExportService
        let pixelCount = Float(size.width * size.height)
        let baseBitrate = Float(10_000_000)
        let bitrate = baseBitrate * (pixelCount / Float(1920 * 1080))
                      * (Float(fps) / 24.0) * settings.quality.compressionQuality

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

        print("🎬 [SeqCoord] Starting sequence export: \(scenes.count) scenes")

        // Kick off the first scene
        DispatchQueue.main.async { [weak self] in
            self?.processScene(at: 0)
        }
    }

    func cancel() {
        isCancelled = true
        writer?.cancelWriting()
        print("🚫 [SeqCoord] Export cancelled")
    }

    // MARK: - Per-Scene Processing

    private func processScene(at index: Int) {
        guard !isCancelled else { finishCancelled(); return }
        guard let writer = writer, writer.status == .writing else {
            failExport(error: writer?.error); return
        }

        // All scenes done
        guard index < scenes.count else {
            finishWriting()
            return
        }

        let entry = scenes[index]
        print("🎬 [SeqCoord] ── Scene \(index + 1)/\(scenes.count): \"\(entry.sceneName)\" ──")

        reportProgress(sceneIndex: index, shotName: entry.sceneName, message: "Loading scene…")

        // Check if scene JSON exists
        guard ScenePersistenceService.shared.hasSave(for: entry.sceneID) else {
            print("⚠️ [SeqCoord] No save for scene \(entry.sceneID) — inserting black")
            insertBlackFrames(duration: 2.0) { [weak self] in
                self?.insertGapThenNext(sceneIndex: index)
            }
            return
        }

        // Load the scene using the real pipeline
        loadSceneOnCanvas(sceneID: entry.sceneID, sceneIndex: index)
    }

    private func loadSceneOnCanvas(sceneID: UUID, sceneIndex: Int) {
        // Reset the canvas state so it can load a new scene
        canvas.hasSceneBeenLoaded = false
        canvas.currentSceneID = sceneID

        Task { @MainActor [weak self] in
            guard let self = self, !self.isCancelled else { return }

            // Use the real ScenePersistenceService load path
            await ScenePersistenceService.shared.load(into: self.canvas, sceneID: sceneID)

            // Wait a moment for RealityKit to settle after entity restore
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s

            guard !self.isCancelled else { return }
            self.onSceneLoaded(sceneIndex: sceneIndex)
        }
    }

    private func onSceneLoaded(sceneIndex: Int) {
        let entry = scenes[sceneIndex]

        // Enter playback mode — seeds baseTransforms and baseFOVs
        canvas.enterShotPlaybackMode()

        // Derive shots from the now-live scene graph
        let shots = ShotDerived.derive(from: canvas.timeline, cameraItems: canvas.sceneCameraItems)
        let fps = settings.fps.timescale

        if shots.isEmpty {
            print("⚠️ [SeqCoord] No shots derived for \"\(entry.sceneName)\" — inserting black")
            canvas.exitShotPlaybackMode()
            insertBlackFrames(duration: 2.0) { [weak self] in
                self?.insertGapThenNext(sceneIndex: sceneIndex)
            }
            return
        }

        // Refine total frame estimate
        let sceneFrames = shots.reduce(0) { $0 + max(1, Int(ceil($1.duration * Float(fps)))) }
        let remainingScenes = scenes.count - sceneIndex - 1
        let remainingGaps = remainingScenes * Int(ceil(interSceneGapSeconds * Double(fps)))
        let estimated = globalFrameIndex + sceneFrames + remainingScenes * 2 * Int(fps) + remainingGaps
        totalEstimatedFrames = max(totalEstimatedFrames, estimated)

        print("🎬 [SeqCoord] \(shots.count) shots, \(sceneFrames) frames for \"\(entry.sceneName)\"")

        renderShotSequence(shotIdx: 0, shots: shots, sceneIndex: sceneIndex)
    }

    // MARK: - Shot-by-Shot Rendering

    private func renderShotSequence(shotIdx: Int, shots: [Shot], sceneIndex: Int) {
        guard !isCancelled else { finishCancelled(); return }

        // All shots in this scene done
        guard shotIdx < shots.count else {
            canvas.exitShotPlaybackMode()
            canvas.evaluateTimeline(at: 0)
            insertGapThenNext(sceneIndex: sceneIndex)
            return
        }

        let shot = shots[shotIdx]
        let fps = settings.fps.timescale
        let frameCount = max(1, Int(ceil(shot.duration * Float(fps))))

        // Switch to this shot's camera
        let camItem = cameraItem(for: shot)
        if let camItem = camItem {
            canvas.setActiveCamera(camItem.camera)
        }

        // Evaluate at shot start
        canvas.evaluateTimeline(at: shot.startTime)

        reportProgress(sceneIndex: sceneIndex,
                       shotName: "\(scenes[sceneIndex].sceneName) – \(shot.displayName)",
                       message: "Rendering…")

        let settle: TimeInterval = shotIdx > 0 ? cameraSettleDelay : 0.1

        DispatchQueue.main.asyncAfter(deadline: .now() + settle) { [weak self] in
            self?.renderFrameLoop(localIdx: 0, frameCount: frameCount, shot: shot,
                                  shotIdx: shotIdx, shots: shots, sceneIndex: sceneIndex)
        }
    }

    // MARK: - Per-Frame Render

    private func renderFrameLoop(localIdx: Int, frameCount: Int, shot: Shot,
                                 shotIdx: Int, shots: [Shot], sceneIndex: Int) {
        guard !isCancelled else { finishCancelled(); return }
        guard let writer = writer, writer.status == .writing else {
            failExport(error: writer?.error); return
        }

        // Shot complete → next shot
        guard localIdx < frameCount else {
            renderShotSequence(shotIdx: shotIdx + 1, shots: shots, sceneIndex: sceneIndex)
            return
        }

        let fps = settings.fps.timescale
        let size = settings.resolution.size
        let currentGlobal = globalFrameIndex

        // Report progress
        reportProgress(sceneIndex: sceneIndex,
                       shotName: "\(scenes[sceneIndex].sceneName) – \(shot.displayName)")

        // Evaluate timeline at this frame's master time
        let masterTime = shot.startTime + Float(localIdx) / Float(fps)
        canvas.evaluateTimeline(at: masterTime)

        // Wait for RealityKit to commit
        DispatchQueue.main.asyncAfter(deadline: .now() + frameRenderDelay) { [weak self] in
            guard let self = self, !self.isCancelled else { return }

            // Snapshot from the live ARView
            self.canvas.arView.snapshot(saveToHDR: false) { [weak self] image in
                guard let self = self, !self.isCancelled else { return }

                self.writeQueue.async { [weak self] in
                    guard let self = self, let videoInput = self.videoInput,
                          let adaptor = self.adaptor else { return }

                    autoreleasepool {
                        let pb: CVPixelBuffer?
                        if let img = image {
                            pb = VideoExportService.createPixelBuffer(from: img, size: size)
                        } else {
                            pb = VideoExportService.createBlackPixelBuffer(size: size)
                        }

                        if let pb = pb {
                            self.waitForInput(videoInput)
                            let pts = CMTime(value: CMTimeValue(currentGlobal), timescale: fps)
                            let ok = adaptor.append(pb, withPresentationTime: pts)
                            if !ok {
                                print("❌ [SeqCoord] Frame \(currentGlobal) append failed")
                            }
                        }
                    }

                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.globalFrameIndex = currentGlobal + 1
                        self.renderFrameLoop(localIdx: localIdx + 1, frameCount: frameCount,
                                             shot: shot, shotIdx: shotIdx, shots: shots,
                                             sceneIndex: sceneIndex)
                    }
                }
            }
        }
    }

    // MARK: - Camera Lookup

    private func cameraItem(for shot: Shot) -> CanvasViewController.SceneCameraItem? {
        if let camID = shot.cameraID {
            if let item = canvas.sceneCameraItems.first(where: { $0.id == camID }) { return item }
        }
        return canvas.sceneCameraItems.first { $0.cameraRoot.name == shot.cameraName }
    }

    // MARK: - Inter-Scene Gap

    private func insertGapThenNext(sceneIndex: Int) {
        guard sceneIndex < scenes.count - 1 else {
            // Last scene — no trailing gap
            processScene(at: sceneIndex + 1)
            return
        }
        insertBlackFrames(duration: interSceneGapSeconds) { [weak self] in
            self?.processScene(at: sceneIndex + 1)
        }
    }

    private func insertBlackFrames(duration: Double, completion: @escaping () -> Void) {
        let fps = settings.fps.timescale
        let size = settings.resolution.size
        let count = max(1, Int(ceil(duration * Double(fps))))

        writeQueue.async { [weak self] in
            guard let self = self, let videoInput = self.videoInput,
                  let adaptor = self.adaptor else {
                DispatchQueue.main.async { completion() }
                return
            }
            for _ in 0..<count {
                guard !self.isCancelled else { break }
                autoreleasepool {
                    if let pb = VideoExportService.createBlackPixelBuffer(size: size) {
                        self.waitForInput(videoInput)
                        let pts = CMTime(value: CMTimeValue(self.globalFrameIndex), timescale: fps)
                        adaptor.append(pb, withPresentationTime: pts)
                        self.globalFrameIndex += 1
                    }
                }
            }
            DispatchQueue.main.async { completion() }
        }
    }

    // MARK: - Progress

    private func reportProgress(sceneIndex: Int, shotName: String, message: String? = nil) {
        let progress = ExportProgress(
            currentShotIndex: sceneIndex,
            totalShots: scenes.count,
            currentFrame: globalFrameIndex,
            totalFrames: max(1, totalEstimatedFrames),
            overallProgress: min(1.0, Float(globalFrameIndex) / Float(max(1, totalEstimatedFrames))),
            shotName: shotName,
            statusMessage: message
        )
        onProgress(progress)
    }

    // MARK: - Finalization

    private func finishWriting() {
        guard let writer = writer, let videoInput = videoInput, let outURL = outURL else { return }
        videoInput.markAsFinished()
        writer.finishWriting { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if self.isCancelled {
                    try? FileManager.default.removeItem(at: outURL)
                    self.onCompletion(.failure(NSError(domain: "SeqCoord", code: -3,
                        userInfo: [NSLocalizedDescriptionKey: "Export cancelled."])))
                } else if writer.status == .completed {
                    let fileSize = (try? FileManager.default.attributesOfItem(atPath: outURL.path)[.size] as? Int) ?? 0
                    print("✅ [SeqCoord] Export complete: \(outURL.lastPathComponent) (\(fileSize) bytes)")
                    self.onCompletion(.success(outURL))
                } else {
                    print("❌ [SeqCoord] Writer failed: \(writer.error?.localizedDescription ?? "unknown")")
                    self.onCompletion(.failure(writer.error ?? NSError(domain: "SeqCoord", code: -4,
                        userInfo: [NSLocalizedDescriptionKey: "Video writer failed."])))
                }
            }
        }
    }

    private func finishCancelled() {
        writer?.cancelWriting()
        if let url = outURL { try? FileManager.default.removeItem(at: url) }
        DispatchQueue.main.async { [weak self] in
            self?.onCompletion(.failure(NSError(domain: "SeqCoord", code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Export cancelled."])))
        }
    }

    private func failExport(error: Error?) {
        guard !isCancelled else { return }
        isCancelled = true
        writer?.cancelWriting()
        if let url = outURL { try? FileManager.default.removeItem(at: url) }
        DispatchQueue.main.async { [weak self] in
            self?.onCompletion(.failure(error ?? NSError(domain: "SeqCoord", code: -5,
                userInfo: [NSLocalizedDescriptionKey: "Export failed."])))
        }
    }

    // MARK: - Helpers

    private func waitForInput(_ input: AVAssetWriterInput) {
        var wait = 0
        while !input.isReadyForMoreMediaData {
            Thread.sleep(forTimeInterval: 0.005)
            wait += 1
            if wait > 200 { break }
        }
    }
}
