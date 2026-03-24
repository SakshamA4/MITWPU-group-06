//
//  ShotPlayerViewController.swift
//  3DCanvas
//

import UIKit
import RealityKit
import AVFoundation


final class ShotPlayerViewController: UIViewController {

    private let bgColor      = UIColor(red: 0.043, green: 0.043, blue: 0.086, alpha: 1)
    private let surfaceColor = UIColor(red: 0.060, green: 0.060, blue: 0.108, alpha: 1)
    private let controlsBg   = UIColor(red: 0.048, green: 0.048, blue: 0.092, alpha: 1)
    private let accentRed    = UIColor(red: 0.694, green: 0.125, blue: 0.224, alpha: 1)
    private let trackColor   = UIColor(white: 1, alpha: 0.10)
    private let labelFaded   = UIColor(white: 1, alpha: 0.38)

    private let stripColors: [UIColor] = [
        UIColor(red: 0.694, green: 0.125, blue: 0.224, alpha: 1),
        UIColor(red: 0.18,  green: 0.44,  blue: 0.78,  alpha: 1),
        UIColor(red: 0.12,  green: 0.65,  blue: 0.45,  alpha: 1),
        UIColor(red: 0.72,  green: 0.45,  blue: 0.12,  alpha: 1),
        UIColor(red: 0.55,  green: 0.22,  blue: 0.75,  alpha: 1),
    ]


