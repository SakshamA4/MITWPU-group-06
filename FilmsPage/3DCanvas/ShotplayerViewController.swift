//
//  ShotPlayerViewController.swift
//  3DCanvas
//
//  Shows the actual ARView snapshot at the current scrub position.
//  When playing, evaluates the scene timeline on each tick, snapshots, and displays.
//

import UIKit
import RealityKit

class ShotPlayerViewController: UIViewController {

    private let navy    = UIColor(red: 11/255,  green: 11/255,  blue: 22/255,  alpha: 1)
    private let appRed  = UIColor(red: 177/255, green: 32/255,  blue: 57/255,  alpha: 1)
    private let panelBg = UIColor(red: 18/255,  green: 18/255,  blue: 32/255,  alpha: 1)
    private let thumbBg = UIColor(red: 12/255,  green: 12/255,  blue: 22/255,  alpha: 1)

    // MARK: Init
    init(shots: [Shot], startIndex: Int, playAll: Bool,
         sceneName: String, arView: ARView?, evaluateTimeline: ((Float) -> Void)?) {
        self.shots            = shots
        self.currentIndex     = startIndex
        self.playAll          = playAll
        self.sceneName        = sceneName
        self.arView           = arView
        self.evaluateTimeline = evaluateTimeline
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: State
    var shots: [Shot]
    var currentIndex: Int
    var playAll: Bool
    var sceneName: String
    weak var arView: ARView?
    var evaluateTimeline: ((Float) -> Void)?

    private var isPlaying   = false
    private var displayLink: CADisplayLink?
    private var playStart: CFTimeInterval = 0
    private var currentTime: Float = 0
    private var currentShot: Shot { shots[currentIndex] }

    // MARK: UI

    /// Shows the actual scene frame — updated from ARView.snapshot() on each scrub/play tick
    private lazy var frameImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode  = .scaleAspectFit
        iv.clipsToBounds = true
        iv.backgroundColor = thumbBg
        iv.layer.cornerRadius = 12
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

    // Shot info overlay on the frame — shows name while playing
    private let nowPlayingLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13, weight: .semibold)
        l.textColor = .white
        l.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        l.layer.cornerRadius = 8
        l.clipsToBounds = true
        l.textAlignment = .center
        l.alpha = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // Cut flash label
    private let cutLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12, weight: .semibold)
        l.textColor = UIColor.white.withAlphaComponent(0.75)
        l.textAlignment = .center
        l.alpha = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // Controls panel
    private lazy var panel: UIView = {
        let v = UIView()
        v.backgroundColor = panelBg
        v.layer.cornerRadius = 16
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let shotInfoLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12, weight: .semibold)
        l.textColor = UIColor.white.withAlphaComponent(0.5)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let currentTimeLbl: UILabel = {
        let l = UILabel()
        l.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        l.textColor = UIColor.white.withAlphaComponent(0.45)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let totalTimeLbl: UILabel = {
        let l = UILabel()
        l.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        l.textColor = UIColor.white.withAlphaComponent(0.45)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var scrubber: UISlider = {
        let s = UISlider()
        s.minimumValue = 0; s.maximumValue = 1; s.value = 0
        s.minimumTrackTintColor = appRed
        s.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.12)
        s.thumbTintColor = .white
        s.translatesAutoresizingMaskIntoConstraints = false
        s.addTarget(self, action: #selector(scrubChanged), for: .valueChanged)
        s.addTarget(self, action: #selector(scrubDown),    for: .touchDown)
        s.addTarget(self, action: #selector(scrubUp),      for: [.touchUpInside, .touchUpOutside])
        return s
    }()

    private lazy var prevBtn  = ctrlBtn(icon: "backward.end.fill", size: 17)
    private lazy var playBtn  = ctrlBtn(icon: "play.fill",          size: 24)
    private lazy var nextBtn  = ctrlBtn(icon: "forward.end.fill",   size: 17)

    // Film strip
    private lazy var strip: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 64, height: 42)
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
        l.textColor = UIColor.white.withAlphaComponent(0.25)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = navy
        setupNav(); setupLayout()
        sync()
        // Show the first frame immediately
        updateFrameImage(at: currentShot.startTime)
        if playAll { startPlayback() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopPlayback()
        // Restore scene to base state
        evaluateTimeline?(0)
    }

    // MARK: Nav

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

    // MARK: Layout

    private func setupLayout() {
        // Frame viewer
        view.addSubview(frameImageView)
        frameImageView.addSubview(placeholderIcon)
        frameImageView.addSubview(nowPlayingLabel)
        frameImageView.addSubview(cutLabel)

        // Panel
        view.addSubview(panel)
        panel.addSubview(shotInfoLabel)
        panel.addSubview(currentTimeLbl)
        panel.addSubview(totalTimeLbl)
        panel.addSubview(scrubber)

        let btnStack = UIStackView(arrangedSubviews: [prevBtn, playBtn, nextBtn])
        btnStack.axis = .horizontal; btnStack.spacing = 28; btnStack.alignment = .center
        btnStack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(btnStack)

        view.addSubview(stripHeaderLbl)
        view.addSubview(strip)

        NSLayoutConstraint.activate([
            // Frame — 16:9, top
            frameImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 14),
            frameImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            frameImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            frameImageView.heightAnchor.constraint(equalTo: frameImageView.widthAnchor, multiplier: 9.0/16.0),

            placeholderIcon.centerXAnchor.constraint(equalTo: frameImageView.centerXAnchor),
            placeholderIcon.centerYAnchor.constraint(equalTo: frameImageView.centerYAnchor),

            nowPlayingLabel.leadingAnchor.constraint(equalTo: frameImageView.leadingAnchor, constant: 10),
            nowPlayingLabel.topAnchor.constraint(equalTo: frameImageView.topAnchor, constant: 10),
            nowPlayingLabel.widthAnchor.constraint(lessThanOrEqualTo: frameImageView.widthAnchor, multiplier: 0.6),

            cutLabel.bottomAnchor.constraint(equalTo: frameImageView.bottomAnchor, constant: -10),
            cutLabel.centerXAnchor.constraint(equalTo: frameImageView.centerXAnchor),

            // Panel
            panel.topAnchor.constraint(equalTo: frameImageView.bottomAnchor, constant: 14),
            panel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            panel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),

            shotInfoLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: 14),
            shotInfoLabel.centerXAnchor.constraint(equalTo: panel.centerXAnchor),

            currentTimeLbl.topAnchor.constraint(equalTo: shotInfoLabel.bottomAnchor, constant: 12),
            currentTimeLbl.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 14),

            totalTimeLbl.centerYAnchor.constraint(equalTo: currentTimeLbl.centerYAnchor),
            totalTimeLbl.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -14),

            scrubber.centerYAnchor.constraint(equalTo: currentTimeLbl.centerYAnchor),
            scrubber.leadingAnchor.constraint(equalTo: currentTimeLbl.trailingAnchor, constant: 10),
            scrubber.trailingAnchor.constraint(equalTo: totalTimeLbl.leadingAnchor, constant: -10),

            btnStack.topAnchor.constraint(equalTo: currentTimeLbl.bottomAnchor, constant: 16),
            btnStack.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
            btnStack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -18),

            prevBtn.widthAnchor.constraint(equalToConstant: 44),
            prevBtn.heightAnchor.constraint(equalToConstant: 44),
            playBtn.widthAnchor.constraint(equalToConstant: 56),
            playBtn.heightAnchor.constraint(equalToConstant: 56),
            nextBtn.widthAnchor.constraint(equalToConstant: 44),
            nextBtn.heightAnchor.constraint(equalToConstant: 44),

            stripHeaderLbl.topAnchor.constraint(equalTo: panel.bottomAnchor, constant: 20),
            stripHeaderLbl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            strip.topAnchor.constraint(equalTo: stripHeaderLbl.bottomAnchor, constant: 8),
            strip.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            strip.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            strip.heightAnchor.constraint(equalToConstant: 52),
            strip.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
        ])
    }

    // MARK: Frame capture
    // Evaluates the timeline at the given master time and snapshots the ARView.
    // The snapshot is then placed into frameImageView — this IS the preview.

    private func updateFrameImage(at masterTime: Float) {
        guard let arView = arView, let evaluate = evaluateTimeline else {
            placeholderIcon.isHidden = false; return
        }
        evaluate(masterTime)
        arView.snapshot(saveToHDR: false) { [weak self] image in
            guard let self = self, let image = image else { return }
            DispatchQueue.main.async {
                self.frameImageView.image = image
                self.placeholderIcon.isHidden = true
            }
        }
    }

    // MARK: Sync UI to current shot

    private func sync() {
        let shot = currentShot
        title = "\(sceneName) — \(shot.displayName)"

        let cam = shot.cleanCameraName
        shotInfoLabel.text = "\(shot.displayName.uppercased())  ·  \(cam.uppercased())"
        totalTimeLbl.text  = fmt(shot.duration)
        currentTimeLbl.text = fmt(0)
        scrubber.value = 0
        currentTime = 0

        strip.reloadData()
        if currentIndex < shots.count {
            strip.scrollToItem(at: IndexPath(item: currentIndex, section: 0),
                               at: .centeredHorizontally, animated: true)
        }

        // Show first frame of this shot
        updateFrameImage(at: shot.startTime)

        // Show "Shot X" label overlay briefly
        nowPlayingLabel.text = "  \(shot.displayName)  "
        UIView.animate(withDuration: 0.2, animations: { self.nowPlayingLabel.alpha = 1 }) { _ in
            UIView.animate(withDuration: 0.4, delay: 1.5) { self.nowPlayingLabel.alpha = 0 }
        }
    }

    private func fmt(_ s: Float) -> String {
        let t = max(0, s)
        return String(format: "%02d:%02d", Int(t) / 60, Int(t) % 60)
    }

    // MARK: Playback

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
                // Flash cut label
                cutLabel.text = "\(fromName)  →  \(currentShot.displayName)"
                UIView.animate(withDuration: 0.15, animations: { self.cutLabel.alpha = 1 }) { _ in
                    UIView.animate(withDuration: 0.4, delay: 0.8) { self.cutLabel.alpha = 0 }
                }
                return
            } else {
                currentTime = duration; stopPlayback()
            }
        }

        scrubber.value = currentTime / max(0.01, duration)
        currentTimeLbl.text = fmt(currentTime)
        title = playAll ? "Playing: \(sceneName) — \(currentShot.displayName)" : title

        // Update the frame image at current master time
        let masterTime = currentShot.startTime + currentTime
        updateFrameImage(at: masterTime)
    }

    // MARK: Actions

    @objc private func backTapped() {
        stopPlayback(); evaluateTimeline?(0)
        navigationController?.popViewController(animated: true)
    }

    @objc private func exportTapped() {
        let exportVC = ExportVC()
        exportVC.projectName = "\(sceneName) — \(currentShot.displayName)"
        exportVC.onFormatSelected = { [weak self] format in
            guard let self = self else { return }
            exportVC.dismiss(animated: true) {
                print("Export \(self.currentShot.displayName) as \(format)")
            }
        }
        if let sheet = exportVC.sheetPresentationController {
            sheet.detents = [.medium()]; sheet.prefersGrabberVisible = true
        }
        present(exportVC, animated: true)
    }

    @objc private func ctrlTapped(_ sender: UIButton) {
        if sender == playBtn {
            isPlaying ? stopPlayback() : startPlayback()
        } else if sender == prevBtn {
            stopPlayback()
            guard currentIndex > 0 else { return }
            currentIndex -= 1; currentTime = 0; sync()
        } else if sender == nextBtn {
            stopPlayback()
            guard currentIndex < shots.count - 1 else { return }
            currentIndex += 1; currentTime = 0; sync()
        }
    }

    @objc private func scrubChanged(_ s: UISlider) {
        currentTime = s.value * currentShot.duration
        currentTimeLbl.text = fmt(currentTime)
        if isPlaying { playStart = CACurrentMediaTime() - CFTimeInterval(currentTime) }
        updateFrameImage(at: currentShot.startTime + currentTime)
    }

    @objc private func scrubDown() { stopPlayback() }
    @objc private func scrubUp()   { startPlayback() }

    private func ctrlBtn(icon: String, size: CGFloat) -> UIButton {
        let btn = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: size, weight: .medium)
        btn.setImage(UIImage(systemName: icon, withConfiguration: cfg), for: .normal)
        btn.tintColor = .white
        btn.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        btn.layer.cornerRadius = size == 24 ? 28 : 22
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(ctrlTapped(_:)), for: .touchUpInside)
        return btn
    }
}

// MARK: - Strip CollectionView

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

// MARK: - Strip Cell

class StripCell: UICollectionViewCell {
    static let reuseID = "StripCell"
    private let appRed = UIColor(red: 177/255, green: 32/255, blue: 57/255, alpha: 1)

    private let bg    = UIView()
    private let img   = UIImageView()
    private let lbl   = UILabel()
    private let bar   = UIView()

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
            img.image = thumb; img.isHidden = false
            // Darken thumbnail slightly when inactive
            img.alpha = isActive ? 1.0 : 0.5
            lbl.isHidden = true
        } else {
            img.isHidden = true; lbl.isHidden = false
            lbl.text = shot.shortLabel
        }
        bg.backgroundColor = isActive
            ? UIColor(red: 30/255, green: 18/255, blue: 40/255, alpha: 1)
            : UIColor(red: 18/255, green: 18/255, blue: 30/255, alpha: 1)
        bg.layer.borderWidth = isActive ? 1.5 : 0
        bg.layer.borderColor = appRed.cgColor
        bar.backgroundColor  = isActive ? appRed : .clear
        lbl.textColor = isActive ? .white : UIColor.white.withAlphaComponent(0.35)
    }
}
