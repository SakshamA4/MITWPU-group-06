//
//  ShotBreakdownViewController.swift
//  3DCanvas
//

import UIKit

// MARK: - Shot Model

struct Shot {
    let id: UUID
    let index: Int
    let cameraName: String
    let startTime: Float
    let duration: Float
    let thumbnail: UIImage?

    var displayName: String { "Shot \(index + 1)" }
    var shortLabel: String  { "\(index + 1)" }
    var endTime: Float      { startTime + duration }
}

// MARK: - Shot Derivation Engine

struct ShotDerived {

    /// Scans the Timeline for AnimationClips that animate scene cameras.
    /// Each distinct camera-active interval becomes one Shot.
    /// If no camera clips exist, the whole timeline is Shot 1 on the editor camera.
    static func derive(from timeline: Timeline, cameraNames: [String]) -> [Shot] {

        let totalDuration = timeline.duration
        guard totalDuration > 0 else { return [] }

        // Step A — find all clips that belong to a scene camera
        let cameraClips = timeline.clips.filter { clip in
            cameraNames.contains(clip.entityName) ||
            clip.entityName.lowercased().contains("scenecamera") ||
            clip.entityName.lowercased().contains("camera")
        }

        // Step B — if none, whole scene = 1 shot
        if cameraClips.isEmpty {
            return [Shot(id: UUID(), index: 0, cameraName: "Editor Camera",
                         startTime: 0, duration: totalDuration, thumbnail: nil)]
        }

        // Step C — group by camera, merge overlapping intervals
        var intervals: [(cam: String, start: Float, end: Float)] = []
        let grouped = Dictionary(grouping: cameraClips, by: { $0.entityName })

        for (camName, clips) in grouped {
            let sorted = clips.sorted { $0.startTime < $1.startTime }
            var merging: (start: Float, end: Float)? = nil

            for clip in sorted {
                let s = clip.startTime
                let e = clip.startTime + clip.duration
                if var m = merging {
                    if s <= m.end + 0.01 {
                        m.end = max(m.end, e)
                        merging = m
                    } else {
                        intervals.append((camName, m.start, m.end))
                        merging = (s, e)
                    }
                } else {
                    merging = (s, e)
                }
            }
            if let m = merging { intervals.append((camName, m.start, m.end)) }
        }

        // Step D — sort by start time → each interval = 1 Shot
        intervals.sort { $0.start < $1.start }

        return intervals.enumerated().map { (i, interval) in
            Shot(id: UUID(), index: i, cameraName: interval.cam,
                 startTime: interval.start,
                 duration: max(0.1, interval.end - interval.start),
                 thumbnail: nil)
        }
    }
}

// MARK: - ShotBreakdownViewController

class ShotBreakdownViewController: UIViewController {

    // App color constants (match entire app)
    static let navy   = UIColor(red: 11/255,  green: 11/255,  blue: 22/255,  alpha: 1)
    static let card   = UIColor(red: 22/255,  green: 22/255,  blue: 38/255,  alpha: 1)
    static let red    = UIColor(red: 177/255, green: 32/255,  blue: 57/255,  alpha: 1)
    static let gray   = UIColor.lightGray

    // MARK: - Public
    var sceneName: String  = "Scene S01"
    var timeline: Timeline = Timeline()
    var cameraNames: [String] = []

