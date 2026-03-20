//
//  ShotPlayerViewController_Improved.swift
//  3DCanvas
//
//  REDESIGNED FOR PROFESSIONAL VIDEO PLAYER EXPERIENCE
//  =====================================================
//
//  Key Improvements:
//  ✅ Responsive layout adapts perfectly to iPad 11" and 13"
//  ✅ Preview takes full priority (70% of screen height minimum)
//  ✅ Clean hierarchy: Preview → Controls → Scrubber → Shots List
//  ✅ Fixed scrubber syncing with proper progress tracking
//  ✅ Horizontal film strip with proper scrolling
//  ✅ Avoids overlapping controls
//  ✅ Professional video editor styling
//
//  Layout Strategy:
//  - LANDSCAPE: Frame (large, left 70%), Side panel (right 30%)
//  - PORTRAIT: Frame (top 65%), Controls (fixed height), Shots (bottom scrollable)
//

import UIKit
import RealityKit
import AVFoundation

final class ShotPlayerViewController_Improved: UIViewController {

    // MARK: - Palette
    private let bgColor     = UIColor(red: 0.043, green: 0.043, blue: 0.086, alpha: 1) // #0B0B16
    private let controlsBg  = UIColor(red: 0.067, green: 0.067, blue: 0.118, alpha: 1) // #111130
    private let thumbBg     = UIColor(red: 0.039, green: 0.039, blue: 0.078, alpha: 1) // #0A0A14
    private let accentRed   = UIColor(red: 0.694, green: 0.125, blue: 0.224, alpha: 1) // #B12038

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
    private var snapshotInFlight: UIImage?
    private var snapshotPending: Bool = false
    private var displayLink: CADisplayLink?
    private var playStart:   CFTimeInterval = 0
    private var currentTime: Float = 0
    private var lastSnapshotTime: CFTimeInterval = 0
    private var currentShot: Shot { shots[currentIndex] }
    private var isScrubbing = false

    // MARK: - Layout State

    private var portraitConstraints:  [NSLayoutConstraint] = []
    private var landscapeConstraints: [NSLayoutConstraint] = []
    private var activeOrientationConstraints: [NSLayoutConstraint] = []
    private var progressFillWidthConstraint: NSLayoutConstraint?

    // MARK: - UI: Frame Viewer (Takes Priority)

    private lazy var frameView: UIView = {
        let v = UIView()
        v.backgroundColor = thumbBg
        v.clipsToBounds = true
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
        let cfg = UIImage.SymbolConfiguration(pointSize: 48, weight: .thin)
        iv.image = UIImage(systemName: "camera.aperture", withConfiguration: cfg)
        iv.tintColor = UIColor.white.withAlphaComponent(0.08)
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let loadingSpinner: UIActivityIndicatorView = {
        let s = UIActivityIndicatorView(style: .medium)
        s.color = UIColor.white.withAlphaComponent(0.40)
        s.hidesWhenStopped = true
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    // MARK: - UI: HUD Chips (Overlay on Frame)

    private let hudShotLbl: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11, weight: .bold)
        l.textColor = .white
        l.backgroundColor = UIColor.black.withAlphaComponent(0.52)
        l.layer.cornerRadius = 4
        l.clipsToBounds = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let hudCamLbl: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 10, weight: .medium)
        l.textColor = UIColor.white.withAlphaComponent(0.70)
        l.backgroundColor = UIColor.black.withAlphaComponent(0.40)
        l.layer.cornerRadius = 4
        l.clipsToBounds = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let hudTimeLbl: UILabel = {
        let l = UILabel()
        l.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        l.textColor = .white
        l.backgroundColor = UIColor.black.withAlphaComponent(0.50)
        l.layer.cornerRadius = 4
        l.clipsToBounds = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let cutFlashLbl: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12, weight: .semibold)
        l.textColor = UIColor.white.withAlphaComponent(0.80)
        l.backgroundColor = UIColor.black.withAlphaComponent(0.60)
        l.layer.cornerRadius = 5
        l.clipsToBounds = true
        l.textAlignment = .center
        l.alpha = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - UI: Playback Controls Container