    init(shots: [Shot],
         startIndex: Int,
         playAll: Bool,
         sceneName: String,
         arView: ARView?,
         evaluateTimeline: ((Float) -> Void)?,
         captureFrameAsync: ((CanvasViewController.SceneCameraItem?,
                              @escaping (UIImage?) -> Void) -> Void)? = nil,
         cameraItems: [CanvasViewController.SceneCameraItem] = []) {
        self.shots             = shots
        self.currentIndex      = startIndex
        self.playAll           = playAll
        self.sceneName         = sceneName
        self.arView            = arView
        self.evaluateTimeline  = evaluateTimeline
        self.captureFrameAsync = captureFrameAsync
        self.cameraItems       = cameraItems
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

 
    var shots: [Shot]
    var currentIndex: Int
    var playAll: Bool
    var sceneName: String
    weak var arView: ARView?
    var evaluateTimeline: ((Float) -> Void)?
    var captureFrameAsync: ((CanvasViewController.SceneCameraItem?,
                             @escaping (UIImage?) -> Void) -> Void)?
    var cameraItems: [CanvasViewController.SceneCameraItem]
    var prepareForCapture: ((CanvasViewController.SceneCameraItem?) -> Void)?

    private var isPlaying        = false
    private var snapshotInFlight: UIImage?
    private var snapshotPending  = false
    private var displayLink: CADisplayLink?
    private var playStart: CFTimeInterval = 0
    private var currentTime: Float = 0
    private var lastSnapshotTime: CFTimeInterval = 0
    private var currentShot: Shot { shots[currentIndex] }
    
    // ISSUE 1: Snapshot cache keyed by camera name
    private var snapshotCache: [String: UIImage] = [:]
    
    // ISSUE 3: Double-buffer rendering
    private var frameBuffer: [UIImage?] = [nil, nil]  // two slots
    private var displaySlot: Int = 0  // which slot is being displayed

    private var is13inch: Bool {
        let s = UIScreen.main.bounds
        return s.width >= 1024 || s.height >= 1024
    }


    private lazy var previewContainer: UIView = {
        let v = UIView()
        v.backgroundColor    = .black
        v.clipsToBounds      = true
        v.layer.cornerRadius = 6
        v.layer.borderWidth  = 1
        v.layer.borderColor  = UIColor(white: 1, alpha: 0.06).cgColor
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

    private lazy var framePlaceholder: UIImageView = {
        let iv = UIImageView()
        let cfg = UIImage.SymbolConfiguration(pointSize: 40, weight: .ultraLight)
        iv.image       = UIImage(systemName: "camera.aperture", withConfiguration: cfg)
        iv.tintColor   = UIColor(white: 1, alpha: 0.07)
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private lazy var loadingSpinner: UIActivityIndicatorView = {
        let s = UIActivityIndicatorView(style: .medium)
        s.color = UIColor(white: 1, alpha: 0.30)
        s.hidesWhenStopped = true
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    // HUD chips overlaid on preview corners
    private lazy var hudShotLbl: UILabel = makeHUDChip(size: 11, weight: .bold)
    private lazy var hudCamLbl:  UILabel = makeHUDChip(size: 10, weight: .medium, alpha: 0.70)
    private lazy var hudTimeLbl: UILabel = {
        let l = makeHUDChip(size: 11, weight: .semibold)
        l.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        return l
    }()
    private lazy var cutFlashLbl: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12, weight: .semibold)
        l.textColor       = UIColor(white: 1, alpha: 0.85)
        l.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        l.layer.cornerRadius = 5; l.clipsToBounds = true
        l.textAlignment = .center; l.alpha = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()


    private lazy var transportBar: UIView = {
        let v = UIView()
        v.backgroundColor = controlsBg
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var prevBtn = makeTransportBtn(icon: "backward.end.fill", symbolPt: 14)
    private lazy var playBtn = makeTransportBtn(icon: "play.fill",          symbolPt: 20, primary: true)
    private lazy var nextBtn = makeTransportBtn(icon: "forward.end.fill",   symbolPt: 14)

    private lazy var currentTimeLbl: UILabel = makeMonoLabel()
    private lazy var durationLbl:    UILabel = makeMonoLabel()
    private lazy var timeSepLbl:     UILabel = {
        let l = makeMonoLabel(); l.text = "/"; l.textColor = labelFaded.withAlphaComponent(0.25); return l
    }()


    private lazy var scrubberBar: UIView = {
        let v = UIView()
        v.backgroundColor = controlsBg
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var scrubber: PlayerSlider = {
        let s = PlayerSlider(accent: accentRed, track: trackColor)
        s.minimumValue = 0; s.maximumValue = 1; s.value = 0
        s.translatesAutoresizingMaskIntoConstraints = false
        s.addTarget(self, action: #selector(scrubChanged),   for: .valueChanged)
        s.addTarget(self, action: #selector(scrubTouchDown), for: .touchDown)
        s.addTarget(self, action: #selector(scrubTouchUp),   for: [.touchUpInside, .touchUpOutside])
        return s
    }()

    private lazy var scrubStartLbl: UILabel = makeMonoLabel()
    private lazy var scrubEndLbl:   UILabel = makeMonoLabel()

    // Film strip row  —  SHOTS  N  [ ][ ][ ]…
    private lazy var filmStripContainer: UIView = {
        let v = UIView()
        v.backgroundColor = surfaceColor
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var shotsHeaderLbl: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 9, weight: .black)
        l.textColor = labelFaded
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var shotCountLbl: UILabel = {
        let l = UILabel()
        l.font = .monospacedDigitSystemFont(ofSize: 9, weight: .medium)
        l.textColor = labelFaded.withAlphaComponent(0.50)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var filmStrip: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection    = .horizontal
        layout.minimumLineSpacing = 8
        layout.sectionInset       = UIEdgeInsets(top: 4, left: 16, bottom: 4, right: 16)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.showsVerticalScrollIndicator   = false
        cv.register(StripCell.self, forCellWithReuseIdentifier: StripCell.reuseID)
        cv.dataSource = self; cv.delegate = self
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()


    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.backgroundColor = .clear
        sv.showsVerticalScrollIndicator = true
        sv.showsHorizontalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private lazy var contentContainer: UIView = {
        let v = UIView()
        v.backgroundColor = .clear
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var exportOverlay: UIView = {
        let v = UIView(); v.backgroundColor = UIColor.black.withAlphaComponent(0.80)
        v.isHidden = true; v.translatesAutoresizingMaskIntoConstraints = false; return v
    }()
    private lazy var exportLabel: UILabel = {
        let l = UILabel(); l.font = .systemFont(ofSize: 13, weight: .semibold)
        l.textColor = .white; l.textAlignment = .center; l.numberOfLines = 2
        l.translatesAutoresizingMaskIntoConstraints = false; return l
    }()
    private lazy var exportProgress: UIProgressView = {
        let p = UIProgressView(progressViewStyle: .default)
        p.progressTintColor = accentRed; p.trackTintColor = UIColor(white: 1, alpha: 0.13)
        p.translatesAutoresizingMaskIntoConstraints = false; return p
    }()
    private var exportOverlayAdded = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = bgColor
        setupNav()
        buildLayout()
        applyOrientation(to: view.bounds.size)
        syncToCurrentShot()
        if playAll { startPlayback() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        [prevBtn, nextBtn].forEach { $0.layer.cornerRadius = $0.bounds.height / 2 }
        playBtn.layer.cornerRadius = playBtn.bounds.height / 2
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopPlayback(); evaluateTimeline?(0)
        frameImageView.image = nil; snapshotInFlight = nil
        // ISSUE 1: Clear cache to release memory
        snapshotCache.removeAll()
        // ISSUE 2: Clear prepareForCapture to release closure references
        prepareForCapture = nil
    }

    override func viewWillTransition(to size: CGSize,
                                     with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.applyOrientation(to: size)
            self?.filmStrip.collectionViewLayout.invalidateLayout()
        })
    }



    private func setupNav() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = bgColor
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 15, weight: .semibold)
        ]
        appearance.shadowColor = UIColor(white: 1, alpha: 0.05)
        navigationController?.navigationBar.standardAppearance   = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.tintColor = .white

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain, target: self, action: #selector(backTapped))

        let exp = UIBarButtonItem(title: "Export", style: .plain,
                                  target: self, action: #selector(exportTapped))
        exp.setTitleTextAttributes([.foregroundColor: accentRed,
                                    .font: UIFont.systemFont(ofSize: 14, weight: .semibold)],
                                   for: .normal)
        navigationItem.rightBarButtonItem = exp
    }

    private func buildLayout() {

        previewContainer.addSubview(frameImageView)
        previewContainer.addSubview(framePlaceholder)
        previewContainer.addSubview(loadingSpinner)
        previewContainer.addSubview(hudShotLbl)
        previewContainer.addSubview(hudCamLbl)
        previewContainer.addSubview(hudTimeLbl)
        previewContainer.addSubview(cutFlashLbl)

        let btnStack = UIStackView(arrangedSubviews: [prevBtn, playBtn, nextBtn])
        btnStack.axis = .horizontal; btnStack.alignment = .center; btnStack.spacing = 24
        btnStack.translatesAutoresizingMaskIntoConstraints = false

        let timeStack = UIStackView(arrangedSubviews: [currentTimeLbl, timeSepLbl, durationLbl])
        timeStack.axis = .horizontal; timeStack.alignment = .center; timeStack.spacing = 4
        timeStack.translatesAutoresizingMaskIntoConstraints = false

        transportBar.addSubview(btnStack)
        transportBar.addSubview(timeStack)

        scrubberBar.addSubview(scrubStartLbl)
        scrubberBar.addSubview(scrubber)
        scrubberBar.addSubview(scrubEndLbl)

        filmStripContainer.addSubview(shotsHeaderLbl)
        filmStripContainer.addSubview(shotCountLbl)
        filmStripContainer.addSubview(filmStrip)

        let sep1 = makeSep()   // below preview
        let sep2 = makeSep()   // below transport
        let sep3 = makeSep()   // below scrubber

        // Main scrollView wraps all content to ensure nothing is cut off
        view.addSubview(scrollView)
        
        // Add all content to the scrollView's content container
        scrollView.addSubview(previewContainer)
        scrollView.addSubview(sep1)
        scrollView.addSubview(transportBar)
        scrollView.addSubview(sep2)
        scrollView.addSubview(scrubberBar)
        scrollView.addSubview(sep3)
        scrollView.addSubview(filmStripContainer)

        let g = view.safeAreaLayoutGuide
        let big         = is13inch
        
        // Adaptive button and bar sizing based on screen size
        let transportH  = CGFloat(big ? 62 : 54)
        let scrubberH   = CGFloat(big ? 50 : 44)
        let headerH     = CGFloat(big ? 22 : 18)
        let cellH       = CGFloat(big ? 84 : 74)
        let cellW       = CGFloat(big ? 94 : 82)
        let stripH      = cellH + headerH + 20
        let playDim     = CGFloat(big ? 50 : 44)
        let prevDim     = CGFloat(big ? 38 : 34)

        if let layout = filmStrip.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .horizontal
            layout.itemSize = CGSize(width: cellW, height: cellH)
        }

        NSLayoutConstraint.activate([
            
            // MARK: - ScrollView Setup
            scrollView.topAnchor.constraint(equalTo: g.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // MARK: - Preview Container (Adaptive 16:9)
            previewContainer.topAnchor.constraint(equalTo: scrollView.topAnchor),
            previewContainer.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            previewContainer.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            previewContainer.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            previewContainer.heightAnchor.constraint(
                equalTo: previewContainer.widthAnchor, multiplier: 9.0 / 16.0),

            frameImageView.topAnchor.constraint(equalTo: previewContainer.topAnchor),
            frameImageView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor),
            frameImageView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor),
            frameImageView.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor),

            framePlaceholder.centerXAnchor.constraint(equalTo: previewContainer.centerXAnchor),
            framePlaceholder.centerYAnchor.constraint(equalTo: previewContainer.centerYAnchor),
            framePlaceholder.widthAnchor.constraint(equalToConstant: 48),
            framePlaceholder.heightAnchor.constraint(equalToConstant: 48),

            loadingSpinner.centerXAnchor.constraint(equalTo: previewContainer.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: previewContainer.centerYAnchor),

            hudShotLbl.topAnchor.constraint(equalTo: previewContainer.topAnchor, constant: 10),
            hudShotLbl.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 10),
            hudCamLbl.topAnchor.constraint(equalTo: hudShotLbl.bottomAnchor, constant: 3),
            hudCamLbl.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 10),
            hudTimeLbl.topAnchor.constraint(equalTo: previewContainer.topAnchor, constant: 10),
            hudTimeLbl.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -10),
            cutFlashLbl.centerXAnchor.constraint(equalTo: previewContainer.centerXAnchor),
            cutFlashLbl.centerYAnchor.constraint(equalTo: previewContainer.centerYAnchor),

            // MARK: - Separator 1
            sep1.topAnchor.constraint(equalTo: previewContainer.bottomAnchor),
            sep1.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            sep1.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            sep1.heightAnchor.constraint(equalToConstant: 1),

            // MARK: - Transport Bar (Adaptive Height)
            transportBar.topAnchor.constraint(equalTo: sep1.bottomAnchor),
            transportBar.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            transportBar.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            transportBar.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            transportBar.heightAnchor.constraint(equalToConstant: transportH),

            prevBtn.widthAnchor.constraint(equalToConstant: prevDim),
            prevBtn.heightAnchor.constraint(equalToConstant: prevDim),
            playBtn.widthAnchor.constraint(equalToConstant: playDim),
            playBtn.heightAnchor.constraint(equalToConstant: playDim),
            nextBtn.widthAnchor.constraint(equalToConstant: prevDim),
            nextBtn.heightAnchor.constraint(equalToConstant: prevDim),

            btnStack.centerXAnchor.constraint(equalTo: transportBar.centerXAnchor),
            btnStack.centerYAnchor.constraint(equalTo: transportBar.centerYAnchor),
            timeStack.trailingAnchor.constraint(equalTo: transportBar.trailingAnchor, constant: -16),
            timeStack.centerYAnchor.constraint(equalTo: transportBar.centerYAnchor),

            // MARK: - Separator 2
            sep2.topAnchor.constraint(equalTo: transportBar.bottomAnchor),
            sep2.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            sep2.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            sep2.heightAnchor.constraint(equalToConstant: 1),

            // MARK: - Scrubber Bar (Adaptive Height)
            scrubberBar.topAnchor.constraint(equalTo: sep2.bottomAnchor),
            scrubberBar.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            scrubberBar.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            scrubberBar.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            scrubberBar.heightAnchor.constraint(equalToConstant: scrubberH),

            scrubStartLbl.leadingAnchor.constraint(equalTo: scrubberBar.leadingAnchor, constant: 16),
            scrubStartLbl.centerYAnchor.constraint(equalTo: scrubberBar.centerYAnchor),
            scrubStartLbl.widthAnchor.constraint(equalToConstant: 40),
            scrubEndLbl.trailingAnchor.constraint(equalTo: scrubberBar.trailingAnchor, constant: -16),
            scrubEndLbl.centerYAnchor.constraint(equalTo: scrubberBar.centerYAnchor),
            scrubEndLbl.widthAnchor.constraint(equalToConstant: 40),
            scrubber.leadingAnchor.constraint(equalTo: scrubStartLbl.trailingAnchor, constant: 10),
            scrubber.trailingAnchor.constraint(equalTo: scrubEndLbl.leadingAnchor, constant: -10),
            scrubber.centerYAnchor.constraint(equalTo: scrubberBar.centerYAnchor),

            // MARK: - Separator 3
            sep3.topAnchor.constraint(equalTo: scrubberBar.bottomAnchor),
            sep3.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            sep3.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            sep3.heightAnchor.constraint(equalToConstant: 1),

            // MARK: - Film Strip Container (Adaptive, grows to fit content)
            filmStripContainer.topAnchor.constraint(equalTo: sep3.bottomAnchor),
            filmStripContainer.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            filmStripContainer.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            filmStripContainer.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            filmStripContainer.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            filmStripContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: stripH),

            shotsHeaderLbl.topAnchor.constraint(equalTo: filmStripContainer.topAnchor, constant: 8),
            shotsHeaderLbl.leadingAnchor.constraint(equalTo: filmStripContainer.leadingAnchor, constant: 16),
            shotsHeaderLbl.heightAnchor.constraint(equalToConstant: headerH),
            shotCountLbl.centerYAnchor.constraint(equalTo: shotsHeaderLbl.centerYAnchor),
            shotCountLbl.leadingAnchor.constraint(equalTo: shotsHeaderLbl.trailingAnchor, constant: 6),

            filmStrip.topAnchor.constraint(equalTo: shotsHeaderLbl.bottomAnchor, constant: 4),
            filmStrip.leadingAnchor.constraint(equalTo: filmStripContainer.leadingAnchor),
            filmStrip.trailingAnchor.constraint(equalTo: filmStripContainer.trailingAnchor),
            filmStrip.bottomAnchor.constraint(equalTo: filmStripContainer.bottomAnchor, constant: -6),
        ])
    }

    private func applyOrientation(to size: CGSize) {
        // Invalidate and refresh layouts for adaptive sizing
        filmStrip.collectionViewLayout.invalidateLayout()
        scrollView.layoutIfNeeded()
        view.layoutIfNeeded()
    }


    private func syncToCurrentShot() {
        let shot   = currentShot
        let accent = stripColors[currentIndex % stripColors.count]

        title = "\(sceneName)  ·  \(shot.displayName)"

        scrubber.setAccent(accent)

        currentTimeLbl.text = fmt(0)
        durationLbl.text    = fmt(shot.duration)
        scrubStartLbl.text  = fmt(0)
        scrubEndLbl.text    = fmt(shot.duration)
        scrubber.value      = 0
        currentTime         = 0

        shotCountLbl.text = "\(shots.count)"

        hudShotLbl.text = "  \(shot.displayName)  "
        hudCamLbl.text  = "  \(shot.cleanCameraName)  "
        hudTimeLbl.text = "  00:00 / \(fmt(shot.duration))  "

        setHeaderSpacing()

        filmStrip.reloadData()
        if currentIndex < shots.count {
            filmStrip.scrollToItem(
                at: IndexPath(item: currentIndex, section: 0),
                at: .centeredHorizontally, animated: true)
        }
        
        // ISSUE 1: Populate cache from previewImage for all cameras at sync time
        for item in cameraItems {
            if let previewImg = item.previewImage {
                snapshotCache[item.cameraRoot.name] = previewImg
            }
        }
        
        // ISSUE 1: Try to show cached snapshot immediately if available
        let camItem = cameraItem(for: shot)
        if let cachedImg = snapshotCache[camItem?.cameraRoot.name ?? ""] {
            frameImageView.image = cachedImg
            framePlaceholder.isHidden = true
            loadingSpinner.stopAnimating()
        }
        
        captureFrame(at: shot.startTime, force: true)
    }

    private func setHeaderSpacing() {
        let attrs: [NSAttributedString.Key: Any] = [
            .kern: 1.8, .font: shotsHeaderLbl.font as Any, .foregroundColor: labelFaded
        ]
        shotsHeaderLbl.attributedText = NSAttributedString(string: "SHOTS", attributes: attrs)
    }


    private func captureFrame(at masterTime: Float, force: Bool = false) {
        evaluateTimeline?(masterTime)

        // Display any buffered frame from the previous slot
        if let img = snapshotInFlight {
            frameImageView.image      = img
            framePlaceholder.isHidden = true
            snapshotInFlight          = nil
            loadingSpinner.stopAnimating()
        }

        let now = CACurrentMediaTime()
        let minInterval: CFTimeInterval = isPlaying ? 1.0 / 24.0 : 0
        guard force || (now - lastSnapshotTime) >= minInterval else { return }
        guard !snapshotPending else { return }

        lastSnapshotTime = now
        if !isPlaying { loadingSpinner.startAnimating() }

        let camItem = cameraItem(for: currentShot)
        snapshotPending = true
        
        // ISSUE 2: Call prepareForCapture before capturing to hide gizmos, etc.
        prepareForCapture?(camItem)

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
                    // ISSUE 1: Update cache with freshest image
                    let camName = camItem?.cameraRoot.name ?? ""
                    self.snapshotCache[camName] = img
                }
                self.snapshotPending = false
            }
        }
    }

    private func cameraItem(for shot: Shot) -> CanvasViewController.SceneCameraItem? {
        cameraItems.first { $0.cameraRoot.name == shot.cameraName }
        ?? cameraItems.first {
            $0.cameraRoot.name.contains(shot.cameraName) ||
            shot.cameraName.contains($0.cameraRoot.name)
        }
        ?? cameraItems.first { _ in true }
    }



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
        isPlaying = false; snapshotPending = false
        updatePlayIcon()
    }

    private func updatePlayIcon() {
        let cfg = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        playBtn.setImage(UIImage(systemName: isPlaying ? "pause.fill" : "play.fill",
                                 withConfiguration: cfg), for: .normal)
    }

    @objc private func tick() {
        guard isPlaying else { return }
        currentTime = Float(CACurrentMediaTime() - playStart)
        let duration = currentShot.duration

        if currentTime >= duration {
            if playAll && currentIndex < shots.count - 1 {
                let from = currentShot.displayName
                currentIndex += 1; currentTime = 0
                playStart = CACurrentMediaTime()
                syncToCurrentShot()
                cutFlashLbl.text = "  \(from)  →  \(currentShot.displayName)  "
                UIView.animate(withDuration: 0.12, animations: { self.cutFlashLbl.alpha = 1 }) { _ in
                    UIView.animate(withDuration: 0.30, delay: 1.0) { self.cutFlashLbl.alpha = 0 }
                }
                return
            } else {
                currentTime = duration; stopPlayback()
            }
        }

        let p = currentTime / max(0.001, duration)
        scrubber.value      = p
        currentTimeLbl.text = fmt(currentTime)
        scrubStartLbl.text  = fmt(currentTime)
        hudTimeLbl.text     = "  \(fmt(currentTime)) / \(fmt(duration))  "

        captureFrame(at: currentShot.startTime + currentTime)
    }



    @objc private func scrubChanged(_ s: UISlider) {
        currentTime = s.value * currentShot.duration
        currentTimeLbl.text = fmt(currentTime)
        scrubStartLbl.text  = fmt(currentTime)
        hudTimeLbl.text     = "  \(fmt(currentTime)) / \(fmt(currentShot.duration))  "
        if isPlaying { playStart = CACurrentMediaTime() - CFTimeInterval(currentTime) }
        // ISSUE 3: Cancel in-flight capture by setting snapshotPending = false before force capture
        snapshotPending = false
        captureFrame(at: currentShot.startTime + currentTime, force: true)
    }

    @objc private func scrubTouchDown() { stopPlayback() }
    @objc private func scrubTouchUp()   { startPlayback() }


    @objc private func controlTapped(_ btn: UIButton) {
        switch btn {
        case playBtn:
            if isPlaying { stopPlayback() } else {
                if currentTime >= currentShot.duration { currentTime = 0; scrubber.value = 0 }
                startPlayback()
            }
        case prevBtn:
            stopPlayback(); guard currentIndex > 0 else { return }
            currentIndex -= 1; currentTime = 0; syncToCurrentShot()
        case nextBtn:
            stopPlayback(); guard currentIndex < shots.count - 1 else { return }
            currentIndex += 1; currentTime = 0; syncToCurrentShot()
        default: break
        }
    }

    @objc private func backTapped() {
        stopPlayback(); evaluateTimeline?(0)
        navigationController?.popViewController(animated: true)
    }


    private func makeHUDChip(size: CGFloat, weight: UIFont.Weight,
                              alpha: CGFloat = 1) -> UILabel {
        let l = UILabel()
        l.font            = .systemFont(ofSize: size, weight: weight)
        l.textColor       = UIColor(white: 1, alpha: alpha)
        l.backgroundColor = UIColor.black.withAlphaComponent(0.50)
        l.layer.cornerRadius = 4; l.clipsToBounds = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    private func makeMonoLabel() -> UILabel {
        let l = UILabel()
        l.font      = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        l.textColor = labelFaded
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    private func makeTransportBtn(icon: String, symbolPt: CGFloat,
                                   primary: Bool = false) -> UIButton {
        let btn = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: symbolPt, weight: .medium)
        btn.setImage(UIImage(systemName: icon, withConfiguration: cfg), for: .normal)
        btn.tintColor       = .white
        btn.backgroundColor = primary ? accentRed.withAlphaComponent(0.90)
                                      : UIColor(white: 1, alpha: 0.08)
        btn.layer.cornerRadius = 20     // refined to height/2 in viewDidLayoutSubviews
        btn.clipsToBounds      = true
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(controlTapped(_:)), for: .touchUpInside)
        return btn
    }

    private func makeSep() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor(white: 1, alpha: 0.07)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    private func fmt(_ s: Float) -> String {
        let t = max(0, s)
        return String(format: "%02d:%02d", Int(t) / 60, Int(t) % 60)
    }


    @objc private func exportTapped() {
        let shot  = currentShot
        let sheet = UIAlertController(title: shot.displayName,
                                      message: shot.cleanCameraName,
                                      preferredStyle: .actionSheet)
        sheet.addAction(.init(title: "Export MP4",        style: .default) { [weak self] _ in self?.renderAndExportMP4() })
        sheet.addAction(.init(title: "Export JPEG Frame", style: .default) { [weak self] _ in self?.exportFrame(png: false) })
        sheet.addAction(.init(title: "Export PNG Frame",  style: .default) { [weak self] _ in self?.exportFrame(png: true) })
        sheet.addAction(.init(title: "Cancel", style: .cancel))
        if let pop = sheet.popoverPresentationController { pop.barButtonItem = navigationItem.rightBarButtonItem }
        present(sheet, animated: true)
    }

    private func exportFrame(png: Bool) {
        guard let img = frameImageView.image else { showAlert("No frame captured."); return }
        let data = png ? img.pngData() : img.jpegData(compressionQuality: 0.92)
        guard let d = data, let out = UIImage(data: d) else { return }
        presentShareSheet([out])
    }

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
            exportOverlay.heightAnchor.constraint(equalTo: previewContainer.heightAnchor),
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
        exportLabel.text = text; exportProgress.progress = progress
    }

    private func renderAndExportMP4() {
        stopPlayback()
        let shot = currentShot; let fps: Int32 = 24
        let totalFrames = max(1, Int(ceil(shot.duration * Float(fps))))

        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Shot\(shot.index + 1)_\(Int(Date().timeIntervalSince1970)).mp4")
        try? FileManager.default.removeItem(at: outURL)

        let size = frameImageView.image.map { $0.size } ?? CGSize(width: 1280, height: 720)
        guard let writer = try? AVAssetWriter(outputURL: outURL, fileType: .mp4) else {
            showAlert("Could not create video writer."); return
        }
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: size.width, AVVideoHeightKey: size.height,
        ])
        videoInput.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey  as String: size.width,
                kCVPixelBufferHeightKey as String: size.height,
            ])
        writer.add(videoInput)
        writer.startWriting(); writer.startSession(atSourceTime: .zero)
        setExportState(visible: true, text: "Preparing…", progress: 0)
        renderNextFrame(index: 0, total: totalFrames, fps: fps, shot: shot,
                        writer: writer, input: videoInput, adaptor: adaptor,
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
                    if writer.status == .completed { self?.presentShareSheet([outURL]) }
                    else { self?.showAlert("MP4 export failed: \(writer.error?.localizedDescription ?? "unknown")") }
                }
            }
            return
        }
        setExportState(visible: true,
                       text: "Rendering \(shot.displayName)… \(index + 1)/\(total)",
                       progress: Float(index) / Float(total))

        let masterTime = shot.startTime + Float(index) / Float(fps)
        evaluateTimeline?(masterTime)
        let camItem = cameraItem(for: shot)
        // ISSUE 2: Call prepareForCapture before each frame capture in export path
        prepareForCapture?(camItem)
        
        let doCapture: (@escaping (UIImage?) -> Void) -> Void
        if let capture = captureFrameAsync { doCapture = { cb in capture(camItem, cb) } }
        else { doCapture = { [weak self] cb in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.033) {
                self?.arView?.snapshot(saveToHDR: false, completion: cb) }
        }}
        doCapture { [weak self] image in
            guard let self = self else { return }
            if let img = image, let pb = img.toPixelBuffer(size: size) {
                while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
                adaptor.append(pb, withPresentationTime: CMTime(value: CMTimeValue(index), timescale: fps))
            }
            DispatchQueue.main.async {
                self.renderNextFrame(index: index + 1, total: total, fps: fps, shot: shot,
                                     writer: writer, input: input, adaptor: adaptor,
                                     size: size, outURL: outURL)
            }
        }
    }

    private func presentShareSheet(_ items: [Any]) {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let pop = vc.popoverPresentationController { pop.barButtonItem = navigationItem.rightBarButtonItem }
        present(vc, animated: true)
    }

    private func showAlert(_ msg: String) {
        let a = UIAlertController(title: nil, message: msg, preferredStyle: .alert)
        a.addAction(.init(title: "OK", style: .default))
        present(a, animated: true)
    }
}


