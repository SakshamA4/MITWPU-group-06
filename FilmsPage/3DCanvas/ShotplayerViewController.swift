//
//  ShotPlayerViewController.swift
//  3DCanvas
//
//  REDESIGN: Clean, cinematic player UI.
//  - Large 16:9 frame view with real camera-POV rendering per shot
//  - Camera switches to the shot's assigned SceneCameraItem on every frame
//  - Compact controls panel below the frame
//  - Horizontal film-strip with thumbnails at the bottom
//  - Export: JPEG / PNG / MP4 via AVAssetWriter
//

import UIKit
import RealityKit
import AVFoundation

final class ShotPlayerViewController: UIViewController {

    // MARK: - Palette
    private let bgColor    = UIColor(red: 0.043, green: 0.043, blue: 0.086, alpha: 1) // #0B0B16
    private let panelColor = UIColor(red: 0.067, green: 0.067, blue: 0.118, alpha: 1) // #111130
    private let thumbBg    = UIColor(red: 0.039, green: 0.039, blue: 0.078, alpha: 1) // #0A0A14
    private let accentRed  = UIColor(red: 0.694, green: 0.125, blue: 0.224, alpha: 1) // #B12038

    private let stripColors: [UIColor] = [
        UIColor(red: 0.694, green: 0.125, blue: 0.224, alpha: 1),
        UIColor(red: 0.18,  green: 0.44,  blue: 0.78,  alpha: 1),
        UIColor(red: 0.12,  green: 0.65,  blue: 0.45,  alpha: 1),
        UIColor(red: 0.72,  green: 0.45,  blue: 0.12,  alpha: 1),
        UIColor(red: 0.55,  green: 0.22,  blue: 0.75,  alpha: 1),
    ]

    // MARK: - Init

