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
    let startTime: Float
    let duration: Float
    var thumbnail: UIImage?

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
    static func derive(from timeline: Timeline, cameraNames: [String]) -> [Shot] {
        let totalDuration = timeline.duration
        guard totalDuration > 0 else { return [] }

        // FIX: Filter ONLY for clips that exactly match camera entity names.
        // Only show shots that are assigned to an actual camera — no props or other entities.
        let cameraClips = timeline.clips.filter { clip in
            cameraNames.contains(clip.entityName)
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
        return sortedClips.enumerated().map { (index, clip) in
            Shot(
                id: UUID(),
                index: index,
                cameraName: clip.entityName,
                startTime: clip.startTime,
                duration: clip.duration,
                thumbnail: nil
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
    var cameraNames: [String] = []
    weak var arView: ARView?
    var evaluateTimeline: ((Float) -> Void)?
    var cameraItems: [CanvasViewController.SceneCameraItem] = []
    var captureFrameAsync: ((CanvasViewController.SceneCameraItem?, @escaping (UIImage?) -> Void) -> Void)?

    // MARK: - State
    private var shots: [Shot] = []
    private var thumbnailsGenerated = false

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
        shots = ShotDerived.derive(from: timeline, cameraNames: cameraNames)
        setupNav()
        setupLayout()
        refresh()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !thumbnailsGenerated { captureThumbnails(); thumbnailsGenerated = true }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // BUG FIX: Clean up the offscreen preview clone so it doesn't affect the live scene
        // Note: arView is weak, so we don't need to nullify it on pop
        // Reset timeline to t=0 so entities return to initial state
        evaluateTimeline?(0)
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

        let playAllBtn = makeNavButton(title: "▶  Play All")
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: playAllBtn)
    }

    private func makeNavButton(title: String) -> UIButton {
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
        btn.addTarget(self, action: #selector(playAllTapped), for: .touchUpInside)
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

    // MARK: - Camera POV Thumbnail Capture
    //
    // Sequential capture: for each shot we:
    //   1. evaluateTimeline at shot.startTime  →  positions all entities
    //   2. find the matching SceneCameraItem
    //   3. captureFrameAsync(camItem) → actual POV image
    //   4. store thumbnail, reload cell

    private func captureThumbnails() {
        guard let evaluate = evaluateTimeline else { return }
        let count = shots.count
        var capturedCount = 0
        let lock = NSLock() // Thread-safe counter

        // Capture all thumbnails in parallel with a small staggered delay
        for (index, _) in shots.enumerated() {
            let shot = shots[index]
            let delayOffset = Double(index) * 0.02 // Stagger by 20ms to avoid GPU spike
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delayOffset) { [weak self] in
                guard let self = self else { return }
                
                // Scrub timeline to shot time
                evaluate(shot.startTime)
                
                // Wait a minimal amount for scene to update (33ms = one frame at 30fps)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.033) { [weak self] in
                    guard let self = self else { return }
                    
                    // Find matching camera item
                    let camItem = self.cameraItems.first {
                        $0.cameraRoot.name == shot.cameraName
                    } ?? self.cameraItems.first {
                        $0.cameraRoot.name.contains(shot.cameraName) ||
                        shot.cameraName.contains($0.cameraRoot.name)
                    } ?? self.cameraItems.first { _ in true }
                    
                    let doCapture = self.captureFrameAsync ?? { _, cb in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) {
                            self.arView?.snapshot(saveToHDR: false, completion: cb)
                        }
                    }
                    
                    doCapture(camItem) { [weak self] img in
                        DispatchQueue.main.async {
                            guard let self = self else { return }
                            if let img = img {
                                self.shots[index].thumbnail = img
                                let ip = IndexPath(item: index, section: 0)
                                if index < self.collectionView.numberOfItems(inSection: 0) {
                                    self.collectionView.reloadItems(at: [ip])
                                }
                            }
                            
                            // Track completion and reset timeline when all done
                            lock.lock()
                            capturedCount += 1
                            let allCaptured = (capturedCount == count)
                            lock.unlock()
                            
                            if allCaptured {
                                // Restore timeline to start after all captures
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    evaluate(0)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func playAllTapped() {
        guard !shots.isEmpty else { return }
        openPlayer(index: 0, playAll: true)
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
            cameraItems: cameraItems
        )
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
        let cell = cv.dequeueReusableCell(
            withReuseIdentifier: ShotCardCell.reuseID, for: ip) as! ShotCardCell
        cell.configure(with: shots[ip.item], accentColor: stripColors[ip.item % stripColors.count])
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