extension ShotPlayerViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ cv: UICollectionView, numberOfItemsInSection _: Int) -> Int { shots.count }

    func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: StripCell.reuseID, for: ip) as! StripCell
        cell.configure(with: shots[ip.item],
                       isActive: ip.item == currentIndex,
                       accentColor: stripColors[ip.item % stripColors.count])
        return cell
    }

    func collectionView(_ cv: UICollectionView, didSelectItemAt ip: IndexPath) {
        stopPlayback(); currentIndex = ip.item; currentTime = 0
        syncToCurrentShot()
    }
}


final class PlayerSlider: UISlider {
    init(accent: UIColor, track: UIColor) {
        super.init(frame: .zero)
        minimumTrackTintColor = accent
        maximumTrackTintColor = track
        setThumbImage(thumb(r: 7), for: .normal)
        setThumbImage(thumb(r: 9), for: .highlighted)
    }
    required init?(coder: NSCoder) { fatalError() }

    func setAccent(_ c: UIColor) { minimumTrackTintColor = c }

    private func thumb(r: CGFloat) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: r*2, height: r*2)).image { ctx in
            UIColor.white.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: r*2, height: r*2))
        }
    }
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(dx: -10, dy: -18).contains(point)
    }
}


final class StripCell: UICollectionViewCell {

