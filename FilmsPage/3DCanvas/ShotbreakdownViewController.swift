//
//  ShotBreakdownViewController.swift
//  3DCanvas
//
//  REDESIGN: Clean cinematic UI. Thumbnails show actual camera POV.
//  Each shot card displays the camera's rendered perspective as the preview image.
//

import UIKit
import RealityKit

// MARK: - Shot Model

struct Shot {
    let id: UUID
    let index: Int
    let cameraName: String
    let cameraID: UUID?
    let startTime: Float
    let duration: Float
    var thumbnail: UIImage?
    let clipID: UUID

    var displayName: String { "Shot \(index + 1)" }
    var shortLabel: String  { "\(index + 1)" }
    var endTime: Float      { startTime + duration }

    var cleanCameraName: String {
        cameraName
            .replacingOccurrences(of: "SceneCamera_", with: "Cam ")
            .replacingOccurrences(of: "SceneCamera", with: "Cam")
            .replacingOccurrences(of: "Camera_", with: "Cam ")
            .replacingOccurrences(of: "Camera", with: "Cam")
    }
}

// MARK: - Shot Derivation

struct ShotDerived {
    static func derive(from timeline: Timeline, cameraItems: [CanvasViewController.SceneCameraItem]) -> [Shot] {
        let totalDuration = timeline.duration
        guard totalDuration > 0 else { return [] }

        let cameraNameSet = Set(cameraItems.map { $0.cameraRoot.name })
        var cameraIDMap: [UUID: CanvasViewController.SceneCameraItem] = [:]
        var cameraNameMap: [String: CanvasViewController.SceneCameraItem] = [:]
        for item in cameraItems {
            cameraIDMap[item.id] = item
            if cameraNameMap[item.cameraRoot.name] == nil {
                cameraNameMap[item.cameraRoot.name] = item
            }
        }

        // FIX: Filter ONLY for clips that match an actual camera by ID or name.
        // If no camera exists, hide the shot.
        let cameraClips = timeline.clips.filter { clip in
            if let id = clip.entityID, cameraIDMap[id] != nil { return true }
            return cameraNameSet.contains(clip.entityName)
        }

        if cameraClips.isEmpty {
            // No camera clips → no shots to show
            // (User must add cameras and animate them to see shots)
            return []
        }

        // FIX: Create ONE SHOT PER CLIP, no merging
        // Sort clips chronologically by start time
        let sortedClips = cameraClips.sorted { $0.startTime < $1.startTime }

        // Create a shot for each clip with its own index
        return sortedClips.enumerated().compactMap { (index, clip) in
            let cameraItem: CanvasViewController.SceneCameraItem?
            if let id = clip.entityID {
                cameraItem = cameraIDMap[id]
            } else {
                cameraItem = cameraNameMap[clip.entityName]
            }
            guard let item = cameraItem else { return nil }
            return Shot(
                id: UUID(),
                index: index,
                cameraName: item.cameraRoot.name,
                cameraID: item.id,
                startTime: clip.startTime,
                duration: clip.duration,
                thumbnail: nil,
                clipID: clip.id
            )
        }
    }
}

// MARK: - ShotBreakdownViewController

class ShotBreakdownViewController: UIViewController {

    // MARK: - Palette
    private let bgColor    = UIColor(red: 0.043, green: 0.043, blue: 0.086, alpha: 1) // #0B0B16
    private let cardColor  = UIColor(red: 0.086, green: 0.086, blue: 0.141, alpha: 1) // #161624
    private let sepColor   = UIColor(white: 1, alpha: 0.06)
    private let accentRed  = UIColor(red: 0.694, green: 0.125, blue: 0.224, alpha: 1) // #B12038

     // MARK: - Public API
     var sceneName: String  = "Scene"
     var timeline: Timeline = Timeline()
    weak var arView: ARView?
    var evaluateTimeline: ((Float) -> Void)?
    var cameraItems: [CanvasViewController.SceneCameraItem] = []
    var captureFrameAsync: ((CanvasViewController.SceneCameraItem?, @escaping (UIImage?) -> Void) -> Void)?
    var captureAtTime: ((Float, CanvasViewController.SceneCameraItem?, @escaping (UIImage?) -> Void) -> Void)?
    var prepareForCapture: ((CanvasViewController.SceneCameraItem?) -> Void)?
    var fetchTimeline: (() -> Timeline)?
    var enterPlaybackMode: (() -> Void)?
    var exitPlaybackMode:  (() -> Void)?
    var commitClipTimingChange: ((AnimationClip, UUID, Int) -> Void)?
    var shiftSubsequentClips: ((String, Float, Float) -> Void)?
    var mergeConflictingClip: ((AnimationClip, Float, Float) -> Void)?
    var deleteTimelineClip: ((UUID) -> Void)?
    var clipConflictCheck: ((AnimationClip, UUID) -> AnimationClip?)?