    init(shots: [Shot],
         startIndex: Int,
         playAll: Bool,
         sceneName: String,
         arView: ARView?,
         evaluateTimeline: ((Float) -> Void)?,
         captureFrameAsync: ((CanvasViewController.SceneCameraItem?, @escaping (UIImage?) -> Void) -> Void)? = nil,
         cameraItems: [CanvasViewController.SceneCameraItem] = []) {
        self.shots            = shots
        self.currentIndex     = startIndex
        self.playAll          = playAll
        self.sceneName        = sceneName
        self.arView           = arView
        self.evaluateTimeline = evaluateTimeline
        self.captureFrameAsync = captureFrameAsync
        self.cameraItems      = cameraItems
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

     // MARK: - State

     var shots: [Shot]
     var currentIndex: Int
     var playAll: Bool
     var sceneName: String
     weak var arView: ARView?
     var evaluateTimeline: ((Float) -> Void)?
     var captureFrameAsync: ((CanvasViewController.SceneCameraItem?, @escaping (UIImage?) -> Void) -> Void)?
     var cameraItems: [CanvasViewController.SceneCameraItem]

     private var isPlaying       = false
     private var snapshotInFlight: UIImage? = nil  // FIX: Replace pendingSnapshot boolean with result holder
     private var snapshotPending: Bool = false    // Tracks if snapshot request is currently being processed
     private var displayLink: CADisplayLink?
     private var playStart:   CFTimeInterval = 0
     private var currentTime: Float = 0
     private var lastSnapshotTime: CFTimeInterval = 0
     private var currentShot: Shot { shots[currentIndex] }

     // MARK: - Layout state

    /// Active portrait/landscape NSLayoutConstraint sets — swapped on rotation.
    private var portraitConstraints:  [NSLayoutConstraint] = []
    private var landscapeConstraints: [NSLayoutConstraint] = []
    private var activeOrientationConstraints: [NSLayoutConstraint] = []

    // MARK: - UI: Frame Viewer

    /// Full-bleed frame that shows the shot's camera POV render.
    private lazy var frameView: UIView = {
        let v = UIView()
        v.backgroundColor = thumbBg
        v.clipsToBounds   = true
        v.layer.cornerRadius = 4
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var frameImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let framePlaceholder: UIImageView = {
        let iv = UIImageView()
        let cfg = UIImage.SymbolConfiguration(pointSize: 36, weight: .ultraLight)
        iv.image     = UIImage(systemName: "camera.aperture", withConfiguration: cfg)
        iv.tintColor = UIColor.white.withAlphaComponent(0.06)
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let loadingSpinner: UIActivityIndicatorView = {
        let s = UIActivityIndicatorView(style: .medium)
        s.color = UIColor.white.withAlphaComponent(0.25)
        s.hidesWhenStopped = true
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    // MARK: - UI: HUD chips (overlaid on frame corners)

    /// Shot label — top-left chip
    private let hudShotLbl: UILabel = {
        let l = UILabel()
        l.font            = .systemFont(ofSize: 11, weight: .bold)
        l.textColor       = .white
        l.backgroundColor = UIColor.black.withAlphaComponent(0.52)
        l.layer.cornerRadius = 4; l.clipsToBounds = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    /// Camera name — below shot label
    private let hudCamLbl: UILabel = {
        let l = UILabel()
        l.font            = .systemFont(ofSize: 10, weight: .medium)
        l.textColor       = UIColor.white.withAlphaComponent(0.70)
        l.backgroundColor = UIColor.black.withAlphaComponent(0.40)
        l.layer.cornerRadius = 4; l.clipsToBounds = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    /// Timecode — top-right chip
    private let hudTimeLbl: UILabel = {
        let l = UILabel()
        l.font            = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        l.textColor       = .white
        l.backgroundColor = UIColor.black.withAlphaComponent(0.50)
        l.layer.cornerRadius = 4; l.clipsToBounds = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    /// Cut transition banner — fades in/out at center of frame
    private let cutFlashLbl: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12, weight: .semibold)
        l.textColor = UIColor.white.withAlphaComponent(0.80)
        l.backgroundColor = UIColor.black.withAlphaComponent(0.60)
        l.layer.cornerRadius = 5; l.clipsToBounds = true
        l.textAlignment = .center
        l.alpha = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - UI: Progress / scrubber row (sits below frame)

    private lazy var progressBar: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.white.withAlphaComponent(0.04)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let progressTrack: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        v.layer.cornerRadius = 2.5
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var progressFill: UIView = {
        let v = UIView()
        v.backgroundColor = accentRed
        v.layer.cornerRadius = 2.5
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var scrubber: UISlider = {
        let s = UISlider()
        s.minimumValue = 0; s.maximumValue = 1; s.value = 0
        s.minimumTrackTintColor = .clear
        s.maximumTrackTintColor = .clear
        s.thumbTintColor = .white
        s.translatesAutoresizingMaskIntoConstraints = false
        s.addTarget(self, action: #selector(scrubChanged), for: .valueChanged)
        s.addTarget(self, action: #selector(scrubTouchDown), for: .touchDown)
        s.addTarget(self, action: #selector(scrubTouchUp), for: [.touchUpInside, .touchUpOutside])
        return s
    }()

    private let scrubStartLbl: UILabel = {
        let l = UILabel()
        l.font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        l.textColor = UIColor.white.withAlphaComponent(0.40)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let scrubEndLbl: UILabel = {
        let l = UILabel()
        l.font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        l.textColor = UIColor.white.withAlphaComponent(0.40)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private var progressFillWidthConstraint: NSLayoutConstraint?

    // MARK: - UI: Right-side panel (controls + shot list)

    /// Dark sidebar container visible in landscape; collapses to a bottom strip in portrait.
    private lazy var sidePanel: UIView = {
        let v = UIView()
        v.backgroundColor = panelColor
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // Shot name + camera name stacked above buttons
    private let shotNameLbl: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15, weight: .semibold)
        l.textColor = .white
        l.textAlignment = .center
        l.adjustsFontSizeToFitWidth = true
        l.minimumScaleFactor = 0.75
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let camNameLbl: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11, weight: .regular)
        l.textColor = UIColor.white.withAlphaComponent(0.42)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // Thin accent line under shot name
    private lazy var accentBar: UIView = {
        let v = UIView()
        v.backgroundColor = accentRed
        v.layer.cornerRadius = 1
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // Controls panel (still used for the button row)
    private lazy var controlsPanel: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // The old shotInfoLbl is kept as an alias so syncToCurrentShot() compiles unchanged
    private var shotInfoLbl: UILabel { camNameLbl }

    private lazy var prevBtn  = makeControlBtn(icon: "backward.end.fill",  size: 16)
    private lazy var playBtn  = makeControlBtn(icon: "play.fill",           size: 22)
    private lazy var nextBtn  = makeControlBtn(icon: "forward.end.fill",    size: 16)

    // MARK: - UI: Film Strip

    private lazy var filmStrip: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection    = .horizontal
        layout.minimumLineSpacing = 8
        layout.sectionInset       = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.register(StripCell.self, forCellWithReuseIdentifier: StripCell.reuseID)
        cv.dataSource = self; cv.delegate = self
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    private let filmStripLabel: UILabel = {
        let l = UILabel()
        l.text = "SHOTS"
        l.font = .systemFont(ofSize: 9, weight: .black)
        l.textColor = UIColor.white.withAlphaComponent(0.20)
        l.letterSpacing(1.5)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Lifecycle

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Ensure buttons are perfect circles after Auto Layout resolves their sizes
        for btn in [prevBtn, nextBtn] {
            btn.layer.cornerRadius = btn.bounds.height / 2
        }
        playBtn.layer.cornerRadius = playBtn.bounds.height / 2
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = bgColor
        setupNav()
        buildLayout()
        syncToCurrentShot()
        if playAll { startPlayback() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopPlayback()
        evaluateTimeline?(0)
        frameImageView.image = nil
        snapshotInFlight = nil
    }

    override func viewWillTransition(to size: CGSize,
                                     with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self = self else { return }
            self.applyOrientation(size: size)
            self.filmStrip.collectionViewLayout.invalidateLayout()
        })
    }

    // MARK: - Nav Setup

    private func setupNav() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = bgColor
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 15, weight: .semibold)
        ]
        appearance.shadowColor = UIColor.white.withAlphaComponent(0.05)
        navigationController?.navigationBar.standardAppearance   = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.tintColor = .white

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain, target: self, action: #selector(backTapped))

        let exportItem = UIBarButtonItem(
            title: "Export", style: .plain,
            target: self, action: #selector(exportTapped))
        exportItem.setTitleTextAttributes(
            [.foregroundColor: accentRed,
             .font: UIFont.systemFont(ofSize: 14, weight: .semibold)],
            for: .normal)
        navigationItem.rightBarButtonItem = exportItem
    }



    private func buildLayout() {
        // ── Frame internals (image + HUD chips only — NO scrubber inside frame) ─
        frameView.addSubview(frameImageView)
        frameView.addSubview(framePlaceholder)
        frameView.addSubview(loadingSpinner)
        frameView.addSubview(hudShotLbl)
        frameView.addSubview(hudCamLbl)
        frameView.addSubview(hudTimeLbl)
        frameView.addSubview(cutFlashLbl)


        progressTrack.addSubview(progressFill)
        progressBar.addSubview(scrubStartLbl)
        progressBar.addSubview(progressTrack)
        progressBar.addSubview(scrubber)
        progressBar.addSubview(scrubEndLbl)

        // Shot info row — name left, cam right in landscape; stacked in portrait
        sidePanel.addSubview(shotNameLbl)
        sidePanel.addSubview(camNameLbl)
        sidePanel.addSubview(accentBar)

        let btnStack = UIStackView(arrangedSubviews: [prevBtn, playBtn, nextBtn])
        btnStack.axis      = .horizontal
        btnStack.alignment = .center
        btnStack.spacing   = 28
        btnStack.translatesAutoresizingMaskIntoConstraints = false
        controlsPanel.addSubview(btnStack)

        sidePanel.addSubview(controlsPanel)
        sidePanel.addSubview(progressBar)
        sidePanel.addSubview(filmStripLabel)
        sidePanel.addSubview(filmStrip)

        // ── Root hierarchy ─────────────────────────────────────────────────────
        view.addSubview(frameView)
        view.addSubview(sidePanel)
        let divider = hairline()
        view.addSubview(divider)

        // ── Fill-width progress constraint ─────────────────────────────────────
        let fillW = progressFill.widthAnchor.constraint(equalToConstant: 0)
        fillW.isActive = true
        progressFillWidthConstraint = fillW

        // ── Adaptive sizing ────────────────────────────────────────────────────
        let is13inch = UIScreen.main.bounds.width >= 1024 || UIScreen.main.bounds.height >= 1024
        let btnSize:  CGFloat = is13inch ? 56 : 50
        let playSize: CGFloat = is13inch ? 62 : 56
        let sidePanelWidth: CGFloat = is13inch ? 280 : 240

        // ── SHARED constraints (both orientations) ─────────────────────────────
        NSLayoutConstraint.activate([

            // Frame image fills entire frameView
            frameImageView.topAnchor.constraint(equalTo: frameView.topAnchor),
            frameImageView.leadingAnchor.constraint(equalTo: frameView.leadingAnchor),
            frameImageView.trailingAnchor.constraint(equalTo: frameView.trailingAnchor),
            frameImageView.bottomAnchor.constraint(equalTo: frameView.bottomAnchor),

            // Placeholder icon — centered
            framePlaceholder.centerXAnchor.constraint(equalTo: frameView.centerXAnchor),
            framePlaceholder.centerYAnchor.constraint(equalTo: frameView.centerYAnchor),
            framePlaceholder.widthAnchor.constraint(equalToConstant: 44),
            framePlaceholder.heightAnchor.constraint(equalToConstant: 44),

            loadingSpinner.centerXAnchor.constraint(equalTo: frameView.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: frameView.centerYAnchor),

            // HUD top-left: shot name chip
            hudShotLbl.topAnchor.constraint(equalTo: frameView.topAnchor, constant: 10),
            hudShotLbl.leadingAnchor.constraint(equalTo: frameView.leadingAnchor, constant: 10),
            // HUD top-left: camera name chip below shot
            hudCamLbl.topAnchor.constraint(equalTo: hudShotLbl.bottomAnchor, constant: 3),
            hudCamLbl.leadingAnchor.constraint(equalTo: frameView.leadingAnchor, constant: 10),
            // HUD top-right: timecode
            hudTimeLbl.topAnchor.constraint(equalTo: frameView.topAnchor, constant: 10),
            hudTimeLbl.trailingAnchor.constraint(equalTo: frameView.trailingAnchor, constant: -10),
            // Cut flash banner — vertically centred
            cutFlashLbl.centerXAnchor.constraint(equalTo: frameView.centerXAnchor),
            cutFlashLbl.centerYAnchor.constraint(equalTo: frameView.centerYAnchor),

            // ── Side panel top info row ────────────────────────────────────────
            // Shot name — left-aligned, top of panel
            shotNameLbl.topAnchor.constraint(equalTo: sidePanel.topAnchor, constant: 14),
            shotNameLbl.leadingAnchor.constraint(equalTo: sidePanel.leadingAnchor, constant: 16),
            // Camera name — right-aligned, vertically centred with shot name
            camNameLbl.centerYAnchor.constraint(equalTo: shotNameLbl.centerYAnchor),
            camNameLbl.trailingAnchor.constraint(equalTo: sidePanel.trailingAnchor, constant: -16),
            camNameLbl.leadingAnchor.constraint(greaterThanOrEqualTo: shotNameLbl.trailingAnchor, constant: 8),
            // Thin accent underline
            accentBar.topAnchor.constraint(equalTo: shotNameLbl.bottomAnchor, constant: 8),
            accentBar.leadingAnchor.constraint(equalTo: sidePanel.leadingAnchor, constant: 16),
            accentBar.widthAnchor.constraint(equalToConstant: 28),
            accentBar.heightAnchor.constraint(equalToConstant: 2),

            // ── Button row (controls panel) ────────────────────────────────────
            controlsPanel.topAnchor.constraint(equalTo: accentBar.bottomAnchor, constant: 10),
            controlsPanel.leadingAnchor.constraint(equalTo: sidePanel.leadingAnchor),
            controlsPanel.trailingAnchor.constraint(equalTo: sidePanel.trailingAnchor),
            controlsPanel.heightAnchor.constraint(equalToConstant: playSize + 16),

            btnStack.centerXAnchor.constraint(equalTo: controlsPanel.centerXAnchor),
            btnStack.centerYAnchor.constraint(equalTo: controlsPanel.centerYAnchor),

            prevBtn.widthAnchor.constraint(equalToConstant: btnSize),
            prevBtn.heightAnchor.constraint(equalToConstant: btnSize),
            playBtn.widthAnchor.constraint(equalToConstant: playSize),
            playBtn.heightAnchor.constraint(equalToConstant: playSize),
            nextBtn.widthAnchor.constraint(equalToConstant: btnSize),
            nextBtn.heightAnchor.constraint(equalToConstant: btnSize),

            // ── Scrubber / timeline row — BELOW buttons ────────────────────────
            progressBar.topAnchor.constraint(equalTo: controlsPanel.bottomAnchor, constant: 4),
            progressBar.leadingAnchor.constraint(equalTo: sidePanel.leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: sidePanel.trailingAnchor),
            progressBar.heightAnchor.constraint(equalToConstant: 40),

            scrubStartLbl.leadingAnchor.constraint(equalTo: progressBar.leadingAnchor, constant: 14),
            scrubStartLbl.centerYAnchor.constraint(equalTo: progressBar.centerYAnchor),
            scrubStartLbl.widthAnchor.constraint(equalToConstant: 38),

            scrubEndLbl.trailingAnchor.constraint(equalTo: progressBar.trailingAnchor, constant: -14),
            scrubEndLbl.centerYAnchor.constraint(equalTo: progressBar.centerYAnchor),
            scrubEndLbl.widthAnchor.constraint(equalToConstant: 38),

            progressTrack.leadingAnchor.constraint(equalTo: scrubStartLbl.trailingAnchor, constant: 8),
            progressTrack.trailingAnchor.constraint(equalTo: scrubEndLbl.leadingAnchor, constant: -8),
            progressTrack.centerYAnchor.constraint(equalTo: progressBar.centerYAnchor),
            progressTrack.heightAnchor.constraint(equalToConstant: 4),

            progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
            progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),

            scrubber.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor, constant: -12),
            scrubber.trailingAnchor.constraint(equalTo: progressTrack.trailingAnchor, constant: 12),
            scrubber.centerYAnchor.constraint(equalTo: progressBar.centerYAnchor),

            // ── Film strip — below scrubber row ───────────────────────────────
            filmStripLabel.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 10),
            filmStripLabel.leadingAnchor.constraint(equalTo: sidePanel.leadingAnchor, constant: 16),

            filmStrip.topAnchor.constraint(equalTo: filmStripLabel.bottomAnchor, constant: 6),
            filmStrip.leadingAnchor.constraint(equalTo: sidePanel.leadingAnchor),
            filmStrip.trailingAnchor.constraint(equalTo: sidePanel.trailingAnchor),
            filmStrip.bottomAnchor.constraint(lessThanOrEqualTo: sidePanel.bottomAnchor, constant: -8),
            filmStrip.heightAnchor.constraint(equalToConstant: is13inch ? 78 : 68),
        ])

        // ── LANDSCAPE: frame left (16:9), side panel right column ─────────────
        landscapeConstraints = [
            frameView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            frameView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 10),
            frameView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            frameView.trailingAnchor.constraint(equalTo: sidePanel.leadingAnchor),
            frameView.widthAnchor.constraint(equalTo: frameView.heightAnchor, multiplier: 16.0 / 9.0),

            divider.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            divider.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: sidePanel.leadingAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),

            sidePanel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            sidePanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sidePanel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sidePanel.widthAnchor.constraint(equalToConstant: sidePanelWidth),
        ]

        // ── PORTRAIT: frame top (16:9), side panel full-width strip below ──────
        portraitConstraints = [
            frameView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            frameView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            frameView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            frameView.heightAnchor.constraint(equalTo: frameView.widthAnchor, multiplier: 9.0 / 16.0),

            divider.topAnchor.constraint(equalTo: frameView.bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1),

            sidePanel.topAnchor.constraint(equalTo: divider.bottomAnchor),
            sidePanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sidePanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sidePanel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ]

        // Activate for whichever orientation we're currently in
        applyOrientation(size: view.bounds.size)
    }

    /// Swaps between portrait/landscape constraint sets cleanly — no constraint conflicts.
    private func applyOrientation(size: CGSize) {
        let isLandscape = size.width > size.height
        NSLayoutConstraint.deactivate(activeOrientationConstraints)
        activeOrientationConstraints = isLandscape ? landscapeConstraints : portraitConstraints
        NSLayoutConstraint.activate(activeOrientationConstraints)

        // Adjust film strip cell size based on orientation + available panel width
        let is13inch = UIScreen.main.bounds.width >= 1024 || UIScreen.main.bounds.height >= 1024
        let cellH: CGFloat = is13inch ? 72 : 64
        let cellW: CGFloat = isLandscape
            ? (is13inch ? 100 : 88)   // wider cells in the side panel
            : (is13inch ? 84 : 74)    // slightly narrower for portrait strip

        if let layout = filmStrip.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.itemSize = CGSize(width: cellW, height: cellH)
            layout.scrollDirection = isLandscape ? .vertical : .horizontal
        }

        view.layoutIfNeeded()
    }

    private func hairline() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    // MARK: - Sync to Current Shot
    // Updates all UI labels and fires the first frame capture for the shot.

    private func syncToCurrentShot() {
        let shot = currentShot
        let accent = stripColors[currentIndex % stripColors.count]

        title = "\(sceneName)  ·  \(shot.displayName)"

        // Side panel labels
        shotNameLbl.text  = shot.displayName
        camNameLbl.text   = shot.cleanCameraName
        accentBar.backgroundColor = accent

        scrubEndLbl.text   = fmt(shot.duration)
        scrubStartLbl.text = "00:00"
        scrubber.value     = 0
        currentTime        = 0

        // Progress fill tint matches shot accent
        progressFill.backgroundColor = accent

        // HUD chips
        hudShotLbl.text = "  \(shot.displayName)  "
        hudCamLbl.text  = "  \(shot.cleanCameraName)  "
        hudTimeLbl.text = "  00:00 / \(fmt(shot.duration))  "

        // Film strip
        filmStrip.reloadData()
        if currentIndex < shots.count {
            filmStrip.scrollToItem(
                at: IndexPath(item: currentIndex, section: 0),
                at: .centeredHorizontally, animated: true)
        }

        // Capture first frame from the shot's camera POV
        captureFrame(at: shot.startTime, force: true)
    }

    // MARK: - Camera POV Frame Capture
    //
    // Finds the SceneCameraItem matching the current shot's cameraName,
    // then calls captureFrameAsync(camItem) which:
    //   1. Clones the live scene into an offscreen ARView
    //   2. Enables only the target PerspectiveCamera in the clone
    //   3. Calls snapshot() on the offscreen view (live view untouched)
    //   4. Returns the UIImage via completion

      private func captureFrame(at masterTime: Float, force: Bool = false) {
          // Always scrub scene entities to the correct time
          evaluateTimeline?(masterTime)

          // FIX: Display any snapshot that arrived and clear the flag
          if let inFlightImage = snapshotInFlight {
              frameImageView.image = inFlightImage
              framePlaceholder.isHidden = true
              snapshotInFlight = nil
              loadingSpinner.stopAnimating()
          }

          let now = CACurrentMediaTime()
          // FIX: Rate-limit snapshots to avoid saturating the snapshot queue
          // During playback: capture at 24fps (1 frame every ~0.04s)
          // When scrubbing: force=true to capture immediately
          let minInterval: CFTimeInterval = isPlaying ? 1.0/24.0 : 0.0
          guard (force || (now - lastSnapshotTime) >= minInterval) else {
              return
          }

          // Don't queue another snapshot if one is already pending
          guard !snapshotPending else {
              return
          }

          lastSnapshotTime = now

          if !isPlaying { loadingSpinner.startAnimating() }

          // Resolve the matching SceneCameraItem for this shot
          let camItem = cameraItem(for: currentShot)

          snapshotPending = true

          let doCapture: (@escaping (UIImage?) -> Void) -> Void
          if let capture = captureFrameAsync {
              doCapture = { cb in capture(camItem, cb) }
          } else {
              doCapture = { [weak self] cb in
                  DispatchQueue.main.asyncAfter(deadline: .now() + 0.033) {
                      self?.arView?.snapshot(saveToHDR: false, completion: cb)
                  }
              }
          }

          doCapture { [weak self] img in
              DispatchQueue.main.async {
                  guard let self = self else { return }
                  // FIX: Always store result in snapshotInFlight, never deadlock
                  if let img = img {
                      self.snapshotInFlight = img
                  }
                  self.snapshotPending = false
              }
          }
      }

    /// Resolves the SceneCameraItem for a given Shot using 4-tier fallback.
    /// Tier 1: Exact name match
    /// Tier 2: Partial name match
    /// Tier 3: Any available camera
    /// Tier 4: nil (falls back to editor camera snapshot)
    private func cameraItem(for shot: Shot) -> CanvasViewController.SceneCameraItem? {
        cameraItems.first { $0.cameraRoot.name == shot.cameraName }
        ?? cameraItems.first {
            $0.cameraRoot.name.contains(shot.cameraName) ||
            shot.cameraName.contains($0.cameraRoot.name)
        }
        ?? cameraItems.first { _ in true }
        // Tier 4: nil if cameraItems is empty
    }

    // MARK: - Playback

     private func startPlayback() {
         stopPlayback()
         isPlaying = true
         playStart = CACurrentMediaTime() - CFTimeInterval(currentTime)
         updatePlayIcon()
         displayLink = CADisplayLink(target: self, selector: #selector(tick))
         displayLink?.add(to: .main, forMode: .common)
     }

     private func stopPlayback() {
         displayLink?.invalidate(); displayLink = nil
         isPlaying = false
         snapshotPending = false  // Clear pending flag on stop
         updatePlayIcon()
     }

    private func updatePlayIcon() {
        let name = isPlaying ? "pause.fill" : "play.fill"
        let cfg  = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
        playBtn.setImage(UIImage(systemName: name, withConfiguration: cfg), for: .normal)
    }

     @objc private func tick() {
         guard isPlaying else { return }
         currentTime = Float(CACurrentMediaTime() - playStart)
         let duration = currentShot.duration

         if currentTime >= duration {
             if playAll && currentIndex < shots.count - 1 {
                 let fromName = currentShot.displayName
                 currentIndex += 1
                 currentTime  = 0
                 playStart    = CACurrentMediaTime()
                 syncToCurrentShot()
                 // Cut flash
                 cutFlashLbl.text = "  \(fromName)  →  \(currentShot.displayName)  "
                 UIView.animate(withDuration: 0.12, animations: { self.cutFlashLbl.alpha = 1 }) { _ in
                     UIView.animate(withDuration: 0.3, delay: 1.0, options: [], animations: { self.cutFlashLbl.alpha = 0 })
                 }
                 return
             } else {
                 currentTime = duration
                 stopPlayback()
             }
         }

         // Update scrubber & time labels
         let progress = currentTime / max(0.001, duration)
         scrubber.value      = progress
         scrubStartLbl.text  = fmt(currentTime)
         hudTimeLbl.text     = "  \(fmt(currentTime)) / \(fmt(duration))  "

         // Update progress fill width
         if let tw = progressTrack.constraints.first(where: { $0.firstAttribute == .width }),
            let fw = progressFillWidthConstraint {
             fw.constant = tw.constant * CGFloat(progress)
         } else {
             // Approximate via bounds on next runloop pass
             DispatchQueue.main.async {
                 self.progressFillWidthConstraint?.constant =
                     self.progressTrack.bounds.width * CGFloat(progress)
             }
         }

         // Capture camera POV frame for the current shot
         let masterTime = currentShot.startTime + currentTime
         captureFrame(at: masterTime)
     }

    // MARK: - Scrubber Actions

    @objc private func scrubChanged(_ s: UISlider) {
        currentTime = s.value * currentShot.duration
        scrubStartLbl.text = fmt(currentTime)
        hudTimeLbl.text = "  \(fmt(currentTime)) / \(fmt(currentShot.duration))  "
        if isPlaying { playStart = CACurrentMediaTime() - CFTimeInterval(currentTime) }
        captureFrame(at: currentShot.startTime + currentTime, force: true)
    }

    @objc private func scrubTouchDown() { stopPlayback() }
    @objc private func scrubTouchUp()   { startPlayback() }

    // MARK: - Button Actions

    @objc private func controlTapped(_ sender: UIButton) {
        switch sender {
        case playBtn:
            if isPlaying {
                stopPlayback()
            } else {
                if currentTime >= currentShot.duration { currentTime = 0; scrubber.value = 0 }
                startPlayback()
            }
        case prevBtn:
            stopPlayback()
            guard currentIndex > 0 else { return }
            currentIndex -= 1; currentTime = 0
            syncToCurrentShot()
        case nextBtn:
            stopPlayback()
            guard currentIndex < shots.count - 1 else { return }
            currentIndex += 1; currentTime = 0
            syncToCurrentShot()
        default: break
        }
    }

    @objc private func backTapped() {
        stopPlayback()
        evaluateTimeline?(0)
        navigationController?.popViewController(animated: true)
    }

    // MARK: - Button Factory

    private func makeControlBtn(icon: String, size: CGFloat) -> UIButton {
        let btn = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: size, weight: .medium)
        btn.setImage(UIImage(systemName: icon, withConfiguration: cfg), for: .normal)
        btn.tintColor = .white
        btn.backgroundColor = UIColor.white.withAlphaComponent(0.09)
        // Corner radius is set dynamically once the button has a frame, but
        // we pre-set a reasonable value here and override in layoutSubviews via layer.
        btn.layer.cornerRadius = (size == 22 ? 32 : 26)
        btn.clipsToBounds = true
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(controlTapped(_:)), for: .touchUpInside)
        return btn
    }

    // MARK: - Helpers

    private func fmt(_ s: Float) -> String {
        let t = max(0, s)
        return String(format: "%02d:%02d", Int(t) / 60, Int(t) % 60)
    }

    // MARK: - Export

    @objc private func exportTapped() {
        let shot = currentShot
        let sheet = UIAlertController(
            title: shot.displayName,
            message: shot.cleanCameraName,
            preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Export MP4", style: .default)    { [weak self] _ in self?.renderAndExportMP4() })
        sheet.addAction(UIAlertAction(title: "Export JPEG Frame", style: .default) { [weak self] _ in self?.exportFrame(png: false) })
        sheet.addAction(UIAlertAction(title: "Export PNG Frame", style: .default)  { [weak self] _ in self?.exportFrame(png: true) })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(sheet, animated: true)
    }

    private func exportFrame(png: Bool) {
        guard let img = frameImageView.image else {
            showAlert("No frame captured. Play or scrub first."); return
        }
        let data = png ? img.pngData() : img.jpegData(compressionQuality: 0.92)
        guard let d = data, let out = UIImage(data: d) else { return }
        presentShareSheet([out])
    }

    // MARK: - MP4 Render + Export

    private lazy var exportOverlay: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.78)
        v.isHidden = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let exportLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13, weight: .semibold)
        l.textColor = .white; l.textAlignment = .center; l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false; return l
    }()
    private let exportProgress: UIProgressView = {
        let p = UIProgressView(progressViewStyle: .default)
        p.progressTintColor = UIColor(red: 0.694, green: 0.125, blue: 0.224, alpha: 1)
        p.trackTintColor    = UIColor.white.withAlphaComponent(0.13)
        p.translatesAutoresizingMaskIntoConstraints = false; return p
    }()
    private var exportOverlayAdded = false