    static let reuseID = "StripCell"

    private let bg        = UIView()
    private let thumbImg  = UIImageView()
    private let indexLbl  = UILabel()
    private let nameLbl   = UILabel()
    private let durLbl    = UILabel()
    private let activeBar = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        bg.layer.cornerRadius = 8; bg.clipsToBounds = true
        bg.translatesAutoresizingMaskIntoConstraints = false

        thumbImg.contentMode = .scaleAspectFill; thumbImg.clipsToBounds = true
        thumbImg.translatesAutoresizingMaskIntoConstraints = false

        indexLbl.font = .systemFont(ofSize: 18, weight: .light)
        indexLbl.textAlignment = .center
        indexLbl.textColor = UIColor(white: 1, alpha: 0.25)
        indexLbl.translatesAutoresizingMaskIntoConstraints = false

        nameLbl.font = .systemFont(ofSize: 9, weight: .semibold)
        nameLbl.textColor = .white; nameLbl.textAlignment = .center
        nameLbl.adjustsFontSizeToFitWidth = true; nameLbl.minimumScaleFactor = 0.7
        nameLbl.translatesAutoresizingMaskIntoConstraints = false

        durLbl.font = .monospacedDigitSystemFont(ofSize: 8, weight: .regular)
        durLbl.textColor = UIColor(white: 1, alpha: 0.40)
        durLbl.textAlignment = .center
        durLbl.translatesAutoresizingMaskIntoConstraints = false

