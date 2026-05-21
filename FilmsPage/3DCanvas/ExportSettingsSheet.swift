//
//  ExportSettingsSheet.swift
//  FilmsPage
//
//  Cinematic export settings sheet matching the app's dark palette.
//  Presented as a UIKit half-sheet with resolution, FPS, and quality pickers.
//

import UIKit

final class ExportSettingsSheet: UIViewController {

    // MARK: - Palette (matches ShotBreakdownViewController)

    private let bgColor   = UIColor(red: 0.055, green: 0.055, blue: 0.100, alpha: 1)
    private let cardColor = UIColor(red: 0.086, green: 0.086, blue: 0.141, alpha: 1)
    private let accentRed = UIColor(red: 0.694, green: 0.125, blue: 0.224, alpha: 1)
    private let dimText   = UIColor(white: 1, alpha: 0.40)
    private let sepColor  = UIColor(white: 1, alpha: 0.06)

    // MARK: - Mode

    enum Mode { case singleShot, allShots }
    let mode: Mode

    // MARK: - State

    private var settings = ExportSettings()

    // MARK: - Callback

    var onExport: ((ExportSettings) -> Void)?

    // MARK: - Init

    init(mode: Mode = .singleShot) {
        self.mode = mode
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - UI Elements

    private lazy var titleLabel: UILabel = {
        let l = UILabel()
        l.text = mode == .allShots ? "Export All Shots" : "Export Shot"
        l.font = .systemFont(ofSize: 18, weight: .bold)
        l.textColor = .white
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var subtitleLabel: UILabel = {
        let l = UILabel()
        l.text = "Choose export settings"
        l.font = .systemFont(ofSize: 12, weight: .medium)
        l.textColor = dimText
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var resolutionSeg: UISegmentedControl = makeSegmented(
        items: ExportSettings.Resolution.allCases.map(\.rawValue),
        defaultIndex: 1  // 1080p default
    )

    private lazy var fpsSeg: UISegmentedControl = makeSegmented(
        items: ExportSettings.FPS.allCases.map(\.label),
        defaultIndex: 0  // 24fps default
    )

    private lazy var qualitySeg: UISegmentedControl = makeSegmented(
        items: ExportSettings.Quality.allCases.map(\.rawValue),
        defaultIndex: 0  // High default
    )

    private lazy var exportButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Export"
        config.image = UIImage(systemName: "square.and.arrow.up")
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
        let resRow = makeRow(label: "RESOLUTION", control: resolutionSeg)
        let fpsRow = makeRow(label: "FRAME RATE", control: fpsSeg)
        let qualRow = makeRow(label: "QUALITY", control: qualitySeg)

        let stack = UIStackView(arrangedSubviews: [resRow, makeSep(), fpsRow, makeSep(), qualRow])
        stack.axis = .vertical
        stack.spacing = 0
        stack.backgroundColor = cardColor
        stack.layer.cornerRadius = 14
        stack.clipsToBounds = true
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(stack)
        view.addSubview(exportButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 28),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            stack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            exportButton.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 28),
            exportButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            exportButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 200)
        ])
    }

    // MARK: - Helpers

    private func makeSegmented(items: [String], defaultIndex: Int) -> UISegmentedControl {
        let seg = UISegmentedControl(items: items)
        seg.selectedSegmentIndex = defaultIndex

        // Dark tinted appearance
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
        lbl.text = text
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

        // Read settings from segmented controls
        let resIdx = resolutionSeg.selectedSegmentIndex
        settings.resolution = ExportSettings.Resolution.allCases[resIdx]

        let fpsIdx = fpsSeg.selectedSegmentIndex
        settings.fps = ExportSettings.FPS.allCases[fpsIdx]

        let qualIdx = qualitySeg.selectedSegmentIndex
        settings.quality = ExportSettings.Quality.allCases[qualIdx]

        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.onExport?(self.settings)
        }
    }
}
