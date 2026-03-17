//
//  ShotBreakdownViewController.swift
//  3DCanvas
//
//  FIX 2: Thumbnails now show the camera's actual POV, not the editor view.
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
            .replacingOccurrences(of: "SceneCamera_", with: "Camera ")
            .replacingOccurrences(of: "SceneCamera", with: "Camera")
            .replacingOccurrences(of: "Camera_", with: "Camera ")
    }
}

// MARK: - Shot Derivation

struct ShotDerived {
    static func derive(from timeline: Timeline, cameraNames: [String]) -> [Shot] {
        let totalDuration = timeline.duration
        guard totalDuration > 0 else { return [] }

        let cameraClips = timeline.clips.filter { clip in
            cameraNames.contains(clip.entityName) ||
            clip.entityName.lowercased().contains("scenecamera") ||
            clip.entityName.lowercased().contains("camera")
        }

        if cameraClips.isEmpty {
            return [Shot(id: UUID(), index: 0, cameraName: "Editor Camera",
                         startTime: 0, duration: totalDuration, thumbnail: nil)]
        }

        var intervals: [(cam: String, start: Float, end: Float)] = []
        for (camName, clips) in Dictionary(grouping: cameraClips, by: { $0.entityName }) {
            var merging: (start: Float, end: Float)? = nil
            for clip in clips.sorted(by: { $0.startTime < $1.startTime }) {
                let s = clip.startTime, e = clip.startTime + clip.duration
                if var m = merging {
                    if s <= m.end + 0.01 { m.end = max(m.end, e); merging = m }
                    else { intervals.append((camName, m.start, m.end)); merging = (s, e) }
                } else { merging = (s, e) }
            }
            if let m = merging { intervals.append((camName, m.start, m.end)) }
        }

        return intervals.sorted { $0.start < $1.start }.enumerated().map { i, iv in
            Shot(id: UUID(), index: i, cameraName: iv.cam,
                 startTime: iv.start, duration: max(0.1, iv.end - iv.start), thumbnail: nil)
        }
    }
}

// MARK: - ShotBreakdownViewController

class ShotBreakdownViewController: UIViewController {

    private let navy   = UIColor(red: 11/255,  green: 11/255,  blue: 22/255,  alpha: 1)
    private let appRed = UIColor(red: 177/255, green: 32/255,  blue: 57/255,  alpha: 1)

    // MARK: - Public
    var sceneName: String  = "Scene"
    var timeline: Timeline = Timeline()
    var cameraNames: [String] = []
    /// Live ARView — for snapshot fallback only
    weak var arView: ARView?
    /// Scrubs the scene to the given master time
    var evaluateTimeline: ((Float) -> Void)?
    /// Camera items from CanvasViewController — needed to activate camera POV
    var cameraItems: [CanvasViewController.SceneCameraItem] = []
    /// Activates a scene camera, snapshots, restores editor camera. Returns image.
    /// Implement this in CanvasViewController and pass it in.
    var captureFrameAsync: ((CanvasViewController.SceneCameraItem?, @escaping (UIImage?) -> Void) -> Void)?