    // MARK: - Private
    private var shots: [Shot] = []

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection       = .vertical
        layout.minimumLineSpacing    = 12
        layout.minimumInteritemSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 12, left: 16, bottom: 40, right: 16)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.register(ShotCardCell.self, forCellWithReuseIdentifier: ShotCardCell.reuseID)
        cv.dataSource = self
        cv.delegate   = self
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    private let statsLabel: UILabel = {
        let l = UILabel()
        l.font      = .systemFont(ofSize: 11, weight: .black)
        l.textColor = UIColor.white.withAlphaComponent(0.3)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let emptyLabel: UILabel = {
        let l = UILabel()
        l.text          = "No shots detected.\nAdd scene cameras and animate them\nto generate a shot breakdown."
        l.numberOfLines = 0
        l.textAlignment = .center
        l.font          = .systemFont(ofSize: 14)
        l.textColor     = UIColor.lightGray
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Self.navy
        shots = ShotDerived.derive(from: timeline, cameraNames: cameraNames)
        setupNav()
        setupLayout()
        refresh()
    }

    private func setupNav() {
        title = sceneName
        let app = UINavigationBarAppearance()
        app.configureWithOpaqueBackground()
        app.backgroundColor = Self.navy
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

        let playBtn = UIBarButtonItem(
            title: "▶  Play All", style: .plain,
            target: self, action: #selector(playAllTapped))
        playBtn.setTitleTextAttributes([
            .foregroundColor: Self.red,
            .font: UIFont.systemFont(ofSize: 15, weight: .semibold)
        ], for: .normal)
        navigationItem.rightBarButtonItem = playBtn
    }

    private func setupLayout() {
        view.addSubview(statsLabel)
        view.addSubview(collectionView)
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            statsLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            statsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),

            collectionView.topAnchor.constraint(equalTo: statsLabel.bottomAnchor, constant: 2),
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
        let empty = shots.isEmpty
        emptyLabel.isHidden   = !empty
        collectionView.isHidden = empty
        navigationItem.rightBarButtonItem?.isEnabled = !empty

        let total = shots.reduce(0) { $0 + $1.duration }
        let m = Int(total) / 60, s = Int(total) % 60
        statsLabel.text = "\(shots.count) SHOTS  ·  \(m > 0 ? "\(m)m " : "")\(s)s"
        collectionView.reloadData()
    }

    @objc private func backTapped()    { navigationController?.popViewController(animated: true) }

    @objc private func playAllTapped() {
        guard !shots.isEmpty else { return }
        push(ShotPlayerViewController(shots: shots, startIndex: 0, playAll: true, sceneName: sceneName))
    }

    private func push(_ vc: UIViewController) {
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - Collection DataSource + Delegate

extension ShotBreakdownViewController: UICollectionViewDataSource,
                                        UICollectionViewDelegate,
                                        UICollectionViewDelegateFlowLayout {

    func collectionView(_ cv: UICollectionView, numberOfItemsInSection _: Int) -> Int { shots.count }

    func collectionView(_ cv: UICollectionView, cellForItemAt ip: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: ShotCardCell.reuseID, for: ip) as! ShotCardCell
        cell.configure(with: shots[ip.item])
        return cell
    }

    func collectionView(_ cv: UICollectionView, didSelectItemAt ip: IndexPath) {
        push(ShotPlayerViewController(shots: shots, startIndex: ip.item, playAll: false, sceneName: sceneName))
    }

    func collectionView(_ cv: UICollectionView, layout _: UICollectionViewLayout,
                        sizeForItemAt _: IndexPath) -> CGSize {
        let spacing: CGFloat = 12, inset: CGFloat = 16
        let w = floor((cv.bounds.width - inset * 2 - spacing * 2) / 3)
        return CGSize(width: w, height: w * (9/16) + 50)
    }
}

// MARK: - Shot Card Cell

class ShotCardCell: UICollectionViewCell {
    static let reuseID = "ShotCardCell"

    private let appRed  = UIColor(red: 177/255, green: 32/255, blue: 57/255, alpha: 1)
    private let cardBg  = UIColor(red: 22/255,  green: 22/255, blue: 38/255, alpha: 1)
    private let thumbBg = UIColor(red: 14/255,  green: 14/255, blue: 26/255, alpha: 1)

    private let badge     = UIView()
    private let badgeLbl  = UILabel()
    private let thumb     = UIView()
    private let thumbImg  = UIImageView()
    private let thumbIcon = UIImageView()
    private let shotLbl   = UILabel()
    private let camLbl    = UILabel()
    private let durLbl    = UILabel()
    private let overlay   = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        contentView.backgroundColor        = cardBg
        contentView.layer.cornerRadius     = 9
        contentView.clipsToBounds          = true
        contentView.layer.borderWidth      = 1
        contentView.layer.borderColor      = UIColor.white.withAlphaComponent(0.06).cgColor
        layer.shadowColor                  = UIColor.black.cgColor
        layer.shadowOpacity                = 0.4
        layer.shadowRadius                 = 5
        layer.shadowOffset                 = CGSize(width: 0, height: 3)
        layer.masksToBounds                = false

        // Thumb
        thumb.backgroundColor = thumbBg
        thumb.clipsToBounds   = true
        thumb.translatesAutoresizingMaskIntoConstraints = false
        thumbImg.contentMode  = .scaleAspectFill
        thumbImg.clipsToBounds = true
        thumbImg.translatesAutoresizingMaskIntoConstraints = false
        let cfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .thin)
        thumbIcon.image       = UIImage(systemName: "camera.fill", withConfiguration: cfg)
        thumbIcon.tintColor   = UIColor.white.withAlphaComponent(0.12)
        thumbIcon.contentMode = .scaleAspectFit
        thumbIcon.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = .clear
        overlay.translatesAutoresizingMaskIntoConstraints = false
        thumb.addSubview(thumbImg)
        thumb.addSubview(thumbIcon)
        thumb.addSubview(overlay)
        contentView.addSubview(thumb)

        // Badge
        badge.backgroundColor   = appRed
        badge.layer.cornerRadius = 9
        badge.clipsToBounds      = true
        badge.translatesAutoresizingMaskIntoConstraints = false
        badgeLbl.font            = .systemFont(ofSize: 9, weight: .black)
        badgeLbl.textColor       = .white
        badgeLbl.textAlignment   = .center
        badgeLbl.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(badgeLbl)
        contentView.addSubview(badge)

        // Labels
        shotLbl.font      = .systemFont(ofSize: 11, weight: .semibold)
        shotLbl.textColor = .white
        shotLbl.translatesAutoresizingMaskIntoConstraints = false

        camLbl.font       = .systemFont(ofSize: 9, weight: .regular)
        camLbl.textColor  = UIColor.white.withAlphaComponent(0.4)
        camLbl.translatesAutoresizingMaskIntoConstraints = false

        durLbl.font       = .monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
        durLbl.textColor  = UIColor.white.withAlphaComponent(0.4)
        durLbl.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(shotLbl)
        contentView.addSubview(camLbl)
        contentView.addSubview(durLbl)

        NSLayoutConstraint.activate([
            thumb.topAnchor.constraint(equalTo: contentView.topAnchor),
            thumb.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thumb.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            thumb.heightAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 9/16),

            thumbImg.topAnchor.constraint(equalTo: thumb.topAnchor),
            thumbImg.leadingAnchor.constraint(equalTo: thumb.leadingAnchor),
            thumbImg.trailingAnchor.constraint(equalTo: thumb.trailingAnchor),
            thumbImg.bottomAnchor.constraint(equalTo: thumb.bottomAnchor),

            thumbIcon.centerXAnchor.constraint(equalTo: thumb.centerXAnchor),
            thumbIcon.centerYAnchor.constraint(equalTo: thumb.centerYAnchor),
            thumbIcon.widthAnchor.constraint(equalToConstant: 24),
            thumbIcon.heightAnchor.constraint(equalToConstant: 24),

            overlay.topAnchor.constraint(equalTo: thumb.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: thumb.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: thumb.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: thumb.bottomAnchor),

            badge.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            badge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            badge.widthAnchor.constraint(greaterThanOrEqualToConstant: 20),
            badge.heightAnchor.constraint(equalToConstant: 17),

            badgeLbl.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            badgeLbl.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            badgeLbl.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: 4),
            badgeLbl.trailingAnchor.constraint(equalTo: badge.trailingAnchor, constant: -4),

            shotLbl.topAnchor.constraint(equalTo: thumb.bottomAnchor, constant: 5),
            shotLbl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 6),
            shotLbl.trailingAnchor.constraint(lessThanOrEqualTo: durLbl.leadingAnchor, constant: -2),

            camLbl.topAnchor.constraint(equalTo: shotLbl.bottomAnchor, constant: 1),
            camLbl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 6),
            camLbl.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -6),

            durLbl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            durLbl.centerYAnchor.constraint(equalTo: shotLbl.centerYAnchor),
        ])
    }

    func configure(with shot: Shot) {
        badgeLbl.text = shot.shortLabel
        shotLbl.text  = shot.displayName
        camLbl.text   = shot.cameraName
            .replacingOccurrences(of: "SceneCamera_", with: "Cam ")
            .replacingOccurrences(of: "Camera_", with: "Cam ")
        let s = shot.duration
        durLbl.text = s.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(s))s" : String(format: "%.1fs", s)
        if let img = shot.thumbnail {
            thumbImg.image = img
            thumbIcon.isHidden = true
        } else {
            thumbImg.image = nil
            thumbIcon.isHidden = false
        }
    }

    override func touchesBegan(_ t: Set<UITouch>, with e: UIEvent?) {
        super.touchesBegan(t, with: e)
        UIView.animate(withDuration: 0.1) {
            self.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
            self.overlay.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        }
    }
    override func touchesEnded(_ t: Set<UITouch>, with e: UIEvent?) {
        super.touchesEnded(t, with: e)
        UIView.animate(withDuration: 0.15) {
            self.transform = .identity; self.overlay.backgroundColor = .clear
        }
    }
    override func touchesCancelled(_ t: Set<UITouch>, with e: UIEvent?) {
        super.touchesCancelled(t, with: e)
        UIView.animate(withDuration: 0.15) {
            self.transform = .identity; self.overlay.backgroundColor = .clear
        }
    }
}