    // MARK: - State
    private var shots: [Shot] = []
    private var thumbnailsGenerated = false
    private var isCapturingThumbnail = false
    private var thumbnailQueue: [Int] = []
    private var thumbnailCache: [String: UIImage] = [:]
    private var exportService: VideoExportService?
    private var progressOverlay: ExportProgressOverlay?

    // MARK: - UI Elements

    // Stats strip under nav
    private let statsStrip: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let shotsCountLbl: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11, weight: .black)
        l.textColor = UIColor.white.withAlphaComponent(0.28)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let totalDurLbl: UILabel = {
        let l = UILabel()
        l.font = .monospacedDigitSystemFont(ofSize: 11, weight: .bold)
        l.textColor = UIColor.white.withAlphaComponent(0.22)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // Timeline indicator strip (proportional widths per shot)
    private let timelineStrip: UIView = {
        let v = UIView()
        v.clipsToBounds = true
        v.layer.cornerRadius = 3
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 12
        layout.minimumInteritemSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 40, right: 16)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.register(ShotCardCell.self, forCellWithReuseIdentifier: ShotCardCell.reuseID)
        cv.dataSource = self
        cv.delegate = self
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.45
        cv.addGestureRecognizer(longPress)
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    private let emptyLabel: UILabel = {
        let l = UILabel()
        l.text = "No shots detected.\nAdd scene cameras and animate them."
        l.numberOfLines = 0
        l.textAlignment = .center
        l.font = .systemFont(ofSize: 14, weight: .medium)
        l.textColor = UIColor.white.withAlphaComponent(0.25)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = bgColor
        shots = ShotDerived.derive(from: timeline, cameraItems: cameraItems)
        setupNav()
        setupLayout()
        refresh()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !thumbnailsGenerated {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self = self else { return }
                self.captureThumbnails()
                self.thumbnailsGenerated = true
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // BUG FIX: Clean up the offscreen preview clone so it doesn't affect the live scene
        // Note: arView is weak, so we don't need to nullify it on pop
        // Reset timeline to t=0 so entities return to initial state
        evaluateTimeline?(0)
        thumbnailQueue.removeAll()
        isCapturingThumbnail = false
        thumbnailCache.removeAll()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.rebuildTimelineStrip()
        })
    }

    // MARK: - Nav Setup

    private func setupNav() {
        title = sceneName

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = bgColor
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 16, weight: .semibold)
        ]
        appearance.shadowColor = UIColor.white.withAlphaComponent(0.06)
        navigationController?.navigationBar.standardAppearance   = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.tintColor = .white

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain, target: self, action: #selector(backTapped))

        let playAllBtn = makeNavButton(title: "▶  Play All", action: #selector(playAllTapped))
        let exportAllBtn = makeNavButton(title: "⬆  Export All", action: #selector(exportAllTapped))
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(customView: playAllBtn),
            UIBarButtonItem(customView: exportAllBtn),
        ]
    }

    private func makeNavButton(title: String, action: Selector) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.baseBackgroundColor = accentRed
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 14, bottom: 7, trailing: 14)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var a = attrs
            a.font = .systemFont(ofSize: 13, weight: .semibold)
            return a
        }
        let btn = UIButton(configuration: config)
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }

    // MARK: - Layout

    private func setupLayout() {
        // Stats strip
        statsStrip.addSubview(shotsCountLbl)
        statsStrip.addSubview(totalDurLbl)
        view.addSubview(statsStrip)

        // Timeline strip (proportional color bands)
        view.addSubview(timelineStrip)

        // Main collection
        view.addSubview(collectionView)
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            // Stats strip
            statsStrip.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            statsStrip.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            statsStrip.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            statsStrip.heightAnchor.constraint(equalToConstant: 18),

            shotsCountLbl.leadingAnchor.constraint(equalTo: statsStrip.leadingAnchor),
            shotsCountLbl.centerYAnchor.constraint(equalTo: statsStrip.centerYAnchor),

            totalDurLbl.trailingAnchor.constraint(equalTo: statsStrip.trailingAnchor),
            totalDurLbl.centerYAnchor.constraint(equalTo: statsStrip.centerYAnchor),

            // Timeline strip — 4pt tall, full width
            timelineStrip.topAnchor.constraint(equalTo: statsStrip.bottomAnchor, constant: 10),
            timelineStrip.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            timelineStrip.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            timelineStrip.heightAnchor.constraint(equalToConstant: 4),

            // Collection
            collectionView.topAnchor.constraint(equalTo: timelineStrip.bottomAnchor, constant: 4),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Empty state
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
        ])
    }

    // MARK: - Timeline Strip Builder
    // Renders proportional colored bands representing each shot's duration

    private var stripColors: [UIColor] = [
        UIColor(red: 0.694, green: 0.125, blue: 0.224, alpha: 1),
        UIColor(red: 0.18, green: 0.44, blue: 0.78, alpha: 1),
        UIColor(red: 0.12, green: 0.65, blue: 0.45, alpha: 1),
        UIColor(red: 0.72, green: 0.45, blue: 0.12, alpha: 1),
        UIColor(red: 0.55, green: 0.22, blue: 0.75, alpha: 1),
    ]

    private func rebuildTimelineStrip() {
        timelineStrip.subviews.forEach { $0.removeFromSuperview() }
        guard !shots.isEmpty else { return }
        let total = shots.reduce(0) { $0 + $1.duration }
        guard total > 0 else { return }

        var prev: UIView? = nil
        for (i, shot) in shots.enumerated() {
            let ratio = CGFloat(shot.duration / total)
            let seg = UIView()
            seg.backgroundColor = stripColors[i % stripColors.count].withAlphaComponent(0.7)
            seg.translatesAutoresizingMaskIntoConstraints = false
            timelineStrip.addSubview(seg)

            seg.topAnchor.constraint(equalTo: timelineStrip.topAnchor).isActive = true
            seg.bottomAnchor.constraint(equalTo: timelineStrip.bottomAnchor).isActive = true

            if let p = prev {
                seg.leadingAnchor.constraint(equalTo: p.trailingAnchor, constant: 1).isActive = true
            } else {
                seg.leadingAnchor.constraint(equalTo: timelineStrip.leadingAnchor).isActive = true
            }

            if i == shots.count - 1 {
                seg.trailingAnchor.constraint(equalTo: timelineStrip.trailingAnchor).isActive = true
            } else {
                seg.widthAnchor.constraint(
                    equalTo: timelineStrip.widthAnchor,
                    multiplier: ratio
                ).isActive = true
            }
            prev = seg
        }
    }

    // MARK: - Data Refresh

    private func refresh() {
        let isEmpty = shots.isEmpty
        emptyLabel.isHidden = !isEmpty
        collectionView.isHidden = isEmpty
        navigationItem.rightBarButtonItem?.isEnabled = !isEmpty

        let total = shots.reduce(0) { $0 + $1.duration }
        let m = Int(total) / 60
        let s = Int(total) % 60
        shotsCountLbl.text = "\(shots.count) SHOT\(shots.count == 1 ? "" : "S")"
        totalDurLbl.text   = m > 0 ? "\(m)m \(s)s" : "\(s)s"

        collectionView.reloadData()
        rebuildTimelineStrip()
    }

    private func refreshShotsFromTimeline() {
        if let latest = fetchTimeline?() {
            timeline = latest
        }
        shots = ShotDerived.derive(from: timeline, cameraItems: cameraItems)
        refresh()
    }

    // MARK: - Camera POV Thumbnail Capture
    //
    // Sequential capture: for each shot we:
    //   1. evaluateTimeline at shot.startTime  →  positions all entities
    //   2. find the matching SceneCameraItem
    //   3. captureFrameAsync(camItem) → actual POV image
    //   4. store thumbnail, reload cell

    private func captureThumbnails() {
        guard !shots.isEmpty else { return }
        thumbnailQueue = Array(shots.indices)
        captureNextThumbnailIfNeeded()
    }

    private func captureNextThumbnailIfNeeded() {
        guard !isCapturingThumbnail else { return }
        guard let index = thumbnailQueue.first else {
            evaluateTimeline?(0)
            return
        }

        isCapturingThumbnail = true
        thumbnailQueue.removeFirst()

        let shot = shots[index]
        let cacheKey = thumbnailCacheKey(for: shot)
        if let cached = thumbnailCache[cacheKey] {
            shots[index].thumbnail = cached
            reloadThumbnail(at: index)
            isCapturingThumbnail = false
            captureNextThumbnailIfNeeded()
            return
        }

        let camItem = cameraItem(for: shot)
        let doCaptureAtTime = captureAtTime ?? { [weak self] time, _, cb in
            self?.evaluateTimeline?(time)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.033) { [weak self] in
                self?.arView?.snapshot(saveToHDR: false, completion: cb)
            }
        }

        doCaptureAtTime(shot.startTime, camItem) { [weak self] img in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let img = img {
                    self.thumbnailCache[cacheKey] = img
                    self.shots[index].thumbnail = img
                    self.reloadThumbnail(at: index)
                }
                self.isCapturingThumbnail = false
                self.captureNextThumbnailIfNeeded()
            }
        }
    }

    private func reloadThumbnail(at index: Int) {
        let ip = IndexPath(item: index, section: 0)
        if index < collectionView.numberOfItems(inSection: 0) {
            collectionView.reloadItems(at: [ip])
        }
    }

    private func reloadThumbnail(for shot: Shot) {
        guard let index = shots.firstIndex(where: { $0.clipID == shot.clipID }) else { return }
        reloadThumbnail(at: index)
    }

    private func thumbnailCacheKey(for shot: Shot) -> String {
        let camID = shot.cameraID?.uuidString ?? shot.cameraName
        return "\(sceneName)_\(camID)_\(shot.clipID.uuidString)"
    }

    private func cameraItem(for shot: Shot) -> CanvasViewController.SceneCameraItem? {
        if let camID = shot.cameraID {
            return cameraItems.first { $0.id == camID }
        }
        return cameraItems.first { $0.cameraRoot.name == shot.cameraName }
    }

    // MARK: - Actions

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func playAllTapped() {
        guard !shots.isEmpty else { return }
        openPlayer(index: 0, playAll: true)
    }

    @objc private func exportAllTapped() {
        guard !shots.isEmpty else { return }
        let sheet = ExportSettingsSheet(mode: .allShots)
        sheet.onExport = { [weak self] settings in
            self?.beginExportAll(settings: settings)
        }
        present(sheet, animated: true)
    }

    private func beginExportAll(settings: ExportSettings) {
        // Enter playback mode to snapshot base transforms
        enterPlaybackMode?()

        let service = VideoExportService()
        self.exportService = service

        service.evaluateTimeline = evaluateTimeline
        service.prepareForCapture = prepareForCapture
        service.captureFrameAsync = captureFrameAsync
        service.cameraItemForShot = { [weak self] shot in
            self?.cameraItem(for: shot)
        }

        // Show progress overlay
        let overlay = ExportProgressOverlay()
        self.progressOverlay = overlay
        overlay.onCancel = { [weak self] in
            self?.exportService?.cancel()
            self?.progressOverlay?.dismiss {
                self?.exitPlaybackMode?()
                self?.evaluateTimeline?(0)
            }
        }
        overlay.show(in: view)

        service.onProgress = { [weak self] progress in
            self?.progressOverlay?.update(with: progress)
        }

        service.onComplete = { [weak self] url, error in
            guard let self = self else { return }
            self.progressOverlay?.dismiss()
            self.progressOverlay = nil
            self.exportService = nil

            // Exit playback mode and reset timeline
            self.exitPlaybackMode?()
            self.evaluateTimeline?(0)

            if let url = url {
                let haptic = UINotificationFeedbackGenerator()
                haptic.notificationOccurred(.success)
                let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                if let pop = vc.popoverPresentationController {
                    pop.sourceView = self.view
                    pop.sourceRect = CGRect(x: self.view.bounds.midX, y: 60, width: 1, height: 1)
                }
                self.present(vc, animated: true)
            } else if let error = error {
                let alert = UIAlertController(title: "Export Failed",
                                              message: error.localizedDescription,
                                              preferredStyle: .alert)
                alert.addAction(.init(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }

        service.exportAllShots(shots, settings: settings)
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let point = gesture.location(in: collectionView)
        guard let ip = collectionView.indexPathForItem(at: point) else { return }
        showShotActionSheet(for: ip.item, at: point)
    }

    private func showShotActionSheet(for index: Int, at point: CGPoint) {
        guard shots.indices.contains(index) else { return }
        let shot = shots[index]
        let alert = UIAlertController(title: shot.displayName, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteShot(shot)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = alert.popoverPresentationController {
            pop.sourceView = collectionView
            pop.sourceRect = collectionView.layoutAttributesForItem(at: IndexPath(item: index, section: 0))?.frame
                ?? CGRect(x: point.x, y: point.y, width: 1, height: 1)
        }
        present(alert, animated: true)
    }

    private func deleteShot(_ shot: Shot) {
        deleteTimelineClip?(shot.clipID)
        thumbnailCache.removeValue(forKey: thumbnailCacheKey(for: shot))
        refreshShotsFromTimeline()
    }

    private func presentShotEditor(for shot: Shot) {
        guard let clipIndex = timeline.clips.firstIndex(where: { $0.id == shot.clipID }) else { return }
        let clip = timeline.clips[clipIndex]

        let title = "Edit \(shot.displayName)"
        let card = AnimationInputCard(mode: .editShot(
            title: title,
            currentStart: clip.startTime,
            currentDuration: clip.duration
        ))

        card.onConfirm = { [weak self] startTime, duration, _, _ in
            guard let self else { return }

            let candidate = AnimationClip(
                preservingID: clip,
                startTime: startTime,
                duration: duration
            )

            if let conflict = self.clipConflictCheck?(candidate, clip.id) {
                self.presentClipConflictResolution(
                    editedClip: candidate,
                    replacingID: clip.id,
                    conflicting: conflict,
                    clipIndex: clipIndex,
                    originalEndTime: clip.startTime + clip.duration
                )
            } else {
                self.commitClipTimingChange?(candidate, clip.id, clipIndex)
                self.handleClipUpdateCompletion(updatedClip: candidate)
            }
        }

        present(card, animated: false)
    }

    private func presentClipConflictResolution(
        editedClip: AnimationClip,
        replacingID: UUID,
        conflicting: AnimationClip,
        clipIndex: Int,
        originalEndTime: Float
    ) {
        let alert = UIAlertController(
            title: "Animation Timing Conflict",
            message: "The updated animation timing overlaps with another animation for this entity. Choose how you want to resolve the conflict.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        alert.addAction(UIAlertAction(title: "Shift Following Animations", style: .default) { [weak self] _ in
            guard let self else { return }
            self.commitClipTimingChange?(editedClip, replacingID, clipIndex)

            let originalGap   = conflicting.startTime - originalEndTime
            let editedEnd     = editedClip.startTime + editedClip.duration
            let newClipBStart = editedEnd + originalGap
            let shiftDelta    = newClipBStart - conflicting.startTime

            if shiftDelta > 0.0001 {
                self.shiftSubsequentClips?(editedClip.entityName, conflicting.startTime, shiftDelta)
            }
            self.handleClipUpdateCompletion(updatedClip: editedClip)
        })

        alert.addAction(UIAlertAction(title: "Merge Animations", style: .default) { [weak self] _ in
            guard let self else { return }
            self.commitClipTimingChange?(editedClip, replacingID, clipIndex)

            let editedEnd   = editedClip.startTime + editedClip.duration
            let originalEnd = conflicting.startTime + conflicting.duration
            let newDuration = max(0, originalEnd - editedEnd)

            self.mergeConflictingClip?(conflicting, editedEnd, newDuration)
            self.handleClipUpdateCompletion(updatedClip: editedClip)
        })

        present(alert, animated: true)
    }

    private func handleClipUpdateCompletion(updatedClip: AnimationClip) {
        refreshShotsFromTimeline()
        if let shot = shots.first(where: { $0.clipID == updatedClip.id }) {
            thumbnailCache.removeValue(forKey: thumbnailCacheKey(for: shot))
            shots.firstIndex(where: { $0.clipID == updatedClip.id }).map { index in
                thumbnailQueue.append(index)
                captureNextThumbnailIfNeeded()
            }
        }
    }

     private func openPlayer(index: Int, playAll: Bool) {
         let vc = ShotPlayerViewController(
             shots: shots,
             startIndex: index,
             playAll: playAll,
             sceneName: sceneName,
             arView: arView,
             evaluateTimeline: evaluateTimeline,
             captureFrameAsync: captureFrameAsync,
              captureAtTime: captureAtTime,
             cameraItems: cameraItems
         )
         vc.prepareForCapture  = self.prepareForCapture
         vc.enterPlaybackMode  = self.enterPlaybackMode
         vc.exitPlaybackMode   = self.exitPlaybackMode
         navigationController?.pushViewController(vc, animated: true)
     }
 }

// MARK: - UICollectionView DataSource + Delegate

extension ShotBreakdownViewController: UICollectionViewDataSource,
                                        UICollectionViewDelegate,
                                        UICollectionViewDelegateFlowLayout {

    func collectionView(_ cv: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        shots.count
    }

     func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
         guard let cell = cv.dequeueReusableCell(
             withReuseIdentifier: ShotCardCell.reuseID, for: ip) as? ShotCardCell else {
             return UICollectionViewCell()
         }
         let shot = shots[ip.item]
         cell.onEdit = { [weak self] in
             self?.presentShotEditor(for: shot)
         }
         cell.configure(with: shot, accentColor: stripColors[ip.item % stripColors.count])
         return cell
     }

    func collectionView(_ cv: UICollectionView, didSelectItemAt ip: IndexPath) {
        openPlayer(index: ip.item, playAll: false)
    }

    func collectionView(_ cv: UICollectionView,
                        layout _: UICollectionViewLayout,
                        sizeForItemAt _: IndexPath) -> CGSize {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let cols: CGFloat = isIPad ? 3 : 2
        let inset: CGFloat = 16
        let spacing: CGFloat = 12
        let w = floor((cv.bounds.width - inset * 2 - spacing * (cols - 1)) / cols)
        // 16:9 thumbnail + 58pt info bar
        return CGSize(width: w, height: w * (9.0 / 16.0) + 58)
    }
}

// MARK: - Shot Card Cell

final class ShotCardCell: UICollectionViewCell {

    static let reuseID = "ShotCardCell"

    // Palette (instance, not static — avoids repeated alloc)
    private let cardBg  = UIColor(red: 0.086, green: 0.086, blue: 0.141, alpha: 1)
    private let thumbBg = UIColor(red: 0.047, green: 0.047, blue: 0.094, alpha: 1)
    private let infoBg  = UIColor(red: 0.067, green: 0.067, blue: 0.118, alpha: 1)

    // ── Thumbnail area ────────────────────────────────────────────────────────
    private let thumbContainer = UIView()
    private let thumbImageView = UIImageView()
    private let placeholderIcon = UIImageView()
    private let gradientLayer   = CAGradientLayer()
    private let pressOverlay    = UIView()
    private let editButton      = UIButton(type: .system)
    var onEdit: (() -> Void)?

    // ── Number badge (top-left) ────────────────────────────────────────────────
    private let badge    = UIView()
    private let badgeLbl = UILabel()

    // ── Info row ─────────────────────────────────────────────────────────────
    private let infoContainer = UIView()
    private let shotNameLbl   = UILabel()
    private let camNameLbl    = UILabel()
    private let durationLbl   = UILabel()
    private let accentBar     = UIView()   // colour strip on left of info row

    // ── Play button overlay (visible on hover / non-thumbnail) ───────────────
    private let playCircle = UIView()
    private let playIcon   = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = thumbContainer.bounds
    }

    // MARK: - Build

    private func build() {
        // Card chrome
        contentView.backgroundColor    = cardBg
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds      = true

        layer.shadowColor   = UIColor.black.cgColor
        layer.shadowOpacity = 0.55
        layer.shadowRadius  = 10
        layer.shadowOffset  = CGSize(width: 0, height: 5)
        layer.masksToBounds = false

        // ── Thumbnail ─────────────────────────────────────────────────
        thumbContainer.backgroundColor = thumbBg
        thumbContainer.clipsToBounds   = true
        thumbContainer.translatesAutoresizingMaskIntoConstraints = false

        thumbImageView.contentMode = .scaleAspectFill
        thumbImageView.clipsToBounds = true
        thumbImageView.translatesAutoresizingMaskIntoConstraints = false

        let symCfg = UIImage.SymbolConfiguration(pointSize: 26, weight: .ultraLight)
        placeholderIcon.image     = UIImage(systemName: "camera.aperture", withConfiguration: symCfg)
        placeholderIcon.tintColor = UIColor.white.withAlphaComponent(0.1)
        placeholderIcon.contentMode = .scaleAspectFit
        placeholderIcon.translatesAutoresizingMaskIntoConstraints = false

        // Gradient: transparent → dark at bottom
        gradientLayer.colors   = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.55).cgColor]
        gradientLayer.locations = [0.45, 1.0]
        thumbContainer.layer.addSublayer(gradientLayer)

        pressOverlay.backgroundColor = UIColor.black.withAlphaComponent(0)
        pressOverlay.translatesAutoresizingMaskIntoConstraints = false

        thumbContainer.addSubview(thumbImageView)
        thumbContainer.addSubview(placeholderIcon)
        thumbContainer.addSubview(pressOverlay)
        contentView.addSubview(thumbContainer)

        let editCfg = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        editButton.setImage(UIImage(systemName: "pencil", withConfiguration: editCfg), for: .normal)
        editButton.tintColor = UIColor.white.withAlphaComponent(0.85)
        editButton.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        editButton.layer.cornerRadius = 12
        editButton.clipsToBounds = true
        editButton.translatesAutoresizingMaskIntoConstraints = false
        editButton.addAction(UIAction { [weak self] _ in self?.onEdit?() }, for: .touchUpInside)
        thumbContainer.addSubview(editButton)

        // ── Play circle (center of thumbnail, shown when no thumb yet) ─
        playCircle.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        playCircle.layer.cornerRadius = 20
        playCircle.layer.borderWidth  = 1.5
        playCircle.layer.borderColor  = UIColor.white.withAlphaComponent(0.3).cgColor
        playCircle.translatesAutoresizingMaskIntoConstraints = false

        let pSym = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        playIcon.image     = UIImage(systemName: "play.fill", withConfiguration: pSym)
        playIcon.tintColor = UIColor.white.withAlphaComponent(0.8)
        playIcon.contentMode = .scaleAspectFit
        playIcon.translatesAutoresizingMaskIntoConstraints = false
        playCircle.addSubview(playIcon)
        thumbContainer.addSubview(playCircle)

        // ── Badge ──────────────────────────────────────────────────────
        badge.layer.cornerRadius = 5
        badge.clipsToBounds      = true
        badge.translatesAutoresizingMaskIntoConstraints = false
        badgeLbl.font          = .systemFont(ofSize: 10, weight: .black)
        badgeLbl.textColor     = .white
        badgeLbl.textAlignment = .center
        badgeLbl.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(badgeLbl)
        contentView.addSubview(badge)

        // ── Info row ───────────────────────────────────────────────────
        infoContainer.backgroundColor = infoBg
        infoContainer.translatesAutoresizingMaskIntoConstraints = false

        accentBar.layer.cornerRadius = 1.5
        accentBar.translatesAutoresizingMaskIntoConstraints = false

        shotNameLbl.font      = .systemFont(ofSize: 13, weight: .semibold)
        shotNameLbl.textColor = .white
        shotNameLbl.translatesAutoresizingMaskIntoConstraints = false

        camNameLbl.font      = .systemFont(ofSize: 10, weight: .medium)
        camNameLbl.textColor = UIColor.white.withAlphaComponent(0.45)
        camNameLbl.translatesAutoresizingMaskIntoConstraints = false

        durationLbl.font      = .monospacedDigitSystemFont(ofSize: 12, weight: .bold)
        durationLbl.textColor = UIColor.white.withAlphaComponent(0.55)
        durationLbl.translatesAutoresizingMaskIntoConstraints = false

        infoContainer.addSubview(accentBar)
        infoContainer.addSubview(shotNameLbl)
        infoContainer.addSubview(camNameLbl)
        infoContainer.addSubview(durationLbl)
        contentView.addSubview(infoContainer)

        // MARK: Constraints
        NSLayoutConstraint.activate([

            // Thumbnail — 16:9
            thumbContainer.topAnchor.constraint(equalTo: contentView.topAnchor),
            thumbContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thumbContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            thumbContainer.heightAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 9.0/16.0),

            thumbImageView.topAnchor.constraint(equalTo: thumbContainer.topAnchor),
            thumbImageView.leadingAnchor.constraint(equalTo: thumbContainer.leadingAnchor),
            thumbImageView.trailingAnchor.constraint(equalTo: thumbContainer.trailingAnchor),
            thumbImageView.bottomAnchor.constraint(equalTo: thumbContainer.bottomAnchor),

            placeholderIcon.centerXAnchor.constraint(equalTo: thumbContainer.centerXAnchor),
            placeholderIcon.centerYAnchor.constraint(equalTo: thumbContainer.centerYAnchor),
            placeholderIcon.widthAnchor.constraint(equalToConstant: 36),
            placeholderIcon.heightAnchor.constraint(equalToConstant: 36),

            pressOverlay.topAnchor.constraint(equalTo: thumbContainer.topAnchor),
            pressOverlay.leadingAnchor.constraint(equalTo: thumbContainer.leadingAnchor),
            pressOverlay.trailingAnchor.constraint(equalTo: thumbContainer.trailingAnchor),
            pressOverlay.bottomAnchor.constraint(equalTo: thumbContainer.bottomAnchor),

            // Play circle — centered
            playCircle.centerXAnchor.constraint(equalTo: thumbContainer.centerXAnchor),
            playCircle.centerYAnchor.constraint(equalTo: thumbContainer.centerYAnchor),
            playCircle.widthAnchor.constraint(equalToConstant: 40),
            playCircle.heightAnchor.constraint(equalToConstant: 40),
            playIcon.centerXAnchor.constraint(equalTo: playCircle.centerXAnchor, constant: 1.5),
            playIcon.centerYAnchor.constraint(equalTo: playCircle.centerYAnchor),
            playIcon.widthAnchor.constraint(equalToConstant: 14),
            playIcon.heightAnchor.constraint(equalToConstant: 14),

            editButton.topAnchor.constraint(equalTo: thumbContainer.topAnchor, constant: 8),
            editButton.trailingAnchor.constraint(equalTo: thumbContainer.trailingAnchor, constant: -8),
            editButton.widthAnchor.constraint(equalToConstant: 24),
            editButton.heightAnchor.constraint(equalToConstant: 24),

            // Badge — top-left
            badge.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            badge.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            badge.heightAnchor.constraint(equalToConstant: 20),
            badge.widthAnchor.constraint(greaterThanOrEqualToConstant: 24),

            badgeLbl.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: 6),
            badgeLbl.trailingAnchor.constraint(equalTo: badge.trailingAnchor, constant: -6),
            badgeLbl.centerYAnchor.constraint(equalTo: badge.centerYAnchor),

            // Info row — flush bottom
            infoContainer.topAnchor.constraint(equalTo: thumbContainer.bottomAnchor),
            infoContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            infoContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            infoContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            accentBar.leadingAnchor.constraint(equalTo: infoContainer.leadingAnchor),
            accentBar.topAnchor.constraint(equalTo: infoContainer.topAnchor),
            accentBar.bottomAnchor.constraint(equalTo: infoContainer.bottomAnchor),
            accentBar.widthAnchor.constraint(equalToConstant: 3),

            shotNameLbl.topAnchor.constraint(equalTo: infoContainer.topAnchor, constant: 9),
            shotNameLbl.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: 10),
            shotNameLbl.trailingAnchor.constraint(lessThanOrEqualTo: durationLbl.leadingAnchor, constant: -6),

            camNameLbl.topAnchor.constraint(equalTo: shotNameLbl.bottomAnchor, constant: 2),
            camNameLbl.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: 10),
            camNameLbl.trailingAnchor.constraint(lessThanOrEqualTo: infoContainer.trailingAnchor, constant: -10),
            camNameLbl.bottomAnchor.constraint(lessThanOrEqualTo: infoContainer.bottomAnchor, constant: -8),

            durationLbl.centerYAnchor.constraint(equalTo: infoContainer.centerYAnchor),
            durationLbl.trailingAnchor.constraint(equalTo: infoContainer.trailingAnchor, constant: -12),
        ])
    }

    // MARK: - Configure

    func configure(with shot: Shot, accentColor: UIColor) {
        badgeLbl.text     = shot.shortLabel
        shotNameLbl.text  = shot.displayName
        camNameLbl.text   = shot.cleanCameraName
        badge.backgroundColor  = accentColor
        accentBar.backgroundColor = accentColor.withAlphaComponent(0.8)

        let d = shot.duration
        durationLbl.text = d.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(d))s"
            : String(format: "%.1fs", d)

        if let img = shot.thumbnail {
            thumbImageView.image = img
            thumbImageView.isHidden = false
            placeholderIcon.isHidden = true
            playCircle.isHidden = true
        } else {
            thumbImageView.image = nil
            thumbImageView.isHidden = true
            placeholderIcon.isHidden = false
            playCircle.isHidden = false
        }
    }

    // MARK: - Press Animation

    override func touchesBegan(_ t: Set<UITouch>, with e: UIEvent?) {
        super.touchesBegan(t, with: e)
        UIView.animate(withDuration: 0.12, delay: 0, options: .allowUserInteraction, animations: {
            self.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
            self.pressOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        })
    }

    override func touchesEnded(_ t: Set<UITouch>, with e: UIEvent?) {
        super.touchesEnded(t, with: e)
        UIView.animate(withDuration: 0.18, delay: 0, options: .allowUserInteraction, animations: {
            self.transform = .identity
            self.pressOverlay.backgroundColor = .clear
        })
    }

    override func touchesCancelled(_ t: Set<UITouch>, with e: UIEvent?) {
        super.touchesCancelled(t, with: e)
        UIView.animate(withDuration: 0.18, delay: 0, options: .allowUserInteraction, animations: {
            self.transform = .identity
            self.pressOverlay.backgroundColor = .clear
        })
    }
}