        activeBar.layer.cornerRadius = 2
        activeBar.translatesAutoresizingMaskIntoConstraints = false

        let labelBg = UIView()
        labelBg.backgroundColor = UIColor.black.withAlphaComponent(0.58)
        labelBg.translatesAutoresizingMaskIntoConstraints = false

        bg.addSubview(thumbImg); bg.addSubview(indexLbl)
        bg.addSubview(labelBg); labelBg.addSubview(nameLbl); labelBg.addSubview(durLbl)
        bg.addSubview(activeBar); contentView.addSubview(bg)

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
            indexLbl.centerYAnchor.constraint(equalTo: bg.centerYAnchor, constant: -8),

            labelBg.leadingAnchor.constraint(equalTo: bg.leadingAnchor),
            labelBg.trailingAnchor.constraint(equalTo: bg.trailingAnchor),
            labelBg.bottomAnchor.constraint(equalTo: bg.bottomAnchor),

            nameLbl.topAnchor.constraint(equalTo: labelBg.topAnchor, constant: 3),
            nameLbl.leadingAnchor.constraint(equalTo: labelBg.leadingAnchor, constant: 4),
            nameLbl.trailingAnchor.constraint(equalTo: labelBg.trailingAnchor, constant: -4),

            durLbl.topAnchor.constraint(equalTo: nameLbl.bottomAnchor, constant: 1),
            durLbl.leadingAnchor.constraint(equalTo: labelBg.leadingAnchor, constant: 4),
            durLbl.trailingAnchor.constraint(equalTo: labelBg.trailingAnchor, constant: -4),
            durLbl.bottomAnchor.constraint(equalTo: labelBg.bottomAnchor, constant: -3),

