//
//  ShotPlayerViewController.swift
//  3DCanvas
//
//  FIX 1: Timeline bar is now at the BOTTOM of the frame, no overlap with buttons.
//         Buttons sit above the strip in their own clean panel.
//  FIX 2: Frame shows actual camera POV — activates the shot's PerspectiveCamera,
//         snapshots via the passed captureFromCamera closure, then restores.
//  FIX 3: Export can trigger MP4 recording via ReplayKit.
//

import UIKit
import RealityKit
import ReplayKit

class ShotPlayerViewController: UIViewController {

    // MARK: - Colours
    private let navy     = UIColor(red: 11/255,  green: 11/255,  blue: 22/255,  alpha: 1)
    private let appRed   = UIColor(red: 177/255, green: 32/255,  blue: 57/255,  alpha: 1)
    private let panelBg  = UIColor(red: 17/255,  green: 17/255,  blue: 30/255,  alpha: 1)
    private let thumbBg  = UIColor(red: 10/255,  green: 10/255,  blue: 20/255,  alpha: 1)

    // MARK: - Init
    /// captureFromCamera: given a SceneCameraItem, return a UIImage of what that camera sees.
    /// evaluateTimeline:  scrub the scene to a given master time.
    init(shots: [Shot],
         startIndex: Int,
         playAll: Bool,
         sceneName: String,
         arView: ARView?,
         evaluateTimeline: ((Float) -> Void)?,
         captureFromCamera: ((CanvasViewController.SceneCameraItem?) -> UIImage?)? = nil,
         cameraItems: [CanvasViewController.SceneCameraItem] = []) {
        self.shots             = shots
        self.currentIndex      = startIndex
        self.playAll           = playAll
        self.sceneName         = sceneName
        self.arView            = arView
        self.evaluateTimeline  = evaluateTimeline
        self.captureFromCamera = captureFromCamera
        self.cameraItems       = cameraItems
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
    var captureFromCamera: ((CanvasViewController.SceneCameraItem?) -> UIImage?)?
    var cameraItems: [CanvasViewController.SceneCameraItem]

    private var isPlaying   = false
    private var displayLink: CADisplayLink?
    private var playStart:   CFTimeInterval = 0
    private var currentTime: Float = 0
    private var currentShot: Shot { shots[currentIndex] }

    // MARK: - UI

    // Large frame viewer — shows camera POV
    private lazy var frameView: UIView = {
        let v = UIView()
        v.backgroundColor      = thumbBg
        v.layer.cornerRadius   = 0   // full width
        v.clipsToBounds        = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private lazy var frameImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode         = .scaleAspectFit
        iv.clipsToBounds       = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let placeholderIcon: UIImageView = {
        let iv = UIImageView()
        let cfg = UIImage.SymbolConfiguration(pointSize: 44, weight: .thin)
        iv.image = UIImage(systemName: "camera.fill", withConfiguration: cfg)
        iv.tintColor = UIColor.white.withAlphaComponent(0.08)
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    // HUD overlaid on the frame — shot name top-left, time bottom-left
    private let hudShotLabel: UILabel = {
        let l = UILabel()
        l.font            = .systemFont(ofSize: 13, weight: .bold)
        l.textColor       = .white
        l.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        l.layer.cornerRadius = 6; l.clipsToBounds = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let hudCamLabel: UILabel = {
        let l = UILabel()
        l.font            = .systemFont(ofSize: 11, weight: .medium)
        l.textColor       = UIColor.white.withAlphaComponent(0.8)
        l.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        l.layer.cornerRadius = 5; l.clipsToBounds = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let hudTimeLabel: UILabel = {
        let l = UILabel()
        l.font            = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        l.textColor       = .white
        l.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        l.layer.cornerRadius = 5; l.clipsToBounds = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // Cut flash
    private let cutLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13, weight: .semibold)
        l.textColor = UIColor.white.withAlphaComponent(0.8)
        l.textAlignment = .center; l.alpha = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // ── TIMELINE BAR ──────────────────────────────────────────────────────────
    // Sits at the very bottom of the frame — does NOT overlap buttons.
    // Layout: [00:00] [━━━━━━━━●━━━━━━━━] [00:04]

    private lazy var timelineBar: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let startTimeLbl: UILabel = {
        let l = UILabel()
        l.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        l.textColor = UIColor.white.withAlphaComponent(0.55)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let endTimeLbl: UILabel = {
        let l = UILabel()
        l.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        l.textColor = UIColor.white.withAlphaComponent(0.55)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var scrubber: UISlider = {
        let s = UISlider()
        s.minimumValue          = 0; s.maximumValue = 1; s.value = 0
        s.minimumTrackTintColor = appRed
        s.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.2)
        s.thumbTintColor        = .white
        s.translatesAutoresizingMaskIntoConstraints = false
        s.addTarget(self, action: #selector(scrubChanged),   for: .valueChanged)
        s.addTarget(self, action: #selector(scrubTouchDown), for: .touchDown)
        s.addTarget(self, action: #selector(scrubTouchUp),   for: [.touchUpInside, .touchUpOutside])
        return s
    }()

    // ── BUTTONS PANEL (separate from timeline, clearly above strip) ───────────
    private lazy var buttonsPanel: UIView = {
        let v = UIView()
        v.backgroundColor = panelBg
        v.layer.cornerRadius = 14
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let shotInfoLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11, weight: .semibold)
        l.textColor = UIColor.white.withAlphaComponent(0.45)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var prevBtn = makeBtn(icon: "backward.end.fill", size: 17)
    private lazy var playBtn = makeBtn(icon: "play.fill",          size: 24)
    private lazy var nextBtn = makeBtn(icon: "forward.end.fill",   size: 17)

    // ── FILM STRIP ────────────────────────────────────────────────────────────
    private lazy var strip: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 70, height: 46)
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.register(StripCell.self, forCellWithReuseIdentifier: StripCell.reuseID)
        cv.dataSource = self; cv.delegate = self
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    private let stripHeaderLbl: UILabel = {
        let l = UILabel()
        l.text = "ALL SHOTS"
        l.font = .systemFont(ofSize: 9, weight: .black)
        l.textColor = UIColor.white.withAlphaComponent(0.22)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = navy
        setupNav()
        setupLayout()
        sync()
        if playAll { startPlayback() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopPlayback()
        evaluateTimeline?(0)
    }

    // MARK: - Nav

    private func setupNav() {
        let app = UINavigationBarAppearance()
        app.configureWithOpaqueBackground()
        app.backgroundColor = navy
        app.titleTextAttributes = [.foregroundColor: UIColor.white,
                                    .font: UIFont.systemFont(ofSize: 17, weight: .semibold)]
        navigationController?.navigationBar.standardAppearance   = app
        navigationController?.navigationBar.scrollEdgeAppearance = app
        navigationController?.navigationBar.tintColor = .white

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain, target: self, action: #selector(backTapped))

        let exportItem = UIBarButtonItem(title: "Export", style: .plain,
                                         target: self, action: #selector(exportTapped))
        exportItem.setTitleTextAttributes([.foregroundColor: appRed,
                                            .font: UIFont.systemFont(ofSize: 15, weight: .semibold)],
                                           for: .normal)
        navigationItem.rightBarButtonItem = exportItem
    }

    // MARK: - Layout
    //
    // Structure (top → bottom):
    //   [Nav bar]
    //   [frameView — 16:9 — fills width]
    //     └─ frameImageView (fills)
    //     └─ hudShotLabel (top-left)
    //     └─ hudCamLabel  (top-left, below shot label)
    //     └─ hudTimeLabel (bottom-left)
    //     └─ cutLabel     (bottom-center)
    //     └─ timelineBar  (bottom, 40pt tall)
    //           [startTime] [━━scrubber━━] [endTime]
    //   [buttonsPanel — 80pt]
    //     [shotInfoLabel centered]
    //     [prev | ▶ | next centered]
    //   [stripHeaderLbl]
    //   [strip — 56pt]

    private func setupLayout() {
        // Frame
        frameView.addSubview(frameImageView)
        frameView.addSubview(placeholderIcon)
        frameView.addSubview(hudShotLabel)
        frameView.addSubview(hudCamLabel)
        frameView.addSubview(hudTimeLabel)
        frameView.addSubview(cutLabel)
        frameView.addSubview(timelineBar)

        // Timeline bar contents
        timelineBar.addSubview(startTimeLbl)
        timelineBar.addSubview(scrubber)
        timelineBar.addSubview(endTimeLbl)

        view.addSubview(frameView)

        // Buttons panel
        let btnStack = UIStackView(arrangedSubviews: [prevBtn, playBtn, nextBtn])
        btnStack.axis = .horizontal; btnStack.spacing = 32; btnStack.alignment = .center
        btnStack.translatesAutoresizingMaskIntoConstraints = false
        buttonsPanel.addSubview(shotInfoLabel)
        buttonsPanel.addSubview(btnStack)
        view.addSubview(buttonsPanel)

        // Strip
        view.addSubview(stripHeaderLbl)
        view.addSubview(strip)

        NSLayoutConstraint.activate([
            // Frame — full width, 16:9
            frameView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            frameView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            frameView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            frameView.heightAnchor.constraint(equalTo: frameView.widthAnchor, multiplier: 9.0/16.0),

            frameImageView.topAnchor.constraint(equalTo: frameView.topAnchor),
            frameImageView.leadingAnchor.constraint(equalTo: frameView.leadingAnchor),
            frameImageView.trailingAnchor.constraint(equalTo: frameView.trailingAnchor),
            frameImageView.bottomAnchor.constraint(equalTo: frameView.bottomAnchor),

            placeholderIcon.centerXAnchor.constraint(equalTo: frameView.centerXAnchor),
            placeholderIcon.centerYAnchor.constraint(equalTo: frameView.centerYAnchor),

            // HUD — top-left
            hudShotLabel.topAnchor.constraint(equalTo: frameView.topAnchor, constant: 10),
            hudShotLabel.leadingAnchor.constraint(equalTo: frameView.leadingAnchor, constant: 10),

            hudCamLabel.topAnchor.constraint(equalTo: hudShotLabel.bottomAnchor, constant: 4),
            hudCamLabel.leadingAnchor.constraint(equalTo: frameView.leadingAnchor, constant: 10),

            // HUD — bottom-left (above timeline bar)
            hudTimeLabel.bottomAnchor.constraint(equalTo: timelineBar.topAnchor, constant: -6),
            hudTimeLabel.leadingAnchor.constraint(equalTo: frameView.leadingAnchor, constant: 10),

            cutLabel.bottomAnchor.constraint(equalTo: timelineBar.topAnchor, constant: -6),
            cutLabel.centerXAnchor.constraint(equalTo: frameView.centerXAnchor),

            // Timeline bar — bottom of frame, full width, 40pt
            timelineBar.leadingAnchor.constraint(equalTo: frameView.leadingAnchor),
            timelineBar.trailingAnchor.constraint(equalTo: frameView.trailingAnchor),
            timelineBar.bottomAnchor.constraint(equalTo: frameView.bottomAnchor),
            timelineBar.heightAnchor.constraint(equalToConstant: 40),

            startTimeLbl.leadingAnchor.constraint(equalTo: timelineBar.leadingAnchor, constant: 12),
            startTimeLbl.centerYAnchor.constraint(equalTo: timelineBar.centerYAnchor),
            startTimeLbl.widthAnchor.constraint(equalToConstant: 44),

            endTimeLbl.trailingAnchor.constraint(equalTo: timelineBar.trailingAnchor, constant: -12),
            endTimeLbl.centerYAnchor.constraint(equalTo: timelineBar.centerYAnchor),
            endTimeLbl.widthAnchor.constraint(equalToConstant: 44),

            scrubber.leadingAnchor.constraint(equalTo: startTimeLbl.trailingAnchor, constant: 6),
            scrubber.trailingAnchor.constraint(equalTo: endTimeLbl.leadingAnchor, constant: -6),
            scrubber.centerYAnchor.constraint(equalTo: timelineBar.centerYAnchor),

            // Buttons panel
            buttonsPanel.topAnchor.constraint(equalTo: frameView.bottomAnchor, constant: 12),
            buttonsPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            buttonsPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),

            shotInfoLabel.topAnchor.constraint(equalTo: buttonsPanel.topAnchor, constant: 10),
            shotInfoLabel.centerXAnchor.constraint(equalTo: buttonsPanel.centerXAnchor),

            btnStack.topAnchor.constraint(equalTo: shotInfoLabel.bottomAnchor, constant: 10),
            btnStack.centerXAnchor.constraint(equalTo: buttonsPanel.centerXAnchor),
            btnStack.bottomAnchor.constraint(equalTo: buttonsPanel.bottomAnchor, constant: -14),

            prevBtn.widthAnchor.constraint(equalToConstant: 44),
            prevBtn.heightAnchor.constraint(equalToConstant: 44),
            playBtn.widthAnchor.constraint(equalToConstant: 56),
            playBtn.heightAnchor.constraint(equalToConstant: 56),
            nextBtn.widthAnchor.constraint(equalToConstant: 44),
            nextBtn.heightAnchor.constraint(equalToConstant: 44),

            // Strip
            stripHeaderLbl.topAnchor.constraint(equalTo: buttonsPanel.bottomAnchor, constant: 18),
            stripHeaderLbl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            strip.topAnchor.constraint(equalTo: stripHeaderLbl.bottomAnchor, constant: 8),
            strip.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            strip.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            strip.heightAnchor.constraint(equalToConstant: 56),
            strip.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
        ])
    }

    // MARK: - Camera POV Snapshot
    //
    // For the shot's camera we:
    // 1. Find the matching SceneCameraItem by name
    // 2. Call captureFromCamera (supplied by CanvasViewController)
    //    which activates that camera, snapshots, then restores editor camera
    // 3. Display the result in frameImageView

    private func updateFrameImage(at masterTime: Float) {
        guard let evaluate = evaluateTimeline else {
            placeholderIcon.isHidden = false; return
        }

        // Evaluate scene positions
        evaluate(masterTime)

        // Find the camera item for the current shot
        let camItem = cameraItems.first { item in
            item.cameraRoot.name == currentShot.cameraName ||
            item.cameraRoot.name.contains(currentShot.cameraName)
        }

        if let capture = captureFromCamera {
            // Use camera POV capture
            if let img = capture(camItem) {
                frameImageView.image = img
                placeholderIcon.isHidden = true
            } else {
                // Fallback to direct snapshot
                fallbackSnapshot()
            }
        } else {
            fallbackSnapshot()
        }
    }

    private func fallbackSnapshot() {
        arView?.snapshot(saveToHDR: false) { [weak self] image in
            guard let self = self, let image = image else { return }
            DispatchQueue.main.async {
                self.frameImageView.image = image
                self.placeholderIcon.isHidden = true
            }
        }
    }

    // MARK: - Sync

    private func sync() {
        let shot = currentShot
        title = "\(sceneName) — \(shot.displayName)"
        shotInfoLabel.text = "\(shot.displayName.uppercased())  ·  \(shot.cleanCameraName.uppercased())"
        endTimeLbl.text  = fmt(shot.duration)
        startTimeLbl.text = "00:00"
        scrubber.value   = 0
        currentTime      = 0

        // HUD
        hudShotLabel.text = "  \(shot.displayName)  "
        hudCamLabel.text  = "  \(shot.cleanCameraName)  "
        hudTimeLabel.text = "  00:00  "

        strip.reloadData()
        if currentIndex < shots.count {
            strip.scrollToItem(at: IndexPath(item: currentIndex, section: 0),
                               at: .centeredHorizontally, animated: true)
        }

        updateFrameImage(at: shot.startTime)
    }

    private func fmt(_ s: Float) -> String {
        let t = max(0, s)
        return String(format: "%02d:%02d", Int(t) / 60, Int(t) % 60)
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
        isPlaying = false; updatePlayIcon()
    }

    private func updatePlayIcon() {
        let name = isPlaying ? "pause.fill" : "play.fill"
        let cfg  = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        playBtn.setImage(UIImage(systemName: name, withConfiguration: cfg), for: .normal)
    }

    @objc private func tick() {
        guard isPlaying else { return }
        currentTime = Float(CACurrentMediaTime() - playStart)
        let duration = currentShot.duration

        if currentTime >= duration {
            if playAll && currentIndex < shots.count - 1 {
                let fromName = currentShot.displayName
                currentIndex += 1; currentTime = 0
                playStart = CACurrentMediaTime()
                sync()
                cutLabel.text = "\(fromName)  →  \(currentShot.displayName)"
                UIView.animate(withDuration: 0.15, animations: { self.cutLabel.alpha = 1 }) { _ in
                    UIView.animate(withDuration: 0.35, delay: 1.0) { self.cutLabel.alpha = 0 }
                }
                return
            } else {
                currentTime = duration; stopPlayback()
            }
        }

        let progress = currentTime / max(0.01, duration)
        scrubber.value       = progress
        startTimeLbl.text    = fmt(currentTime)
        hudTimeLabel.text    = "  \(fmt(currentTime)) / \(fmt(duration))  "
        title = playAll ? "Playing: \(sceneName) — \(currentShot.displayName)" : title

        // Update frame — camera POV at master time
        let masterTime = currentShot.startTime + currentTime
        updateFrameImage(at: masterTime)
    }

    // MARK: - Actions

    @objc private func backTapped() {
        stopPlayback(); evaluateTimeline?(0)
        navigationController?.popViewController(animated: true)
    }

    // FIX 3: MP4 Export via ReplayKit screen recording
    @objc private func exportTapped() {
        let alert = UIAlertController(title: "Export Shot",
                                       message: "\(currentShot.displayName)  ·  \(currentShot.cleanCameraName)",
                                       preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "📹 Record MP4 (Screen Recording)", style: .default) { [weak self] _ in
            self?.startMP4Recording()
        })
        alert.addAction(UIAlertAction(title: "🖼 Export Frame as JPEG", style: .default) { [weak self] _ in
            self?.exportCurrentFrame(asPNG: false)
        })
        alert.addAction(UIAlertAction(title: "🖼 Export Frame as PNG", style: .default) { [weak self] _ in
            self?.exportCurrentFrame(asPNG: true)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let pop = alert.popoverPresentationController {
            pop.barButtonItem = navigationItem.rightBarButtonItem
        }
        present(alert, animated: true)
    }

    // ── MP4: use ReplayKit to record screen while playing the shot ────────────
    private func startMP4Recording() {
        let recorder = RPScreenRecorder.shared()
        guard recorder.isAvailable else {
            showAlert("Screen recording not available on this device.")
            return
        }

        recorder.startRecording { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                DispatchQueue.main.async { self.showAlert("Recording failed: \(error.localizedDescription)") }
                return
            }
            DispatchQueue.main.async {
                // Play the shot — recording captures exactly what's on screen
                self.currentTime = 0
                self.scrubber.value = 0
                self.startPlayback()

                // Stop recording after shot duration + small buffer
                let duration = Double(self.currentShot.duration) + 0.3
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    self.stopPlayback()
                    recorder.stopRecording { previewVC, error in
                        DispatchQueue.main.async {
                            if let previewVC = previewVC {
                                previewVC.previewControllerDelegate = self
                                self.present(previewVC, animated: true)
                            } else if let error = error {
                                self.showAlert("Could not finish recording: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
        }
    }

    private func exportCurrentFrame(asPNG: Bool) {
        guard let img = frameImageView.image else {
            showAlert("No frame to export. Play the shot first."); return
        }
        let data = asPNG ? img.pngData() : img.jpegData(compressionQuality: 0.92)
        guard let d = data, let exportImg = UIImage(data: d) else { return }
        let vc = UIActivityViewController(activityItems: [exportImg], applicationActivities: nil)
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

    @objc private func btnTapped(_ sender: UIButton) {
        if sender == playBtn {
            isPlaying ? stopPlayback() : startPlayback()
        } else if sender == prevBtn {
            stopPlayback(); guard currentIndex > 0 else { return }
            currentIndex -= 1; currentTime = 0; sync()
        } else if sender == nextBtn {
            stopPlayback(); guard currentIndex < shots.count - 1 else { return }
            currentIndex += 1; currentTime = 0; sync()
        }
    }

    @objc private func scrubChanged(_ s: UISlider) {
        currentTime = s.value * currentShot.duration
        startTimeLbl.text = fmt(currentTime)
        hudTimeLabel.text = "  \(fmt(currentTime)) / \(fmt(currentShot.duration))  "
        if isPlaying { playStart = CACurrentMediaTime() - CFTimeInterval(currentTime) }
        updateFrameImage(at: currentShot.startTime + currentTime)
    }
    @objc private func scrubTouchDown() { stopPlayback() }
    @objc private func scrubTouchUp()   { startPlayback() }

    private func makeBtn(icon: String, size: CGFloat) -> UIButton {
        let btn = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: size, weight: .medium)
        btn.setImage(UIImage(systemName: icon, withConfiguration: cfg), for: .normal)
        btn.tintColor = .white
        btn.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        btn.layer.cornerRadius = size == 24 ? 28 : 22
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(btnTapped(_:)), for: .touchUpInside)
        return btn
    }
}

// MARK: - Strip DataSource

extension ShotPlayerViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ cv: UICollectionView, numberOfItemsInSection _: Int) -> Int { shots.count }

    func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: StripCell.reuseID, for: ip) as! StripCell
        cell.configure(with: shots[ip.item], isActive: ip.item == currentIndex)
        return cell
    }

    func collectionView(_ cv: UICollectionView, didSelectItemAt ip: IndexPath) {
        stopPlayback(); currentIndex = ip.item; currentTime = 0; sync()
    }
}

// MARK: - ReplayKit Preview Delegate

extension ShotPlayerViewController: RPPreviewViewControllerDelegate {
    func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
        previewController.dismiss(animated: true)
    }
}

// MARK: - Strip Cell

class StripCell: UICollectionViewCell {
    static let reuseID = "StripCell"
    private let appRed = UIColor(red: 177/255, green: 32/255, blue: 57/255, alpha: 1)

    private let bg   = UIView()
    private let img  = UIImageView()
    private let lbl  = UILabel()
    private let bar  = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        bg.layer.cornerRadius = 6; bg.clipsToBounds = true
        bg.translatesAutoresizingMaskIntoConstraints = false
        img.contentMode = .scaleAspectFill; img.clipsToBounds = true
        img.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = .systemFont(ofSize: 11, weight: .bold); lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        bar.layer.cornerRadius = 1.5
        bar.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(img); bg.addSubview(lbl); bg.addSubview(bar)
        contentView.addSubview(bg)
        NSLayoutConstraint.activate([
            bg.topAnchor.constraint(equalTo: contentView.topAnchor),
            bg.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bg.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            img.topAnchor.constraint(equalTo: bg.topAnchor),
            img.leadingAnchor.constraint(equalTo: bg.leadingAnchor),
            img.trailingAnchor.constraint(equalTo: bg.trailingAnchor),
            img.bottomAnchor.constraint(equalTo: bg.bottomAnchor),
            lbl.centerXAnchor.constraint(equalTo: bg.centerXAnchor),
            lbl.centerYAnchor.constraint(equalTo: bg.centerYAnchor),
            bar.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 4),
            bar.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -4),
            bar.bottomAnchor.constraint(equalTo: bg.bottomAnchor, constant: -2),
            bar.heightAnchor.constraint(equalToConstant: 3),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(with shot: Shot, isActive: Bool) {
        if let thumb = shot.thumbnail {
            img.image = thumb; img.isHidden = false; lbl.isHidden = true
            img.alpha = isActive ? 1.0 : 0.45
        } else {
            img.isHidden = true; lbl.isHidden = false; lbl.text = shot.shortLabel
        }
        bg.backgroundColor = isActive
            ? UIColor(red: 32/255, green: 16/255, blue: 42/255, alpha: 1)
            : UIColor(red: 18/255, green: 18/255, blue: 30/255, alpha: 1)
        bg.layer.borderWidth = isActive ? 1.5 : 0
        bg.layer.borderColor = appRed.cgColor
        bar.backgroundColor  = isActive ? appRed : .clear
        lbl.textColor = isActive ? .white : UIColor.white.withAlphaComponent(0.3)
    }
}