    private var shots: [Shot] = []
    private var thumbnailsGenerated = false

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 14
        layout.minimumInteritemSpacing = 14
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 48, right: 16)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.register(ShotCardCell.self, forCellWithReuseIdentifier: ShotCardCell.reuseID)
        cv.dataSource = self; cv.delegate = self
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    private let statsLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11, weight: .black)
        l.textColor = UIColor.white.withAlphaComponent(0.35)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let emptyLabel: UILabel = {
        let l = UILabel()
        l.text = "No shots detected.\nAdd scene cameras and animate them\nto generate a shot breakdown."
        l.numberOfLines = 0; l.textAlignment = .center
        l.font = .systemFont(ofSize: 15); l.textColor = .lightGray
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = navy
        shots = ShotDerived.derive(from: timeline, cameraNames: cameraNames)
        setupNav(); setupLayout(); refresh()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !thumbnailsGenerated { captureThumbnails(); thumbnailsGenerated = true }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.collectionView.collectionViewLayout.invalidateLayout()
        })
    }


    // MARK: - Camera POV Thumbnail Capture
    //
    // For each shot:
    // 1. Evaluate timeline at shot.startTime (positions all entities)
    // 2. Find the matching SceneCameraItem by camera name
    // 3. Call captureFromCamera to get actual POV image
    // 4. Reload cell

    private func captureThumbnails() {
        guard let evaluate = evaluateTimeline else { return }
        let count = shots.count

        func captureNext(_ i: Int) {
            guard i < count else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { evaluate(0) }
                return
            }

            let shot = shots[i]
            evaluate(shot.startTime)

            // Wait one render frame for evaluated positions to apply
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                guard let self = self else { return }

                // Find the matching camera item
                let camItem = self.cameraItems.first { item in
                    item.cameraRoot.name == shot.cameraName ||
                    item.cameraRoot.name.contains(shot.cameraName)
                }

                // Use async capture (no semaphore = no deadlock)
                let doCapture = self.captureFrameAsync ?? { _, cb in
                    // Fallback: snapshot editor view
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.033) {
                        self.arView?.snapshot(saveToHDR: false, completion: cb)
                    }
                }
                doCapture(camItem) { [weak self] img in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        if let img = img {
                            self.shots[i].thumbnail = img
                            if i < self.collectionView.numberOfItems(inSection: 0) {
                                self.collectionView.reloadItems(at: [IndexPath(item: i, section: 0)])
                            }
                        }
                        captureNext(i + 1)
                    }
                }
            }
        }
        captureNext(0)
    }

    // MARK: - Nav

    private func setupNav() {
        title = sceneName
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

        let btn = UIBarButtonItem(title: "▶  Play All", style: .plain,
                                   target: self, action: #selector(playAllTapped))
        btn.setTitleTextAttributes([.foregroundColor: appRed,
                                     .font: UIFont.systemFont(ofSize: 15, weight: .semibold)],
                                    for: .normal)
        navigationItem.rightBarButtonItem = btn
    }

    private func setupLayout() {
        view.addSubview(statsLabel); view.addSubview(collectionView); view.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            statsLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            statsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            collectionView.topAnchor.constraint(equalTo: statsLabel.bottomAnchor, constant: 4),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
        ])
    }

    private func refresh() {
        emptyLabel.isHidden = !shots.isEmpty
        collectionView.isHidden = shots.isEmpty
        navigationItem.rightBarButtonItem?.isEnabled = !shots.isEmpty
        let total = shots.reduce(0) { $0 + $1.duration }
        let m = Int(total) / 60, s = Int(total) % 60
        statsLabel.text = "\(shots.count) SHOTS  ·  \(m > 0 ? "\(m)m " : "")\(s)s TOTAL"
        collectionView.reloadData()
    }

    @objc private func backTapped() { navigationController?.popViewController(animated: true) }

    @objc private func playAllTapped() {
        guard !shots.isEmpty else { return }
        openPlayer(index: 0, playAll: true)
    }

    private func openPlayer(index: Int, playAll: Bool) {
        let vc = ShotPlayerViewController(
            shots: shots, startIndex: index, playAll: playAll,
            sceneName: sceneName, arView: arView,
            evaluateTimeline: evaluateTimeline,
            captureFrameAsync: captureFrameAsync,
            cameraItems: cameraItems)
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - CollectionView

extension ShotBreakdownViewController: UICollectionViewDataSource,
                                        UICollectionViewDelegate,
                                        UICollectionViewDelegateFlowLayout {
    func collectionView(_ cv: UICollectionView, numberOfItemsInSection _: Int) -> Int { shots.count }

    func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: ShotCardCell.reuseID, for: ip) as! ShotCardCell
        cell.configure(with: shots[ip.item], sceneName: sceneName)
        return cell
    }

    func collectionView(_ cv: UICollectionView, didSelectItemAt ip: IndexPath) {
        openPlayer(index: ip.item, playAll: false)
    }

    func collectionView(_ cv: UICollectionView, layout _: UICollectionViewLayout,
                        sizeForItemAt _: IndexPath) -> CGSize {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        let cols: CGFloat = isIPad ? 3 : 2
        let w = floor((cv.bounds.width - 16*2 - 14*(cols-1)) / cols)
        return CGSize(width: w, height: w * (9.0/16.0) + 62)
    }
}