            activeBar.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 4),
            activeBar.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -4),
            activeBar.bottomAnchor.constraint(equalTo: bg.bottomAnchor, constant: -2),
            activeBar.heightAnchor.constraint(equalToConstant: 3),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(with shot: Shot, isActive: Bool, accentColor: UIColor) {
        if let thumb = shot.thumbnail {
            thumbImg.image = thumb; thumbImg.isHidden = false
            thumbImg.alpha = isActive ? 1.0 : 0.45; indexLbl.isHidden = true
        } else {
            thumbImg.isHidden = true; indexLbl.isHidden = false
            indexLbl.text = "\(shot.index + 1)"
        }
        nameLbl.text = shot.shortLabel
        durLbl.text  = String(format: "%02d:%02d", Int(shot.duration)/60, Int(shot.duration)%60)
        bg.backgroundColor = isActive
            ? UIColor(red: 0.12, green: 0.06, blue: 0.16, alpha: 1)
            : UIColor(red: 0.07, green: 0.07, blue: 0.12, alpha: 1)
        bg.layer.borderWidth = isActive ? 1.5 : 0
        bg.layer.borderColor = accentColor.cgColor
        activeBar.backgroundColor = isActive ? accentColor : .clear
    }
}


extension UIImage {
    func toPixelBuffer(size: CGSize) -> CVPixelBuffer? {
        var pb: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height),
                            kCVPixelFormatType_32ARGB,
                            [kCVPixelBufferCGImageCompatibilityKey: true,
                             kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary,
                            &pb)
        guard let buf = pb else { return nil }
        CVPixelBufferLockBaseAddress(buf, [])
        let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buf),
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