    private func ensureExportOverlay() {
        guard !exportOverlayAdded else { return }
        exportOverlayAdded = true
        view.addSubview(exportOverlay)
        exportOverlay.addSubview(exportLabel)
        exportOverlay.addSubview(exportProgress)
        NSLayoutConstraint.activate([
            exportOverlay.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            exportOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            exportOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            exportOverlay.heightAnchor.constraint(equalTo: view.widthAnchor, multiplier: 9.0/16.0),
            exportLabel.centerXAnchor.constraint(equalTo: exportOverlay.centerXAnchor),
            exportLabel.centerYAnchor.constraint(equalTo: exportOverlay.centerYAnchor, constant: -14),
            exportProgress.topAnchor.constraint(equalTo: exportLabel.bottomAnchor, constant: 14),
            exportProgress.leadingAnchor.constraint(equalTo: exportOverlay.leadingAnchor, constant: 40),
            exportProgress.trailingAnchor.constraint(equalTo: exportOverlay.trailingAnchor, constant: -40),
        ])
    }

    private func setExportState(visible: Bool, text: String = "", progress: Float = 0) {
        ensureExportOverlay()
        exportOverlay.isHidden = !visible
        exportLabel.text = text
        exportProgress.progress = progress
    }

    private func renderAndExportMP4() {
        stopPlayback()
        let shot = currentShot
        let fps: Int32 = 24
        let totalFrames = max(1, Int(ceil(shot.duration * Float(fps))))

        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Shot\(shot.index + 1)_\(Int(Date().timeIntervalSince1970)).mp4")
        try? FileManager.default.removeItem(at: outURL)

        let size = frameImageView.image.map { $0.size } ?? CGSize(width: 1280, height: 720)

        guard let writer = try? AVAssetWriter(outputURL: outURL, fileType: .mp4) else {
            showAlert("Could not create video writer."); return
        }

        let videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey:  AVVideoCodecType.h264,
                AVVideoWidthKey:  size.width,
                AVVideoHeightKey: size.height,
            ])
        videoInput.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey  as String: size.width,
                kCVPixelBufferHeightKey as String: size.height,
            ])

        writer.add(videoInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        setExportState(visible: true, text: "Preparing…", progress: 0)
        renderNextFrame(index: 0, total: totalFrames, fps: fps,
                        shot: shot, writer: writer,
                        input: videoInput, adaptor: adaptor,
                        size: size, outURL: outURL)
    }

    private func renderNextFrame(index: Int, total: Int, fps: Int32,
                                  shot: Shot, writer: AVAssetWriter,
                                  input: AVAssetWriterInput,
                                  adaptor: AVAssetWriterInputPixelBufferAdaptor,
                                  size: CGSize, outURL: URL) {
        guard index < total else {
            input.markAsFinished()
            writer.finishWriting { [weak self] in
                DispatchQueue.main.async {
                    self?.setExportState(visible: false)
                    if writer.status == .completed {
                        self?.presentShareSheet([outURL])
                    } else {
                        self?.showAlert("MP4 export failed: \(writer.error?.localizedDescription ?? "unknown")")
                    }
                }
            }
            return
        }

        let progress = Float(index) / Float(total)
        setExportState(visible: true,
                       text: "Rendering \(shot.displayName)… \(index + 1)/\(total)",
                       progress: progress)

        let masterTime = shot.startTime + Float(index) / Float(fps)
        evaluateTimeline?(masterTime)

        let camItem = cameraItem(for: shot)

        let doCapture: (@escaping (UIImage?) -> Void) -> Void
        if let capture = captureFrameAsync {
            doCapture = { cb in capture(camItem, cb) }
        } else {
            doCapture = { [weak self] cb in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.033) {
                    self?.arView?.snapshot(saveToHDR: false, completion: cb)
                }
            }
        }

        doCapture { [weak self] image in
            guard let self = self else { return }
            if let img = image, let pb = img.toPixelBuffer(size: size) {
                while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
                let time = CMTime(value: CMTimeValue(index), timescale: fps)
                adaptor.append(pb, withPresentationTime: time)
            }
            DispatchQueue.main.async {
                self.renderNextFrame(index: index + 1, total: total, fps: fps,
                                     shot: shot, writer: writer,
                                     input: input, adaptor: adaptor,
                                     size: size, outURL: outURL)
            }
        }
    }

    private func presentShareSheet(_ items: [Any]) {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let pop = vc.popoverPresentationController {
            pop.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(vc, animated: true)
    }

    private func showAlert(_ msg: String) {
        let a = UIAlertController(title: nil, message: msg, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default))
        present(a, animated: true)
    }
}

