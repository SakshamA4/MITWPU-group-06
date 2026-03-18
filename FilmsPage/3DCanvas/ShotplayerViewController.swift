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

    // MARK: - UI: Frame Viewer

    /// Full-width 16:9 frame — shows the shot's camera POV
    private lazy var frameView: UIView = {
        let v = UIView()
        v.backgroundColor = thumbBg
        v.clipsToBounds   = true
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
        let cfg = UIImage.SymbolConfiguration(pointSize: 40, weight: .ultraLight)
        iv.image     = UIImage(systemName: "camera.aperture", withConfiguration: cfg)
        iv.tintColor = UIColor.white.withAlphaComponent(0.07)
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    // Spinner shown while snapshot is in-flight
    private let loadingSpinner: UIActivityIndicatorView = {
        let s = UIActivityIndicatorView(style: .medium)
        s.color = UIColor.white.withAlphaComponent(0.3)
        s.hidesWhenStopped = true
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    // MARK: - UI: HUD (overlaid on frame)

    private let hudShotLbl: UILabel = {
        let l = UILabel()
        l.font            = .systemFont(ofSize: 12, weight: .bold)
        l.textColor       = .white
        l.backgroundColor = UIColor.black.withAlphaComponent(0.48)
        l.layer.cornerRadius = 5; l.clipsToBounds = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let hudCamLbl: UILabel = {
        let l = UILabel()
        l.font            = .systemFont(ofSize: 10, weight: .medium)
        l.textColor       = UIColor.white.withAlphaComponent(0.75)
        l.backgroundColor = UIColor.black.withAlphaComponent(0.38)
        l.layer.cornerRadius = 4; l.clipsToBounds = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let hudTimeLbl: UILabel = {
        let l = UILabel()
        l.font            = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        l.textColor       = .white
        l.backgroundColor = UIColor.black.withAlphaComponent(0.44)
        l.layer.cornerRadius = 4; l.clipsToBounds = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    /// Briefly shown on cut transition
    private let cutFlashLbl: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12, weight: .semibold)
        l.textColor = UIColor.white.withAlphaComponent(0.75)
        l.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        l.layer.cornerRadius = 5; l.clipsToBounds = true
        l.textAlignment = .center
        l.alpha = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - UI: Progress Bar (slim, overlaid at bottom of frame)

    private lazy var progressBar: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.60)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let progressTrack: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        v.layer.cornerRadius = 2
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var progressFill: UIView = {
        let v = UIView()
        v.backgroundColor = accentRed
        v.layer.cornerRadius = 2
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
        l.textColor = UIColor.white.withAlphaComponent(0.45)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let scrubEndLbl: UILabel = {
        let l = UILabel()
        l.font = .monospacedDigitSystemFont(ofSize: 10, weight: .medium)
        l.textColor = UIColor.white.withAlphaComponent(0.45)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private var progressFillWidthConstraint: NSLayoutConstraint?

    // MARK: - UI: Controls Panel

    private lazy var controlsPanel: UIView = {
        let v = UIView()
        v.backgroundColor = panelColor
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let shotInfoLbl: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11, weight: .medium)
        l.textColor = UIColor.white.withAlphaComponent(0.38)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var prevBtn  = makeControlBtn(icon: "backward.end.fill",  size: 16)
    private lazy var playBtn  = makeControlBtn(icon: "play.fill",           size: 22)
    private lazy var nextBtn  = makeControlBtn(icon: "forward.end.fill",    size: 16)

    // MARK: - UI: Film Strip

    private lazy var filmStrip: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection     = .horizontal
        layout.itemSize            = CGSize(width: 64, height: 42)
        layout.minimumLineSpacing  = 6
        layout.sectionInset        = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
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
        l.textColor = UIColor.white.withAlphaComponent(0.18)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Lifecycle

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
         // BUG FIX: Clean up the offscreen preview clone so it doesn't affect the live scene
         // Note: arView is weak, so we don't need to nullify it on pop
         // Reset timeline to t=0 so entities return to initial state
         evaluateTimeline?(0)
         
         // Memory cleanup: release cached image to avoid memory pressure
         frameImageView.image = nil
         snapshotInFlight = nil
     }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
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
        appearance.shadowColor = UIColor.white.withAlphaComponent(0.06)
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

    // MARK: - Layout
    //
    //  [NavBar]
    //  ┌───────────────────────────────┐
    //  │  frameView  (16:9)            │
    //  │   ├─ frameImageView           │
    //  │   ├─ framePlaceholder         │
    //  │   ├─ HUD (shot / cam / time)  │
    //  │   └─ progressBar (bottom)     │
    //  │       [start][track/scrub][end]│
    //  └───────────────────────────────┘
    //  ┌───────────────────────────────┐
    //  │  controlsPanel                │
    //  │   shotInfoLbl (centered)      │
    //  │   [prev]  [▶]  [next]         │
    //  └───────────────────────────────┘
    //   SHOTS label
    //  ┌─────── filmStrip ─────────────┐
    //  └───────────────────────────────┘

    private func buildLayout() {
        // Frame view
        frameView.addSubview(frameImageView)
        frameView.addSubview(framePlaceholder)
        frameView.addSubview(loadingSpinner)
        frameView.addSubview(hudShotLbl)
        frameView.addSubview(hudCamLbl)
        frameView.addSubview(hudTimeLbl)
        frameView.addSubview(cutFlashLbl)

        // Progress bar (bottom of frame)
        progressTrack.addSubview(progressFill)
        progressBar.addSubview(progressTrack)
        progressBar.addSubview(scrubber)
        progressBar.addSubview(scrubStartLbl)
        progressBar.addSubview(scrubEndLbl)
        frameView.addSubview(progressBar)
        view.addSubview(frameView)

        // Controls panel
        let btnStack = UIStackView(arrangedSubviews: [prevBtn, playBtn, nextBtn])
        btnStack.axis = .horizontal; btnStack.spacing = 28; btnStack.alignment = .center
        btnStack.translatesAutoresizingMaskIntoConstraints = false
        controlsPanel.addSubview(shotInfoLbl)
        controlsPanel.addSubview(btnStack)
        view.addSubview(controlsPanel)

        // Film strip
        view.addSubview(filmStripLabel)
        view.addSubview(filmStrip)

        // Separator lines
        let sep1 = hairline(); view.addSubview(sep1)
        let sep2 = hairline(); view.addSubview(sep2)

        let fillW = progressFill.widthAnchor.constraint(equalToConstant: 0)
        fillW.isActive = true
        progressFillWidthConstraint = fillW

        // Determine if iPad or iPhone
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let controlPanelHeight: CGFloat = isIPad ? 100 : 84
        let buttonSize: CGFloat = isIPad ? 56 : 50
        let playButtonSize: CGFloat = isIPad ? 62 : 50
        let buttonSpacing: CGFloat = isIPad ? 36 : 28

        NSLayoutConstraint.activate([

            // ── Frame view ──────────────────────────────────────────────
            frameView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            frameView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            frameView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            frameView.heightAnchor.constraint(equalTo: frameView.widthAnchor, multiplier: 9.0/16.0),

            frameImageView.topAnchor.constraint(equalTo: frameView.topAnchor),
            frameImageView.leadingAnchor.constraint(equalTo: frameView.leadingAnchor),
            frameImageView.trailingAnchor.constraint(equalTo: frameView.trailingAnchor),
            frameImageView.bottomAnchor.constraint(equalTo: frameView.bottomAnchor),

            framePlaceholder.centerXAnchor.constraint(equalTo: frameView.centerXAnchor),
            framePlaceholder.centerYAnchor.constraint(equalTo: frameView.centerYAnchor),
            framePlaceholder.widthAnchor.constraint(equalToConstant: 48),
            framePlaceholder.heightAnchor.constraint(equalToConstant: 48),

            loadingSpinner.centerXAnchor.constraint(equalTo: frameView.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: frameView.centerYAnchor),

            // ── HUD top-left ─────────────────────────────────────────────
            hudShotLbl.topAnchor.constraint(equalTo: frameView.topAnchor, constant: 10),
            hudShotLbl.leadingAnchor.constraint(equalTo: frameView.leadingAnchor, constant: 10),

            hudCamLbl.topAnchor.constraint(equalTo: hudShotLbl.bottomAnchor, constant: 4),
            hudCamLbl.leadingAnchor.constraint(equalTo: frameView.leadingAnchor, constant: 10),

            // ── HUD bottom-left ─────────────────────────────────────────
            hudTimeLbl.bottomAnchor.constraint(equalTo: progressBar.topAnchor, constant: -6),
            hudTimeLbl.leadingAnchor.constraint(equalTo: frameView.leadingAnchor, constant: 10),

            // ── Cut flash — bottom center above progress bar ─────────────
            cutFlashLbl.bottomAnchor.constraint(equalTo: progressBar.topAnchor, constant: -6),
            cutFlashLbl.centerXAnchor.constraint(equalTo: frameView.centerXAnchor),

            // ── Progress bar (pinned to bottom of frame) ──────────────────
            progressBar.leadingAnchor.constraint(equalTo: frameView.leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: frameView.trailingAnchor),
            progressBar.bottomAnchor.constraint(equalTo: frameView.bottomAnchor),
            progressBar.heightAnchor.constraint(equalToConstant: 44),

            scrubStartLbl.leadingAnchor.constraint(equalTo: progressBar.leadingAnchor, constant: 12),
            scrubStartLbl.centerYAnchor.constraint(equalTo: progressBar.centerYAnchor),
            scrubStartLbl.widthAnchor.constraint(equalToConstant: 40),

            scrubEndLbl.trailingAnchor.constraint(equalTo: progressBar.trailingAnchor, constant: -12),
            scrubEndLbl.centerYAnchor.constraint(equalTo: progressBar.centerYAnchor),
            scrubEndLbl.widthAnchor.constraint(equalToConstant: 40),

            progressTrack.leadingAnchor.constraint(equalTo: scrubStartLbl.trailingAnchor, constant: 6),
            progressTrack.trailingAnchor.constraint(equalTo: scrubEndLbl.leadingAnchor, constant: -6),
            progressTrack.centerYAnchor.constraint(equalTo: progressBar.centerYAnchor),
            progressTrack.heightAnchor.constraint(equalToConstant: 4),

            progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
            progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),

            scrubber.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor, constant: -12),
            scrubber.trailingAnchor.constraint(equalTo: progressTrack.trailingAnchor, constant: 12),
            scrubber.centerYAnchor.constraint(equalTo: progressBar.centerYAnchor),

            // ── Separator 1 (frame / controls) ───────────────────────────
            sep1.topAnchor.constraint(equalTo: frameView.bottomAnchor),
            sep1.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sep1.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sep1.heightAnchor.constraint(equalToConstant: 1),

            // ── Controls panel ────────────────────────────────────────────
            controlsPanel.topAnchor.constraint(equalTo: sep1.bottomAnchor),
            controlsPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlsPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlsPanel.heightAnchor.constraint(equalToConstant: controlPanelHeight),

            shotInfoLbl.topAnchor.constraint(equalTo: controlsPanel.topAnchor, constant: 12),
            shotInfoLbl.centerXAnchor.constraint(equalTo: controlsPanel.centerXAnchor),

            btnStack.topAnchor.constraint(equalTo: shotInfoLbl.bottomAnchor, constant: isIPad ? 10 : 6),
            btnStack.centerXAnchor.constraint(equalTo: controlsPanel.centerXAnchor),
            btnStack.bottomAnchor.constraint(lessThanOrEqualTo: controlsPanel.bottomAnchor, constant: -10),

            prevBtn.widthAnchor.constraint(equalToConstant: buttonSize),
            prevBtn.heightAnchor.constraint(equalToConstant: buttonSize),
            playBtn.widthAnchor.constraint(equalToConstant: playButtonSize),
            playBtn.heightAnchor.constraint(equalToConstant: playButtonSize),
            nextBtn.widthAnchor.constraint(equalToConstant: buttonSize),
            nextBtn.heightAnchor.constraint(equalToConstant: buttonSize),

            // ── Separator 2 (controls / strip) ───────────────────────────
            sep2.topAnchor.constraint(equalTo: controlsPanel.bottomAnchor),
            sep2.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sep2.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sep2.heightAnchor.constraint(equalToConstant: 1),

            // ── Film strip header ─────────────────────────────────────────
            filmStripLabel.topAnchor.constraint(equalTo: sep2.bottomAnchor, constant: 12),
            filmStripLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            // ── Film strip ────────────────────────────────────────────────
            filmStrip.topAnchor.constraint(equalTo: filmStripLabel.bottomAnchor, constant: 6),
            filmStrip.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filmStrip.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            filmStrip.heightAnchor.constraint(equalToConstant: 50),
            filmStrip.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
        ])
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
        shotInfoLbl.text  = "\(shot.displayName)  ·  \(shot.cleanCameraName)"
        scrubEndLbl.text  = fmt(shot.duration)
        scrubStartLbl.text = "00:00"
        scrubber.value    = 0
        currentTime       = 0

        // Progress fill tint matches shot accent
        progressFill.backgroundColor = accent

        // HUD
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
        btn.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        btn.layer.cornerRadius = size == 22 ? 25 : 20
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
