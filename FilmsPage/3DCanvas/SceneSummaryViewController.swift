//
//  SceneSummaryViewController.swift
//  FilmsPage
//
//  A lightweight, dark-themed summary modal for the active 3D scene.
//  Reads live entity data directly from the CanvasViewController's scene graph,
//  so it always reflects the current state — no file I/O needed.
//

import UIKit
import RealityKit

// MARK: - Row Model

struct SummaryRow {
    let icon: String
    let title: String
    let detail: String
    var highlight: Bool = false
}

// MARK: - SceneSummaryViewController

final class SceneSummaryViewController: UIViewController {

    // MARK: - Input
    /// Populated by the presenter before showing.
    var sceneName: String     = "Scene"
    var sequenceName: String? = nil
    var filmName: String?     = nil
    var rows: [SummaryRow]    = []

    // MARK: - UI
    private let grabber       = UIView()
    private let titleLabel    = UILabel()
    private let subtitleLabel = UILabel()
    private let accentBar     = UIView()
    private let tableView     = UITableView(frame: .zero, style: .plain)
    private let emptyLabel    = UILabel()

    private let accentColor = UIColor(red: 100/255, green: 180/255, blue: 255/255, alpha: 1)
    private let bgColor     = UIColor(red: 10/255, green: 12/255, blue: 22/255, alpha: 1)
    private let cellBg      = UIColor(red: 18/255, green: 21/255, blue: 38/255, alpha: 1)
    private let cellId      = "SceneSummaryCell"

    // MARK: - Factory

    /// Builds the summary rows by reading live entity data from the canvas.
    static func makeRows(from vc: CanvasViewController) -> [SummaryRow] {
        guard let anchor = vc.mainAnchor else { return [] }

        var propCount     = 0
        var charCount     = 0
        var lightNames    = [String]()
        var cameraDetails = [String]()
        var bgCount       = 0
        var wallCount     = 0
        var skyName: String? = nil

        // Clip stats
        let clips      = vc.timeline.clips
        let clipCount  = clips.count
        var animatedEntities = Set<String>()
        clips.forEach { animatedEntities.insert($0.entityName) }

        for child in anchor.children {
            let name = child.name
            guard !name.isEmpty,
                  !name.hasPrefix("PathRoot_"),
                  !name.hasPrefix("RotationArc_"),
                  !name.hasPrefix("ProceduralSky"),
                  !["Grid","EditorCamera","MainAnchor","GizmoRoot","MotionPath"].contains(name)
            else { continue }

            if let cat = child.components[CategoryComponent.self] {
                switch cat.toolType {
                case .prop:       propCount += 1
                case .character:  charCount += 1
                case .background: bgCount   += 1
                case .wall:       wallCount  += 1
                case .sky:
                    skyName = name.hasPrefix("ProceduralSky_")
                        ? formatSkyName(String(name.dropFirst("ProceduralSky_".count)))
                        : "Custom Sky"

                case .light:
                    if let cfg = child.components[LightConfigComponent.self] {
                        lightNames.append(describeLightConfig(cfg))
                    } else {
                        lightNames.append("Light")
                    }

                case .camera:
                    var desc = "Camera"
                    if let aspect = child.components[CameraAspectComponent.self] {
                        desc += " (\(aspect.aspectRatio.rawValue))"
                    }
                    if let focus = child.components[CameraFocusComponent.self] {
                        desc += " \(Int(focus.focalLengthMM))mm"
                    }
                    cameraDetails.append(desc)
                }
            }
        }

        // Sky from ProceduralSky entity if not found via CategoryComponent
        if skyName == nil {
            for child in anchor.children where child.name.hasPrefix("ProceduralSky_") {
                skyName = formatSkyName(String(child.name.dropFirst("ProceduralSky_".count)))
                break
            }
        }

        var rows = [SummaryRow]()

        rows.append(SummaryRow(
            icon: "cube.fill",
            title: "Props",
            detail: propCount == 0 ? "None" : "\(propCount)",
            highlight: propCount > 0
        ))

        rows.append(SummaryRow(
            icon: "figure.stand",
            title: "Characters",
            detail: charCount == 0 ? "None" : "\(charCount)",
            highlight: charCount > 0
        ))

        rows.append(SummaryRow(
            icon: "timeline.selection",
            title: "Animation Clips",
            detail: clipCount == 0 ? "None" : "\(clipCount) clip(s) on \(animatedEntities.count) object(s)",
            highlight: clipCount > 0
        ))

        rows.append(SummaryRow(
            icon: "lightbulb.fill",
            title: "Lights",
            detail: lightNames.isEmpty ? "None" : lightNames.joined(separator: "\n"),
            highlight: !lightNames.isEmpty
        ))

        rows.append(SummaryRow(
            icon: "camera.fill",
            title: "Cameras",
            detail: cameraDetails.isEmpty ? "None" : cameraDetails.joined(separator: "\n"),
            highlight: !cameraDetails.isEmpty
        ))

        rows.append(SummaryRow(
            icon: "photo.fill",
            title: "Backgrounds",
            detail: bgCount == 0 ? "None" : "\(bgCount) background(s)"
        ))

        rows.append(SummaryRow(
            icon: "square.split.2x2",
            title: "Set Elements",
            detail: wallCount == 0 ? "None" : "\(wallCount) wall / ground element(s)"
        ))

        rows.append(SummaryRow(
            icon: "cloud.sun.fill",
            title: "Sky Setting",
            detail: skyName ?? "None (default)"
        ))

        return rows
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = bgColor
        setupGrabber()
        setupHeader()
        setupTable()
    }

    // MARK: - Setup