// MARK: - Film Strip CollectionView

extension ShotPlayerViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ cv: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        shots.count
    }

    func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: StripCell.reuseID, for: ip) as! StripCell
        cell.configure(
            with: shots[ip.item],
            isActive: ip.item == currentIndex,
            accentColor: stripColors[ip.item % stripColors.count])
        return cell
    }

    func collectionView(_ cv: UICollectionView, didSelectItemAt ip: IndexPath) {
        stopPlayback()
        currentIndex = ip.item
        currentTime  = 0
        syncToCurrentShot()
    }
}

// MARK: - Strip Cell (film strip thumbnail)

final class StripCell: UICollectionViewCell {

    static let reuseID = "StripCell"

    private let bg        = UIView()
    private let thumbImg  = UIImageView()
    private let indexLbl  = UILabel()
    private let activeBar = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        bg.layer.cornerRadius = 6; bg.clipsToBounds = true
        bg.translatesAutoresizingMaskIntoConstraints = false

        thumbImg.contentMode = .scaleAspectFill; thumbImg.clipsToBounds = true
        thumbImg.translatesAutoresizingMaskIntoConstraints = false

        indexLbl.font = .systemFont(ofSize: 11, weight: .bold)
        indexLbl.textAlignment = .center
        indexLbl.translatesAutoresizingMaskIntoConstraints = false

