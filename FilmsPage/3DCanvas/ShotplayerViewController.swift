//
//  ShotPlayerViewController.swift
//  3DCanvas
//
//  Plays shots individually or all sequentially on one screen.
//  When Play All is active, shots transition automatically like an editor timeline —
//  the active shot highlights in the strip and the header updates in real time.
//

import UIKit

class ShotPlayerViewController: UIViewController {

    // MARK: - Colors (app design system)
    private let navy      = UIColor(red: 11/255,  green: 11/255,  blue: 22/255,  alpha: 1)
    private let appRed    = UIColor(red: 177/255, green: 32/255,  blue: 57/255,  alpha: 1)
    private let panelBg   = UIColor(red: 20/255,  green: 20/255,  blue: 34/255,  alpha: 1)
    private let thumbBg   = UIColor(red: 14/255,  green: 14/255,  blue: 26/255,  alpha: 1)

    // MARK: - Init

    init(shots: [Shot], startIndex: Int, playAll: Bool, sceneName: String) {
        self.shots        = shots
        self.currentIndex = startIndex
        self.playAll      = playAll
        self.sceneName    = sceneName
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - State
    var shots: [Shot]
    var currentIndex: Int
    var playAll: Bool
    var sceneName: String

    private var isPlaying   = false
    private var displayLink: CADisplayLink?
    private var playbackStart: CFTimeInterval = 0
    private var currentTime: Float = 0          // time within current shot
    private var masterTime: Float  = 0          // time across ALL shots (used for Play All)

    private var currentShot: Shot { shots[currentIndex] }

    // MARK: - UI

    // Player area (wire in ARView snapshot or AVPlayer here)
    private lazy var playerArea: UIView = {
        let v = UIView()
        v.backgroundColor = thumbBg
        v.layer.cornerRadius = 12
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let playerIcon: UIImageView = {
        let iv = UIImageView()
        let cfg = UIImage.SymbolConfiguration(pointSize: 44, weight: .thin)
        iv.image = UIImage(systemName: "camera.fill", withConfiguration: cfg)
        iv.tintColor = UIColor.white.withAlphaComponent(0.07)
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    // Shot transition label — "Shot 1 → Shot 2" flashes briefly during cut
    private let cutLabel: UILabel = {
        let l = UILabel()
        l.font      = .systemFont(ofSize: 13, weight: .semibold)
        l.textColor = UIColor.white.withAlphaComponent(0.7)
        l.textAlignment = .center
        l.alpha     = 0
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
        l.font          = .systemFont(ofSize: 12, weight: .semibold)
        l.textColor     = UIColor.white.withAlphaComponent(0.5)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let currentTimeLbl: UILabel = {
        let l = UILabel()
        l.font      = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        l.textColor = UIColor.white.withAlphaComponent(0.45)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let totalTimeLbl: UILabel = {
        let l = UILabel()
        l.font      = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        l.textColor = UIColor.white.withAlphaComponent(0.45)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var scrubber: UISlider = {
        let s = UISlider()
        s.minimumValue       = 0
        s.maximumValue       = 1
        s.value              = 0
        s.minimumTrackTintColor = appRed
        s.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.12)
        s.thumbTintColor     = .white
        s.translatesAutoresizingMaskIntoConstraints = false
        s.addTarget(self, action: #selector(scrubChanged(_:)),      for: .valueChanged)
        s.addTarget(self, action: #selector(scrubTouchDown(_:)),    for: .touchDown)
        s.addTarget(self, action: #selector(scrubTouchUp(_:)),      for: [.touchUpInside, .touchUpOutside])
        return s
    }()

    private lazy var prevBtn  = makeCtrlBtn(icon: "backward.end.fill",  size: 17)
    private lazy var playBtn  = makeCtrlBtn(icon: "play.fill",          size: 24)
    private lazy var nextBtn  = makeCtrlBtn(icon: "forward.end.fill",   size: 17)

    // Film strip
    private lazy var strip: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection     = .horizontal
        layout.itemSize            = CGSize(width: 58, height: 38)
        layout.minimumLineSpacing  = 7
        layout.sectionInset        = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.register(StripCell.self, forCellWithReuseIdentifier: StripCell.reuseID)
        cv.dataSource = self
        cv.delegate   = self
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    private let stripHeaderLbl: UILabel = {
        let l = UILabel()
        l.text      = "ALL SHOTS"
        l.font      = .systemFont(ofSize: 9, weight: .black)
        l.textColor = UIColor.white.withAlphaComponent(0.25)
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
    }

    // MARK: - Navigation

    private func setupNav() {
        let app = UINavigationBarAppearance()
        app.configureWithOpaqueBackground()
        app.backgroundColor = navy
        app.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        navigationController?.navigationBar.standardAppearance   = app
        navigationController?.navigationBar.scrollEdgeAppearance = app
        navigationController?.navigationBar.tintColor = .white

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain, target: self, action: #selector(backTapped))

        let exportItem = UIBarButtonItem(
            title: "Export", style: .plain,
            target: self, action: #selector(exportTapped))
        exportItem.setTitleTextAttributes([
            .foregroundColor: appRed,
            .font: UIFont.systemFont(ofSize: 15, weight: .semibold)
        ], for: .normal)
        navigationItem.rightBarButtonItem = exportItem
    }

    // MARK: - Layout

    private func setupLayout() {
        playerArea.addSubview(playerIcon)
        playerArea.addSubview(cutLabel)
        view.addSubview(playerArea)
        view.addSubview(panel)
        view.addSubview(stripHeaderLbl)
        view.addSubview(strip)

        panel.addSubview(shotInfoLabel)
        panel.addSubview(currentTimeLbl)
        panel.addSubview(totalTimeLbl)
        panel.addSubview(scrubber)

        let btnStack = UIStackView(arrangedSubviews: [prevBtn, playBtn, nextBtn])
        btnStack.axis      = .horizontal
        btnStack.spacing   = 28
        btnStack.alignment = .center
        btnStack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(btnStack)

        NSLayoutConstraint.activate([
            // Player
            playerArea.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 14),
            playerArea.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            playerArea.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            playerArea.heightAnchor.constraint(equalTo: playerArea.widthAnchor, multiplier: 9/16),

            playerIcon.centerXAnchor.constraint(equalTo: playerArea.centerXAnchor),
            playerIcon.centerYAnchor.constraint(equalTo: playerArea.centerYAnchor),
            playerIcon.widthAnchor.constraint(equalToConstant: 50),
            playerIcon.heightAnchor.constraint(equalToConstant: 50),

            cutLabel.bottomAnchor.constraint(equalTo: playerArea.bottomAnchor, constant: -10),
            cutLabel.centerXAnchor.constraint(equalTo: playerArea.centerXAnchor),

            // Panel
            panel.topAnchor.constraint(equalTo: playerArea.bottomAnchor, constant: 14),
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

            // Strip
            stripHeaderLbl.topAnchor.constraint(equalTo: panel.bottomAnchor, constant: 20),
            stripHeaderLbl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            strip.topAnchor.constraint(equalTo: stripHeaderLbl.bottomAnchor, constant: 8),
            strip.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            strip.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            strip.heightAnchor.constraint(equalToConstant: 48),
            strip.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
        ])
    }

    // MARK: - Sync UI to current shot

    private func sync() {
        let shot = currentShot
        title = playAll
            ? "Playing: \(sceneName) — \(shot.displayName)"
            : "\(sceneName) — \(shot.displayName)"

        let cam = shot.cameraName
            .replacingOccurrences(of: "SceneCamera_", with: "Cam ")
            .replacingOccurrences(of: "Camera_", with: "Cam ")
        shotInfoLabel.text = "\(shot.displayName.uppercased())  ·  \(cam.uppercased())"

        totalTimeLbl.text   = fmt(shot.duration)
        currentTimeLbl.text = fmt(0)
        scrubber.value      = 0

        strip.reloadData()
        strip.scrollToItem(at: IndexPath(item: currentIndex, section: 0),
                           at: .centeredHorizontally, animated: true)
    }

    private func fmt(_ s: Float) -> String {
        let t = max(0, s)
        return String(format: "%02d:%02d", Int(t) / 60, Int(t) % 60)
    }

    // MARK: - Playback Engine

    private func startPlayback() {
        stopPlayback()
        isPlaying     = true
        playbackStart = CACurrentMediaTime() - CFTimeInterval(currentTime)
        updatePlayIcon()
        displayLink   = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopPlayback() {
        displayLink?.invalidate()
        displayLink = nil
        isPlaying   = false
        updatePlayIcon()
    }

    private func updatePlayIcon() {
        let name = isPlaying ? "pause.fill" : "play.fill"
        let cfg  = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        playBtn.setImage(UIImage(systemName: name, withConfiguration: cfg), for: .normal)
    }

    @objc private func tick() {
        guard isPlaying else { return }
        currentTime = Float(CACurrentMediaTime() - playbackStart)

        let duration = currentShot.duration

        if currentTime >= duration {
            // Shot finished
            if playAll && currentIndex < shots.count - 1 {
                // ── Auto-advance to next shot ──
                let fromName = currentShot.displayName
                currentIndex  += 1
                currentTime    = 0
                playbackStart  = CACurrentMediaTime()
                sync()

                // Flash cut label: "Shot 1 → Shot 2"
                cutLabel.text  = "\(fromName)  →  \(currentShot.displayName)"
                UIView.animate(withDuration: 0.15,
                               animations: { self.cutLabel.alpha = 1 }) { _ in
                    UIView.animate(withDuration: 0.5, delay: 0.8) {
                        self.cutLabel.alpha = 0
                    }
                }
                return
            } else {
                currentTime = duration
                stopPlayback()
            }
        }

        scrubber.value      = currentTime / max(0.01, currentShot.duration)
        currentTimeLbl.text = fmt(currentTime)

        if playAll {
            title = "Playing: \(sceneName) — \(currentShot.displayName)"
        }
    }

    // MARK: - Actions

    @objc private func backTapped() {
        stopPlayback()
        navigationController?.popViewController(animated: true)
    }

    @objc private func exportTapped() {
        let exportVC = ExportVC()
        exportVC.projectName = "\(sceneName) — \(currentShot.displayName)"
        exportVC.onFormatSelected = { [weak self] format in
            guard let self = self else { return }
            exportVC.dismiss(animated: true) {
                print("Export \(self.currentShot.displayName) as \(format)")
                // Hook: exportShot(self.currentShot, format: format, type: .singleShotMP4)
            }
        }
        if let sheet = exportVC.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        present(exportVC, animated: true)
    }

    @objc private func controlTapped(_ sender: UIButton) {
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
        currentTime         = s.value * currentShot.duration
        currentTimeLbl.text = fmt(currentTime)
        if isPlaying { playbackStart = CACurrentMediaTime() - CFTimeInterval(currentTime) }
    }
    @objc private func scrubTouchDown(_ s: UISlider) { stopPlayback() }
    @objc private func scrubTouchUp(_ s: UISlider)   { startPlayback() }

    // MARK: - Helpers

    private func makeCtrlBtn(icon: String, size: CGFloat) -> UIButton {
        let btn = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: size, weight: .medium)
        btn.setImage(UIImage(systemName: icon, withConfiguration: cfg), for: .normal)
        btn.tintColor       = .white
        btn.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        btn.layer.cornerRadius = size == 24 ? 28 : 22
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(controlTapped(_:)), for: .touchUpInside)
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
        stopPlayback()
        currentIndex = ip.item
        currentTime  = 0
        sync()
    }
}

// MARK: - Strip Cell

class StripCell: UICollectionViewCell {
    static let reuseID = "StripCell"
    private let appRed = UIColor(red: 177/255, green: 32/255, blue: 57/255, alpha: 1)

    private let bg    = UIView()
    private let lbl   = UILabel()
    private let bar   = UIView()        // red bottom bar on active

    override init(frame: CGRect) {
        super.init(frame: frame)
        bg.backgroundColor    = UIColor(red: 20/255, green: 20/255, blue: 34/255, alpha: 1)
        bg.layer.cornerRadius = 6
        bg.clipsToBounds      = true
        bg.translatesAutoresizingMaskIntoConstraints = false

        lbl.font          = .systemFont(ofSize: 11, weight: .bold)
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false

        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.layer.cornerRadius = 1.5

        bg.addSubview(lbl)
        bg.addSubview(bar)
        contentView.addSubview(bg)

        NSLayoutConstraint.activate([
            bg.topAnchor.constraint(equalTo: contentView.topAnchor),
            bg.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bg.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            lbl.centerXAnchor.constraint(equalTo: bg.centerXAnchor),
            lbl.centerYAnchor.constraint(equalTo: bg.centerYAnchor),

            bar.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 8),
            bar.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -8),
            bar.bottomAnchor.constraint(equalTo: bg.bottomAnchor, constant: -3),
            bar.heightAnchor.constraint(equalToConstant: 3),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(with shot: Shot, isActive: Bool) {
        lbl.text      = shot.shortLabel
        lbl.textColor = isActive ? .white : UIColor.white.withAlphaComponent(0.35)
        bg.backgroundColor = isActive
            ? UIColor(red: 30/255, green: 20/255, blue: 40/255, alpha: 1)
            : UIColor(red: 20/255, green: 20/255, blue: 34/255, alpha: 1)
        bg.layer.borderWidth = isActive ? 1.5 : 0
        bg.layer.borderColor = appRed.cgColor
        bar.backgroundColor  = isActive ? appRed : .clear
    }
}