// MARK: - Shot Card Cell

class ShotCardCell: UICollectionViewCell {
    static let reuseID = "ShotCardCell"

    private let appRed  = UIColor(red: 177/255, green: 32/255,  blue: 57/255,  alpha: 1)
    private let cardBg  = UIColor(red: 22/255,  green: 22/255,  blue: 36/255,  alpha: 1)
    private let thumbBg = UIColor(red: 12/255,  green: 12/255,  blue: 22/255,  alpha: 1)
    private let infoBg  = UIColor(red: 17/255,  green: 17/255,  blue: 30/255,  alpha: 1)

    private let thumb     = UIView()
    private let thumbImg  = UIImageView()
    private let thumbIcon = UIImageView()
    private let overlay   = UIView()
    private let gradient  = CAGradientLayer()
    private let infoRow   = UIView()
    private let badge     = UIView()
    private let badgeLbl  = UILabel()
    private let shotLbl   = UILabel()
    private let camLbl    = UILabel()
    private let sceneLbl  = UILabel()
    private let durLbl    = UILabel()

    override init(frame: CGRect) { super.init(frame: frame); build() }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() { super.layoutSubviews(); gradient.frame = thumb.bounds }

    private func build() {
        contentView.backgroundColor    = cardBg
        contentView.layer.cornerRadius = 10
        contentView.clipsToBounds      = true
        contentView.layer.borderWidth  = 1
        contentView.layer.borderColor  = UIColor.white.withAlphaComponent(0.07).cgColor
        layer.shadowColor   = UIColor.black.cgColor
        layer.shadowOpacity = 0.5
        layer.shadowRadius  = 8
        layer.shadowOffset  = CGSize(width: 0, height: 4)
        layer.masksToBounds = false

        thumb.backgroundColor = thumbBg
        thumb.clipsToBounds = true
        thumb.translatesAutoresizingMaskIntoConstraints = false
        thumbImg.contentMode = .scaleAspectFill; thumbImg.clipsToBounds = true
        thumbImg.translatesAutoresizingMaskIntoConstraints = false
        let cfg = UIImage.SymbolConfiguration(pointSize: 24, weight: .thin)
        thumbIcon.image = UIImage(systemName: "camera.fill", withConfiguration: cfg)
        thumbIcon.tintColor = UIColor.white.withAlphaComponent(0.13)
        thumbIcon.contentMode = .scaleAspectFit
        thumbIcon.translatesAutoresizingMaskIntoConstraints = false
        gradient.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.6).cgColor]
        gradient.locations = [0.3, 1.0]
        thumb.layer.addSublayer(gradient)
        overlay.backgroundColor = .clear
        overlay.translatesAutoresizingMaskIntoConstraints = false
        thumb.addSubview(thumbImg); thumb.addSubview(thumbIcon); thumb.addSubview(overlay)
        contentView.addSubview(thumb)

        badge.backgroundColor = appRed; badge.layer.cornerRadius = 10
        badge.clipsToBounds = true; badge.translatesAutoresizingMaskIntoConstraints = false
        badgeLbl.font = .systemFont(ofSize: 11, weight: .black); badgeLbl.textColor = .white
        badgeLbl.textAlignment = .center; badgeLbl.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(badgeLbl); contentView.addSubview(badge)

        infoRow.backgroundColor = infoBg; infoRow.translatesAutoresizingMaskIntoConstraints = false
        shotLbl.font = .systemFont(ofSize: 13, weight: .bold); shotLbl.textColor = .white
        shotLbl.translatesAutoresizingMaskIntoConstraints = false
        camLbl.font = .systemFont(ofSize: 11, weight: .medium)
        camLbl.textColor = UIColor.white.withAlphaComponent(0.6)
        camLbl.translatesAutoresizingMaskIntoConstraints = false
        sceneLbl.font = .systemFont(ofSize: 10, weight: .regular)
        sceneLbl.textColor = UIColor.white.withAlphaComponent(0.3)
        sceneLbl.translatesAutoresizingMaskIntoConstraints = false
        durLbl.font = .monospacedDigitSystemFont(ofSize: 12, weight: .bold)
        durLbl.textColor = appRed; durLbl.translatesAutoresizingMaskIntoConstraints = false
        infoRow.addSubview(shotLbl); infoRow.addSubview(camLbl)
        infoRow.addSubview(sceneLbl); infoRow.addSubview(durLbl)
        contentView.addSubview(infoRow)

        NSLayoutConstraint.activate([
            thumb.topAnchor.constraint(equalTo: contentView.topAnchor),
            thumb.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thumb.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            thumb.heightAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 9.0/16.0),

            thumbImg.topAnchor.constraint(equalTo: thumb.topAnchor),
            thumbImg.leadingAnchor.constraint(equalTo: thumb.leadingAnchor),
            thumbImg.trailingAnchor.constraint(equalTo: thumb.trailingAnchor),
            thumbImg.bottomAnchor.constraint(equalTo: thumb.bottomAnchor),

            thumbIcon.centerXAnchor.constraint(equalTo: thumb.centerXAnchor),
            thumbIcon.centerYAnchor.constraint(equalTo: thumb.centerYAnchor),

            overlay.topAnchor.constraint(equalTo: thumb.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: thumb.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: thumb.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: thumb.bottomAnchor),

            badge.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 7),
            badge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -7),
            badge.widthAnchor.constraint(greaterThanOrEqualToConstant: 26),
            badge.heightAnchor.constraint(equalToConstant: 20),
            badgeLbl.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            badgeLbl.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            badgeLbl.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: 6),
            badgeLbl.trailingAnchor.constraint(equalTo: badge.trailingAnchor, constant: -6),

            infoRow.topAnchor.constraint(equalTo: thumb.bottomAnchor),
            infoRow.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            infoRow.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            infoRow.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            shotLbl.topAnchor.constraint(equalTo: infoRow.topAnchor, constant: 8),
            shotLbl.leadingAnchor.constraint(equalTo: infoRow.leadingAnchor, constant: 10),
            shotLbl.trailingAnchor.constraint(lessThanOrEqualTo: durLbl.leadingAnchor, constant: -4),

            camLbl.topAnchor.constraint(equalTo: shotLbl.bottomAnchor, constant: 2),
            camLbl.leadingAnchor.constraint(equalTo: infoRow.leadingAnchor, constant: 10),
            camLbl.trailingAnchor.constraint(lessThanOrEqualTo: infoRow.trailingAnchor, constant: -10),

            sceneLbl.topAnchor.constraint(equalTo: camLbl.bottomAnchor, constant: 1),
            sceneLbl.leadingAnchor.constraint(equalTo: infoRow.leadingAnchor, constant: 10),
            sceneLbl.bottomAnchor.constraint(lessThanOrEqualTo: infoRow.bottomAnchor, constant: -8),

            durLbl.trailingAnchor.constraint(equalTo: infoRow.trailingAnchor, constant: -10),
            durLbl.topAnchor.constraint(equalTo: infoRow.topAnchor, constant: 10),
        ])
    }

    func configure(with shot: Shot, sceneName: String) {
        badgeLbl.text = shot.shortLabel; shotLbl.text = shot.displayName
        camLbl.text = shot.cleanCameraName; sceneLbl.text = sceneName
        let s = shot.duration
        durLbl.text = s.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(s))s" : String(format: "%.1fs", s)
        if let img = shot.thumbnail {
            thumbImg.image = img; thumbIcon.isHidden = true
        } else { thumbImg.image = nil; thumbIcon.isHidden = false }
    }

    override func touchesBegan(_ t: Set<UITouch>, with e: UIEvent?) {
        super.touchesBegan(t, with: e)
        UIView.animate(withDuration: 0.1) {
            self.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
            self.overlay.backgroundColor = UIColor.black.withAlphaComponent(0.25) }
    }
    override func touchesEnded(_ t: Set<UITouch>, with e: UIEvent?) {
        super.touchesEnded(t, with: e)
        UIView.animate(withDuration: 0.15) { self.transform = .identity; self.overlay.backgroundColor = .clear }
    }
    override func touchesCancelled(_ t: Set<UITouch>, with e: UIEvent?) {
        super.touchesCancelled(t, with: e)
        UIView.animate(withDuration: 0.15) { self.transform = .identity; self.overlay.backgroundColor = .clear }
    }
}
