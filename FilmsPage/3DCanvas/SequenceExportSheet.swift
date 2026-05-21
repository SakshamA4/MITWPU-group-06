//
//  SequenceExportSheet.swift
//  FilmsPage
//
//  Half-sheet for sequence export confirmation and settings.
//  Shows sequence name, scene list, and resolution/FPS pickers.
//

import UIKit

final class SequenceExportSheet: UIViewController {

    // MARK: - Palette (matches ExportSettingsSheet)

    private let bgColor   = UIColor(red: 0.055, green: 0.055, blue: 0.100, alpha: 1)
    private let cardColor = UIColor(red: 0.086, green: 0.086, blue: 0.141, alpha: 1)
    private let accentRed = UIColor(red: 0.694, green: 0.125, blue: 0.224, alpha: 1)
    private let dimText   = UIColor(white: 1, alpha: 0.40)
    private let sepColor  = UIColor(white: 1, alpha: 0.06)

    // MARK: - Data

    let sequenceName: String
    let scenes: [ScenesModel]

    // MARK: - State

    private var settings = ExportSettings()

    // MARK: - Callback

    var onExport: ((ExportSettings) -> Void)?

    // MARK: - Init

    init(sequenceName: String, scenes: [ScenesModel]) {
        self.sequenceName = sequenceName
        self.scenes = scenes
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - UI Elements

    private lazy var titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Export Sequence"
        l.font = .systemFont(ofSize: 18, weight: .bold)
        l.textColor = .white
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var sequenceNameLabel: UILabel = {
        let l = UILabel()
        l.text = sequenceName
        l.font = .systemFont(ofSize: 14, weight: .semibold)
        l.textColor = accentRed
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var sceneListLabel: UILabel = {
        let l = UILabel()
        l.numberOfLines = 0
        l.font = .systemFont(ofSize: 12, weight: .regular)
        l.textColor = UIColor(white: 1, alpha: 0.65)
        l.translatesAutoresizingMaskIntoConstraints = false

        let lines = scenes.enumerated().map { (i, s) in "\(i + 1). \(s.name)" }
        l.text = lines.joined(separator: "\n")
        return l
    }()

    private lazy var sceneCountLabel: UILabel = {
        let l = UILabel()
        l.text = "\(scenes.count) scene(s)"
        l.font = .systemFont(ofSize: 11, weight: .medium)
        l.textColor = dimText
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var resolutionSeg: UISegmentedControl = makeSegmented(
        items: ExportSettings.Resolution.allCases.map(\.rawValue),
        defaultIndex: 1
    )

    private lazy var fpsSeg: UISegmentedControl = makeSegmented(
        items: ExportSettings.FPS.allCases.map(\.label),
        defaultIndex: 0
    )

    private lazy var exportButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Export Sequence"
        config.image = UIImage(systemName: "film.stack")
        config.imagePadding = 8
        config.baseBackgroundColor = accentRed
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 32, bottom: 14, trailing: 32)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var a = attrs; a.font = .systemFont(ofSize: 16, weight: .semibold); return a
        }
        let btn = UIButton(configuration: config)
        btn.addTarget(self, action: #selector(exportTapped), for: .touchUpInside)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = bgColor
        buildLayout()
    }

    // MARK: - Layout

    private func buildLayout() {
        // Scene list card
        let sceneCard = UIView()
        sceneCard.backgroundColor = cardColor
        sceneCard.layer.cornerRadius = 14
        sceneCard.clipsToBounds = true
        sceneCard.translatesAutoresizingMaskIntoConstraints = false

        let scenesHeader = UILabel()
        scenesHeader.text = "SCENES IN ORDER"
        scenesHeader.font = .systemFont(ofSize: 10, weight: .black)
        scenesHeader.textColor = dimText
        let attrs: [NSAttributedString.Key: Any] = [
            .kern: 1.6,
            .font: scenesHeader.font as Any,
            .foregroundColor: dimText
        ]
        scenesHeader.attributedText = NSAttributedString(string: "SCENES IN ORDER", attributes: attrs)
        scenesHeader.translatesAutoresizingMaskIntoConstraints = false

        sceneCard.addSubview(scenesHeader)
        sceneCard.addSubview(sceneListLabel)

        NSLayoutConstraint.activate([
            scenesHeader.topAnchor.constraint(equalTo: sceneCard.topAnchor, constant: 14),
            scenesHeader.leadingAnchor.constraint(equalTo: sceneCard.leadingAnchor, constant: 16),

            sceneListLabel.topAnchor.constraint(equalTo: scenesHeader.bottomAnchor, constant: 8),
            sceneListLabel.leadingAnchor.constraint(equalTo: sceneCard.leadingAnchor, constant: 16),
            sceneListLabel.trailingAnchor.constraint(equalTo: sceneCard.trailingAnchor, constant: -16),
            sceneListLabel.bottomAnchor.constraint(equalTo: sceneCard.bottomAnchor, constant: -14)
        ])

        // Settings card
        let resRow = makeRow(label: "RESOLUTION", control: resolutionSeg)
        let fpsRow = makeRow(label: "FRAME RATE", control: fpsSeg)

        let settingsStack = UIStackView(arrangedSubviews: [resRow, makeSep(), fpsRow])
        settingsStack.axis = .vertical
        settingsStack.spacing = 0
        settingsStack.backgroundColor = cardColor
        settingsStack.layer.cornerRadius = 14
        settingsStack.clipsToBounds = true
        settingsStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(titleLabel)
        view.addSubview(sequenceNameLabel)
        view.addSubview(sceneCountLabel)
        view.addSubview(sceneCard)
        view.addSubview(settingsStack)
        view.addSubview(exportButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 28),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            sequenceNameLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            sequenceNameLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            sceneCountLabel.topAnchor.constraint(equalTo: sequenceNameLabel.bottomAnchor, constant: 2),
            sceneCountLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            sceneCard.topAnchor.constraint(equalTo: sceneCountLabel.bottomAnchor, constant: 20),
            sceneCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            sceneCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            settingsStack.topAnchor.constraint(equalTo: sceneCard.bottomAnchor, constant: 20),
            settingsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            settingsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            exportButton.topAnchor.constraint(equalTo: settingsStack.bottomAnchor, constant: 28),
            exportButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            exportButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 200)
        ])
    }

    // MARK: - Helpers

    private func makeSegmented(items: [String], defaultIndex: Int) -> UISegmentedControl {
        let seg = UISegmentedControl(items: items)
        seg.selectedSegmentIndex = defaultIndex
        seg.backgroundColor = UIColor(white: 1, alpha: 0.06)
        seg.selectedSegmentTintColor = accentRed
        seg.setTitleTextAttributes([
            .foregroundColor: UIColor.white.withAlphaComponent(0.50),
            .font: UIFont.systemFont(ofSize: 13, weight: .medium)
        ], for: .normal)
        seg.setTitleTextAttributes([
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold)
        ], for: .selected)
        seg.translatesAutoresizingMaskIntoConstraints = false
        return seg
    }

    private func makeRow(label text: String, control: UIControl) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 10, weight: .black)
        lbl.textColor = dimText
        let attrs: [NSAttributedString.Key: Any] = [
            .kern: 1.6,
            .font: lbl.font as Any,
            .foregroundColor: dimText
        ]
        lbl.attributedText = NSAttributedString(string: text, attributes: attrs)
        lbl.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(lbl)
        container.addSubview(control)

        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: 64),

            lbl.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            lbl.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            lbl.widthAnchor.constraint(equalToConstant: 90),

            control.leadingAnchor.constraint(equalTo: lbl.trailingAnchor, constant: 12),
            control.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            control.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            control.heightAnchor.constraint(equalToConstant: 32)
        ])

        return container
    }

    private func makeSep() -> UIView {
        let v = UIView()
        v.backgroundColor = sepColor
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return v
    }

    // MARK: - Actions

    @objc private func exportTapped() {
        let haptic = UIImpactFeedbackGenerator(style: .medium)
        haptic.impactOccurred()

        let resIdx = resolutionSeg.selectedSegmentIndex
        settings.resolution = ExportSettings.Resolution.allCases[resIdx]

        let fpsIdx = fpsSeg.selectedSegmentIndex
        settings.fps = ExportSettings.FPS.allCases[fpsIdx]

        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.onExport?(self.settings)
        }
    }
}