        activeBar.layer.cornerRadius = 1.5
        activeBar.translatesAutoresizingMaskIntoConstraints = false

        bg.addSubview(thumbImg)
        bg.addSubview(indexLbl)
        bg.addSubview(activeBar)
        contentView.addSubview(bg)

        NSLayoutConstraint.activate([
            bg.topAnchor.constraint(equalTo: contentView.topAnchor),
            bg.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bg.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            thumbImg.topAnchor.constraint(equalTo: bg.topAnchor),
            thumbImg.leadingAnchor.constraint(equalTo: bg.leadingAnchor),
            thumbImg.trailingAnchor.constraint(equalTo: bg.trailingAnchor),
            thumbImg.bottomAnchor.constraint(equalTo: bg.bottomAnchor),

            indexLbl.centerXAnchor.constraint(equalTo: bg.centerXAnchor),
            indexLbl.centerYAnchor.constraint(equalTo: bg.centerYAnchor),

            activeBar.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 4),
            activeBar.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -4),
            activeBar.bottomAnchor.constraint(equalTo: bg.bottomAnchor, constant: -2),
            activeBar.heightAnchor.constraint(equalToConstant: 2.5),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(with shot: Shot, isActive: Bool, accentColor: UIColor) {
        if let thumb = shot.thumbnail {
            thumbImg.image = thumb
            thumbImg.isHidden = false
            indexLbl.isHidden = true
            thumbImg.alpha = isActive ? 1.0 : 0.4
        } else {
            thumbImg.isHidden = true
            indexLbl.isHidden = false
            indexLbl.text = shot.shortLabel
        }
        bg.backgroundColor = isActive
            ? UIColor(red: 0.13, green: 0.06, blue: 0.16, alpha: 1)
            : UIColor(red: 0.07, green: 0.07, blue: 0.12, alpha: 1)
        bg.layer.borderWidth = isActive ? 1.5 : 0
        bg.layer.borderColor = accentColor.cgColor
        activeBar.backgroundColor = isActive ? accentColor : .clear
        indexLbl.textColor = isActive ? .white : UIColor.white.withAlphaComponent(0.3)
    }
}

// MARK: - UILabel letter-spacing helper

private extension UILabel {
    func letterSpacing(_ spacing: CGFloat) {
        guard let text = text else { return }
        let attrs = NSAttributedString(
            string: text,
            attributes: [.kern: spacing,
                         .font: font as Any,
                         .foregroundColor: textColor as Any])
        attributedText = attrs
    }
}

// MARK: - UIImage → CVPixelBuffer

extension UIImage {
    func toPixelBuffer(size: CGSize) -> CVPixelBuffer? {
        var pb: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault, Int(size.width), Int(size.height),
            kCVPixelFormatType_32ARGB,
            [kCVPixelBufferCGImageCompatibilityKey: true,
             kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary,
            &pb)
        guard let buf = pb else { return nil }
        CVPixelBufferLockBaseAddress(buf, [])
        let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(buf),
            width: Int(size.width), height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buf),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        if let cg = cgImage { ctx?.draw(cg, in: CGRect(origin: .zero, size: size)) }
        CVPixelBufferUnlockBaseAddress(buf, [])
        return buf
    }
}