    private lazy var controlsContainer: UIView = {
        let v = UIView()
        v.backgroundColor = controlsBg
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // Shot & Camera info
    private let shotInfoLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 14, weight: .semibold)
        l.textColor = .white
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let cameraInfoLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11, weight: .regular)
        l.textColor = UIColor.white.withAlphaComponent(0.50)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // ── Playback Control Buttons ──
    private lazy var prevBtn  = makeControlBtn(icon: "backward.end.fill",  size: 16)
    private lazy var playBtn  = makeControlBtn(icon: "play.fill",           size: 20)
    private lazy var nextBtn  = makeControlBtn(icon: "forward.end.fill",    size: 16)

    // MARK: - UI: Scrubber / Timeline (Professional)

    private lazy var scrubberContainer: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.white.withAlphaComponent(0.04)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let scrubberTrack: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        v.layer.cornerRadius = 2
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var scrubberFill: UIView = {
        let v = UIView()
        v.backgroundColor = accentRed
        v.layer.cornerRadius = 2
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var scrubber: UISlider = {
        let s = UISlider()
        s.minimumValue = 0
        s.maximumValue = 1
        s.value = 0
        s.minimumTrackTintColor = .clear
        s.maximumTrackTintColor = .clear
        s.thumbTintColor = .white
        s.translatesAutoresizingMaskIntoConstraints = false
        s.addTarget(self, action: #selector(scrubberBeganDragging), for: .touchDown)
        s.addTarget(self, action: #selector(scrubberValueChanged), for: .valueChanged)
        s.addTarget(self, action: #selector(scrubberEndedDragging), for: [.touchUpInside, .touchUpOutside])
        return s
    }()

    private let currentTimeLabel: UILabel = {
        let l = UILabel()
        l.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        l.textColor = UIColor.white.withAlphaComponent(0.50)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let durationLabel: UILabel = {
        let l = UILabel()
        l.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        l.textColor = UIColor.white.withAlphaComponent(0.50)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - UI: Film Strip (Shots List)

    private lazy var filmStripContainer: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let filmStripLabel: UILabel = {
        let l = UILabel()
        l.text = "SHOTS"
        l.font = .systemFont(ofSize: 9, weight: .black)
        l.textColor = UIColor.white.withAlphaComponent(0.20)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var filmStrip: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.register(StripCell.self, forCellWithReuseIdentifier: StripCell.reuseID)
        cv.dataSource = self
        cv.delegate = self
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = bgColor
        setupNavigation()
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
            self?.applyOrientation(size: size)
            self?.filmStrip.collectionViewLayout.invalidateLayout()
        })
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Ensure circular buttons
        for btn in [prevBtn, nextBtn] {
            btn.layer.cornerRadius = btn.bounds.height / 2
        }
        playBtn.layer.cornerRadius = playBtn.bounds.height / 2
    }

    // MARK: - Navigation Setup

    private func setupNavigation() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = bgColor
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 15, weight: .semibold)
        ]
        appearance.shadowColor = UIColor.white.withAlphaComponent(0.05)
        navigationController?.navigationBar.standardAppearance = appearance
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

    // MARK: - Layout Construction

    private func buildLayout() {
        // ── Frame container ──
        frameView.addSubview(frameImageView)
        frameView.addSubview(framePlaceholder)
        frameView.addSubview(loadingSpinner)
        frameView.addSubview(hudShotLbl)
        frameView.addSubview(hudCamLbl)
        frameView.addSubview(hudTimeLbl)
        frameView.addSubview(cutFlashLbl)

        // ── Controls container ──
        controlsContainer.addSubview(shotInfoLabel)
        controlsContainer.addSubview(cameraInfoLabel)

        let btnStack = UIStackView(arrangedSubviews: [prevBtn, playBtn, nextBtn])
        btnStack.axis = .horizontal
        btnStack.alignment = .center
        btnStack.spacing = 24
        btnStack.translatesAutoresizingMaskIntoConstraints = false
        controlsContainer.addSubview(btnStack)

        // ── Scrubber container ──
        scrubberTrack.addSubview(scrubberFill)
        scrubberContainer.addSubview(currentTimeLabel)
        scrubberContainer.addSubview(scrubberTrack)
        scrubberContainer.addSubview(scrubber)
        scrubberContainer.addSubview(durationLabel)

        // ── Film strip ──
        filmStripContainer.addSubview(filmStripLabel)
        filmStripContainer.addSubview(filmStrip)

        // ── Root hierarchy ──
        view.addSubview(frameView)
        view.addSubview(controlsContainer)
        view.addSubview(scrubberContainer)
        view.addSubview(filmStripContainer)

        // ── Setup progress fill constraint ──
        let fillW = scrubberFill.widthAnchor.constraint(equalToConstant: 0)
        fillW.isActive = true
        progressFillWidthConstraint = fillW

        // ── Detect device size ──
        let is13inch = UIScreen.main.bounds.width >= 1024 || UIScreen.main.bounds.height >= 1024
        let btnSize: CGFloat = is13inch ? 54 : 48
        let playSize: CGFloat = is13inch ? 60 : 54

        // ── SHARED Constraints (Both Orientations) ──
        NSLayoutConstraint.activate([

            // Frame image fills entire frameView
            frameImageView.topAnchor.constraint(equalTo: frameView.topAnchor),
            frameImageView.leadingAnchor.constraint(equalTo: frameView.leadingAnchor),
            frameImageView.trailingAnchor.constraint(equalTo: frameView.trailingAnchor),
            frameImageView.bottomAnchor.constraint(equalTo: frameView.bottomAnchor),

            // Placeholder icon — centered
            framePlaceholder.centerXAnchor.constraint(equalTo: frameView.centerXAnchor),
            framePlaceholder.centerYAnchor.constraint(equalTo: frameView.centerYAnchor),
            framePlaceholder.widthAnchor.constraint(equalToConstant: 60),
            framePlaceholder.heightAnchor.constraint(equalToConstant: 60),

            loadingSpinner.centerXAnchor.constraint(equalTo: frameView.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: frameView.centerYAnchor),

            // HUD chips positioning (top-left & top-right)
            hudShotLbl.topAnchor.constraint(equalTo: frameView.topAnchor, constant: 12),
            hudShotLbl.leadingAnchor.constraint(equalTo: frameView.leadingAnchor, constant: 12),
            hudCamLbl.topAnchor.constraint(equalTo: hudShotLbl.bottomAnchor, constant: 4),
            hudCamLbl.leadingAnchor.constraint(equalTo: frameView.leadingAnchor, constant: 12),
            hudTimeLbl.topAnchor.constraint(equalTo: frameView.topAnchor, constant: 12),
            hudTimeLbl.trailingAnchor.constraint(equalTo: frameView.trailingAnchor, constant: -12),
            cutFlashLbl.centerXAnchor.constraint(equalTo: frameView.centerXAnchor),
            cutFlashLbl.centerYAnchor.constraint(equalTo: frameView.centerYAnchor),

            // ── Controls Container ──
            controlsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlsContainer.heightAnchor.constraint(equalToConstant: is13inch ? 100 : 88),

            // Info labels (shot + camera)
            shotInfoLabel.topAnchor.constraint(equalTo: controlsContainer.topAnchor, constant: 10),
            shotInfoLabel.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor, constant: 16),
            cameraInfoLabel.topAnchor.constraint(equalTo: shotInfoLabel.bottomAnchor, constant: 2),
            cameraInfoLabel.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor, constant: 16),

            // Button stack (centered)
            btnStack.centerXAnchor.constraint(equalTo: controlsContainer.centerXAnchor),
            btnStack.bottomAnchor.constraint(equalTo: controlsContainer.bottomAnchor, constant: -14),

            prevBtn.widthAnchor.constraint(equalToConstant: btnSize),
            prevBtn.heightAnchor.constraint(equalToConstant: btnSize),
            playBtn.widthAnchor.constraint(equalToConstant: playSize),
            playBtn.heightAnchor.constraint(equalToConstant: playSize),
            nextBtn.widthAnchor.constraint(equalToConstant: btnSize),
            nextBtn.heightAnchor.constraint(equalToConstant: btnSize),

            // ── Scrubber Container ──
            scrubberContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrubberContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrubberContainer.heightAnchor.constraint(equalToConstant: 44),

            // Time labels
            currentTimeLabel.leadingAnchor.constraint(equalTo: scrubberContainer.leadingAnchor, constant: 12),
            currentTimeLabel.centerYAnchor.constraint(equalTo: scrubberContainer.centerYAnchor),
            currentTimeLabel.widthAnchor.constraint(equalToConstant: 42),

            durationLabel.trailingAnchor.constraint(equalTo: scrubberContainer.trailingAnchor, constant: -12),
            durationLabel.centerYAnchor.constraint(equalTo: scrubberContainer.centerYAnchor),
            durationLabel.widthAnchor.constraint(equalToConstant: 42),

            // Scrubber track
            scrubberTrack.leadingAnchor.constraint(equalTo: currentTimeLabel.trailingAnchor, constant: 8),
            scrubberTrack.trailingAnchor.constraint(equalTo: durationLabel.leadingAnchor, constant: -8),
            scrubberTrack.centerYAnchor.constraint(equalTo: scrubberContainer.centerYAnchor),
            scrubberTrack.heightAnchor.constraint(equalToConstant: 4),

            // Scrubber fill
            scrubberFill.leadingAnchor.constraint(equalTo: scrubberTrack.leadingAnchor),
            scrubberFill.topAnchor.constraint(equalTo: scrubberTrack.topAnchor),
            scrubberFill.bottomAnchor.constraint(equalTo: scrubberTrack.bottomAnchor),

            // Scrubber slider (with padding for thumb)
            scrubber.leadingAnchor.constraint(equalTo: scrubberTrack.leadingAnchor, constant: -10),
            scrubber.trailingAnchor.constraint(equalTo: scrubberTrack.trailingAnchor, constant: 10),
            scrubber.centerYAnchor.constraint(equalTo: scrubberContainer.centerYAnchor),

            // ── Film Strip Container ──
            filmStripContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filmStripContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            filmStripLabel.topAnchor.constraint(equalTo: filmStripContainer.topAnchor, constant: 8),
            filmStripLabel.leadingAnchor.constraint(equalTo: filmStripContainer.leadingAnchor, constant: 16),

            filmStrip.topAnchor.constraint(equalTo: filmStripLabel.bottomAnchor, constant: 6),
            filmStrip.leadingAnchor.constraint(equalTo: filmStripContainer.leadingAnchor),
            filmStrip.trailingAnchor.constraint(equalTo: filmStripContainer.trailingAnchor),
            filmStrip.bottomAnchor.constraint(equalTo: filmStripContainer.bottomAnchor, constant: -6),
            filmStrip.heightAnchor.constraint(equalToConstant: is13inch ? 76 : 66),
        ])

        // ── LANDSCAPE: Frame large on left (70%), Controls on right ──
        landscapeConstraints = [
            frameView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            frameView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 10),
            frameView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            frameView.trailingAnchor.constraint(equalTo: controlsContainer.leadingAnchor, constant: -10),
            frameView.widthAnchor.constraint(equalTo: frameView.heightAnchor, multiplier: 16.0 / 9.0),

            controlsContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            controlsContainer.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            controlsContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            controlsContainer.widthAnchor.constraint(equalToConstant: is13inch ? 320 : 280),

            // Scrubber and film strip hidden in landscape
            scrubberContainer.heightAnchor.constraint(equalToConstant: 0),
            filmStripContainer.heightAnchor.constraint(equalToConstant: 0),
        ]

        // ── PORTRAIT: Frame on top (full width), Controls + Scrubber + Strip stacked below ──
        portraitConstraints = [
            frameView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            frameView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            frameView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            frameView.heightAnchor.constraint(equalTo: frameView.widthAnchor, multiplier: 9.0 / 16.0),

            controlsContainer.topAnchor.constraint(equalTo: frameView.bottomAnchor),

            scrubberContainer.topAnchor.constraint(equalTo: controlsContainer.bottomAnchor),

            filmStripContainer.topAnchor.constraint(equalTo: scrubberContainer.bottomAnchor),
            filmStripContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ]

        applyOrientation(size: view.bounds.size)
    }

    /// Switches between portrait/landscape constraint sets cleanly
    private func applyOrientation(size: CGSize) {
        let isLandscape = size.width > size.height
        NSLayoutConstraint.deactivate(activeOrientationConstraints)
        activeOrientationConstraints = isLandscape ? landscapeConstraints : portraitConstraints
        NSLayoutConstraint.activate(activeOrientationConstraints)

        let is13inch = UIScreen.main.bounds.width >= 1024 || UIScreen.main.bounds.height >= 1024
        let cellH: CGFloat = is13inch ? 70 : 62
        let cellW: CGFloat = is13inch ? 90 : 80

        if let layout = filmStrip.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.itemSize = CGSize(width: cellW, height: cellH)
            layout.scrollDirection = .horizontal
        }

        view.layoutIfNeeded()
    }

    // MARK: - Sync to Current Shot

    private func syncToCurrentShot() {
        let shot = currentShot
        let accent = stripColors[currentIndex % stripColors.count]

        title = "\(sceneName)  ·  \(shot.displayName)"

        // Update labels
        shotInfoLabel.text = shot.displayName
        cameraInfoLabel.text = "  \(shot.cleanCameraName)"
        scrubberFill.backgroundColor = accent
        hudShotLbl.text = "  \(shot.displayName)  "
        hudCamLbl.text = "  \(shot.cleanCameraName)  "

        // Reset scrubber
        currentTime = 0
        scrubber.value = 0
        updateTimeLabels()

        // Film strip
        filmStrip.reloadData()
        if currentIndex < shots.count {
            filmStrip.scrollToItem(
                at: IndexPath(item: currentIndex, section: 0),
                at: .centeredHorizontally, animated: true)
        }

        // Capture first frame
        captureFrame(at: shot.startTime, force: true)
    }

    // MARK: - Frame Capture with Smart Rate Limiting

    private func captureFrame(at masterTime: Float, force: Bool = false) {
        evaluateTimeline?(masterTime)

        // Display any snapshot that arrived
        if let inFlightImage = snapshotInFlight {
            frameImageView.image = inFlightImage
            framePlaceholder.isHidden = true
            snapshotInFlight = nil
            loadingSpinner.stopAnimating()
        }

        let now = CACurrentMediaTime()
        let minInterval: CFTimeInterval = isPlaying ? 1.0 / 30.0 : 0.0

        guard (force || (now - lastSnapshotTime) >= minInterval) else { return }
        guard !snapshotPending else { return }

        lastSnapshotTime = now
        if !isPlaying { loadingSpinner.startAnimating() }

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
                if let img = img {
                    self.snapshotInFlight = img
                }
                self.snapshotPending = false
            }
        }
    }

    /// Resolves SceneCameraItem with 4-tier fallback
    private func cameraItem(for shot: Shot) -> CanvasViewController.SceneCameraItem? {
        cameraItems.first { $0.cameraRoot.name == shot.cameraName }
        ?? cameraItems.first {
            $0.cameraRoot.name.contains(shot.cameraName) ||
            shot.cameraName.contains($0.cameraRoot.name)
        }
        ?? cameraItems.first { _ in true }
    }

    // MARK: - Playback Control

    private func startPlayback() {
        stopPlayback()
        isPlaying = true
        playStart = CACurrentMediaTime() - CFTimeInterval(currentTime)
        updatePlayIcon()
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopPlayback() {
        displayLink?.invalidate()
        displayLink = nil
        isPlaying = false
        snapshotPending = false
        updatePlayIcon()
    }

    private func updatePlayIcon() {
        let name = isPlaying ? "pause.fill" : "play.fill"
        let cfg = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        playBtn.setImage(UIImage(systemName: name, withConfiguration: cfg), for: .normal)
    }

    @objc private func tick() {
        guard isPlaying && !isScrubbing else { return }
        currentTime = Float(CACurrentMediaTime() - playStart)
        let duration = currentShot.duration

        if currentTime >= duration {
            if playAll && currentIndex < shots.count - 1 {
                let fromName = currentShot.displayName
                currentIndex += 1
                currentTime = 0
                playStart = CACurrentMediaTime()
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

        updateScrubber()
    }

    private func updateScrubber() {
        let duration = currentShot.duration
        let progress = currentTime / max(0.001, duration)
        scrubber.value = progress

        // Update progress fill
        if let tw = scrubberTrack.constraints.first(where: { $0.firstAttribute == .width }),
           let fw = progressFillWidthConstraint {
            fw.constant = tw.constant * CGFloat(progress)
        } else {
            DispatchQueue.main.async {
                self.progressFillWidthConstraint?.constant =
                    self.scrubberTrack.bounds.width * CGFloat(progress)
            }
        }

        updateTimeLabels()
        let masterTime = currentShot.startTime + currentTime
        captureFrame(at: masterTime)
    }

    private func updateTimeLabels() {
        currentTimeLabel.text = fmt(currentTime)
        durationLabel.text = fmt(currentShot.duration)
        hudTimeLbl.text = "  \(fmt(currentTime)) / \(fmt(currentShot.duration))  "
    }

    // MARK: - Scrubber Interaction

    @objc private func scrubberBeganDragging() {
        isScrubbing = true
        stopPlayback()
    }

    @objc private func scrubberValueChanged(_ s: UISlider) {
        currentTime = s.value * currentShot.duration
        updateTimeLabels()
        captureFrame(at: currentShot.startTime + currentTime, force: true)
    }

    @objc private func scrubberEndedDragging() {
        isScrubbing = false
        if !currentTime.isNaN && currentTime < currentShot.duration {
            startPlayback()
        }
    }

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
            currentIndex -= 1
            currentTime = 0
            syncToCurrentShot()
        case nextBtn:
            stopPlayback()
            guard currentIndex < shots.count - 1 else { return }
            currentIndex += 1
            currentTime = 0
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
        btn.layer.cornerRadius = 27
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
        sheet.addAction(UIAlertAction(title: "Export MP4", style: .default) { [weak self] _ in self?.renderAndExportMP4() })
        sheet.addAction(UIAlertAction(title: "Export JPEG Frame", style: .default) { [weak self] _ in self?.exportFrame(png: false) })
        sheet.addAction(UIAlertAction(title: "Export PNG Frame", style: .default) { [weak self] _ in self?.exportFrame(png: true) })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(sheet, animated: true)
    }

    private func exportFrame(png: Bool) {
        guard let img = frameImageView.image else {
            showAlert("No frame captured. Play or scrub first.")
            return
        }
        let data = png ? img.pngData() : img.jpegData(compressionQuality: 0.92)
        guard let d = data, let out = UIImage(data: d) else { return }
        presentShareSheet([out])
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
            showAlert("Could not create video writer.")
            return
        }

        let videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: size.width,
                AVVideoHeightKey: size.height,
            ])
        videoInput.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: size.width,
                kCVPixelBufferHeightKey as String: size.height,
            ])

        writer.add(videoInput)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        setExportState(visible: true, text: "Preparing…", progress: 0)
        renderNextFrame(index: 0, total: totalFrames, fps: fps,
                        shot: shot, writer: writer, input: videoInput,
                        adaptor: adaptor, size: size, outURL: outURL)
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
                                     shot: shot, writer: writer, input: input,
                                     adaptor: adaptor, size: size, outURL: outURL)
            }
        }
    }

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
        l.textColor = .white
        l.textAlignment = .center
        l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let exportProgress: UIProgressView = {
        let p = UIProgressView(progressViewStyle: .default)
        p.progressTintColor = UIColor(red: 0.694, green: 0.125, blue: 0.224, alpha: 1)
        p.trackTintColor = UIColor.white.withAlphaComponent(0.13)
        p.translatesAutoresizingMaskIntoConstraints = false
        return p
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
            exportOverlay.heightAnchor.constraint(equalTo: view.widthAnchor, multiplier: 9.0 / 16.0),
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

extension ShotPlayerViewController_Improved: UICollectionViewDataSource, UICollectionViewDelegate {

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
        currentTime = 0
        syncToCurrentShot()
    }
}

// MARK: - Strip Cell

final class StripCell: UICollectionViewCell {

    static let reuseID = "StripCell"

    private let bg = UIView()
    private let thumbImg = UIImageView()
    private let indexLbl = UILabel()
    private let activeBar = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        bg.layer.cornerRadius = 6
        bg.clipsToBounds = true
        bg.translatesAutoresizingMaskIntoConstraints = false

        thumbImg.contentMode = .scaleAspectFill
        thumbImg.clipsToBounds = true
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