    private func setupGrabber() {
        grabber.backgroundColor = UIColor(white: 0.4, alpha: 1)
        grabber.layer.cornerRadius = 2.5
        grabber.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(grabber)
        NSLayoutConstraint.activate([
            grabber.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            grabber.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            grabber.widthAnchor.constraint(equalToConstant: 36),
            grabber.heightAnchor.constraint(equalToConstant: 5),
        ])
    }

    private func setupHeader() {
        // Accent stripe
        accentBar.backgroundColor = accentColor
        accentBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(accentBar)

        // Scene title
        titleLabel.text = sceneName
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // Subtitle: Sequence / Film
        var sub = "SCENE SUMMARY"
        if let seq = sequenceName { sub = seq.uppercased() + " › " + sub }
        if let film = filmName    { sub = film.uppercased() + " › " + sub }
        subtitleLabel.text = sub
        subtitleLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        subtitleLabel.textColor = accentColor
        subtitleLabel.numberOfLines = 1
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)

        // Close button
        let cfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        let closeBtn = UIButton(type: .system)
        closeBtn.setImage(UIImage(systemName: "xmark", withConfiguration: cfg), for: .normal)
        closeBtn.tintColor = UIColor(white: 0.7, alpha: 1)
        closeBtn.backgroundColor = UIColor(white: 1, alpha: 0.08)
        closeBtn.layer.cornerRadius = 16
        closeBtn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeBtn)

        // Separator
        let sep = UIView()
        sep.backgroundColor = UIColor(white: 1, alpha: 0.07)
        sep.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sep)

        NSLayoutConstraint.activate([
            accentBar.topAnchor.constraint(equalTo: grabber.bottomAnchor, constant: 12),
            accentBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            accentBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            accentBar.heightAnchor.constraint(equalToConstant: 3),

            titleLabel.topAnchor.constraint(equalTo: accentBar.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: closeBtn.leadingAnchor, constant: -10),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),

            closeBtn.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeBtn.widthAnchor.constraint(equalToConstant: 32),
            closeBtn.heightAnchor.constraint(equalToConstant: 32),

            sep.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
            sep.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sep.heightAnchor.constraint(equalToConstant: 1),
        ])

        // Store ref to separator for table anchor
        sep.tag = 9901
    }

    private func setupTable() {
        tableView.backgroundColor = .clear
        tableView.separatorColor = UIColor(white: 1, alpha: 0.07)
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 52, bottom: 0, right: 0)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 56
        tableView.register(SceneSummaryCell.self, forCellReuseIdentifier: cellId)
        tableView.dataSource = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        let sep = view.viewWithTag(9901)!
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: sep.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    // MARK: - Static Helpers

    private static func describeLightConfig(_ cfg: LightConfigComponent) -> String {
        var name: String
        if let proc = cfg.proceduralKind {
            switch proc {
            case .practicalLantern: name = "Practical Lantern"
            case .fluorescentTube:  name = "Fluorescent Tube"
            case .skyPanel:         name = "Sky Panel"
            }
        } else {
            switch cfg.lightKind {
            case .spot:  name = "Spotlight"
            case .panel: name = "LED Panel"
            case .point: name = "Point Light"
            }
        }
        let k  = Int(cfg.colorTemperatureKelvin)
        let lm = cfg.intensity >= 1000
            ? String(format: "%.0fK lm", cfg.intensity / 1000)
            : String(format: "%.0f lm", cfg.intensity)
        return "\(name) — \(k)K  \(lm)"
    }

    private static func formatSkyName(_ raw: String) -> String {
        switch raw {
        case "Blue_sky":     return "Blue Sky (Daytime)"
        case "Nighty_night": return "Starry Night"
        case "Evening_sky":  return "Evening Hue"
        case "sky_day":      return "Daylight Sky"
        case "sky_sunset":   return "Sunset Sky"
        case "sky_night":    return "Midnight Sky"
        default:             return raw.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

// MARK: - UITableViewDataSource

extension SceneSummaryViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath) as! SceneSummaryCell
        cell.configure(with: rows[indexPath.row], accentColor: accentColor, bgColor: cellBg)
        return cell
    }
}

// MARK: - SceneSummaryCell

final class SceneSummaryCell: UITableViewCell {

    private let iconView   = UIImageView()
    private let titleLbl   = UILabel()
    private let detailLbl  = UILabel()
    private let dot        = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none

        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .white
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)

        dot.layer.cornerRadius = 4
        dot.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(dot)

        titleLbl.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLbl.textColor = UIColor(white: 0.7, alpha: 1)
        titleLbl.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLbl)

        detailLbl.font = .systemFont(ofSize: 15, weight: .medium)
        detailLbl.textColor = .white
        detailLbl.numberOfLines = 0
        detailLbl.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(detailLbl)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),

            dot.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 10),
            dot.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),

            titleLbl.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLbl.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 10),
            titleLbl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            detailLbl.topAnchor.constraint(equalTo: titleLbl.bottomAnchor, constant: 3),
            detailLbl.leadingAnchor.constraint(equalTo: titleLbl.leadingAnchor),
            detailLbl.trailingAnchor.constraint(equalTo: titleLbl.trailingAnchor),
            detailLbl.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with row: SummaryRow, accentColor: UIColor, bgColor: UIColor) {
        backgroundColor = bgColor
        contentView.backgroundColor = bgColor
        iconView.image = UIImage(systemName: row.icon)
        iconView.tintColor = row.highlight ? accentColor : UIColor(white: 0.5, alpha: 1)
        titleLbl.text = row.title
        detailLbl.text = row.detail
        dot.backgroundColor = row.highlight ? accentColor : UIColor(white: 0.25, alpha: 1)
    }
}
