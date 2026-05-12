//
//  ExportProgressOverlay.swift
//  FilmsPage
//
//  Full-screen cinematic export progress overlay with cancel support.
//  Designed to feel premium — thin progress bar, minimal text, blur backdrop.
//

import UIKit

final class ExportProgressOverlay: UIView {

    // MARK: - Palette

    private let accentRed = UIColor(red: 0.694, green: 0.125, blue: 0.224, alpha: 1)
    private let dimText   = UIColor(white: 1, alpha: 0.40)

    // MARK: - Callback

    var onCancel: (() -> Void)?

    // MARK: - UI

    private let blurView: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .dark)
        let v = UIVisualEffectView(effect: blur)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let cardView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0.075, green: 0.075, blue: 0.130, alpha: 0.95)
        v.layer.cornerRadius = 20
        v.layer.borderWidth = 1
        v.layer.borderColor = UIColor(white: 1, alpha: 0.06).cgColor
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "Exporting…"
        l.font = .systemFont(ofSize: 17, weight: .semibold)
        l.textColor = .white
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let shotLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12, weight: .medium)
        l.textColor = UIColor(white: 1, alpha: 0.55)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let frameLabel: UILabel = {
        let l = UILabel()
        l.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        l.textColor = UIColor(white: 1, alpha: 0.35)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var progressBar: UIProgressView = {
        let p = UIProgressView(progressViewStyle: .default)
        p.progressTintColor = accentRed
        p.trackTintColor = UIColor(white: 1, alpha: 0.08)
        p.layer.cornerRadius = 2
        p.clipsToBounds = true
        p.translatesAutoresizingMaskIntoConstraints = false
        return p
    }()

    private let percentLabel: UILabel = {
        let l = UILabel()
        l.font = .monospacedDigitSystemFont(ofSize: 28, weight: .light)
        l.textColor = UIColor(white: 1, alpha: 0.85)
        l.textAlignment = .center
        l.text = "0%"
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var cancelButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.title = "Cancel"
        config.baseForegroundColor = UIColor(white: 1, alpha: 0.55)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var a = attrs; a.font = .systemFont(ofSize: 14, weight: .medium); return a
        }
        let btn = UIButton(configuration: config)
        btn.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    // MARK: - State for ETA

    private var exportStartTime: CFTimeInterval = 0

    private let etaLabel: UILabel = {
        let l = UILabel()
        l.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        l.textColor = UIColor(white: 1, alpha: 0.30)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        build()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Build

    private func build() {
        translatesAutoresizingMaskIntoConstraints = false
        alpha = 0

        addSubview(blurView)
        addSubview(cardView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(percentLabel)
        cardView.addSubview(shotLabel)
        cardView.addSubview(progressBar)
        cardView.addSubview(frameLabel)
        cardView.addSubview(etaLabel)
        cardView.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            cardView.centerXAnchor.constraint(equalTo: centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: centerYAnchor),
            cardView.widthAnchor.constraint(equalToConstant: 300),

            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 28),
            titleLabel.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),

            percentLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            percentLabel.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),

            shotLabel.topAnchor.constraint(equalTo: percentLabel.bottomAnchor, constant: 12),
            shotLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            shotLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),

            progressBar.topAnchor.constraint(equalTo: shotLabel.bottomAnchor, constant: 14),
            progressBar.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 24),
            progressBar.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),
            progressBar.heightAnchor.constraint(equalToConstant: 4),

            frameLabel.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 10),
            frameLabel.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),

            etaLabel.topAnchor.constraint(equalTo: frameLabel.bottomAnchor, constant: 4),
            etaLabel.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),

            cancelButton.topAnchor.constraint(equalTo: etaLabel.bottomAnchor, constant: 16),
            cancelButton.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            cancelButton.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20),
        ])
    }

    // MARK: - Public API

    func show(in parent: UIView) {
        exportStartTime = CACurrentMediaTime()
        parent.addSubview(self)
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: parent.topAnchor),
            leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            bottomAnchor.constraint(equalTo: parent.bottomAnchor),
        ])
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
            self.alpha = 1
        }
    }

    func dismiss(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn, animations: {
            self.alpha = 0
        }) { _ in
            self.removeFromSuperview()
            completion?()
        }
    }

    func update(with progress: ExportProgress) {
        progressBar.setProgress(progress.overallProgress, animated: true)
        percentLabel.text = "\(Int(progress.overallProgress * 100))%"

        // Show status message (e.g. "Setting up camera…") or rendering info
        if let status = progress.statusMessage {
            shotLabel.text = "\(progress.shotName) — \(status)"
        } else if progress.totalShots > 1 {
            shotLabel.text = "Rendering \(progress.shotName) (\(progress.currentShotIndex + 1) of \(progress.totalShots))"
        } else {
            shotLabel.text = "Rendering \(progress.shotName)…"
        }

        frameLabel.text = "Frame \(progress.currentFrame) / \(progress.totalFrames)"

        // ETA calculation
        let elapsed = CACurrentMediaTime() - exportStartTime
        if progress.overallProgress > 0.02, elapsed > 1.0 {
            let totalEst  = elapsed / Double(progress.overallProgress)
            let remaining = max(0, totalEst - elapsed)
            if remaining < 60 {
                etaLabel.text = "~\(Int(remaining))s remaining"
            } else {
                let m = Int(remaining) / 60
                let s = Int(remaining) % 60
                etaLabel.text = "~\(m)m \(s)s remaining"
            }
        } else {
            etaLabel.text = "Estimating…"
        }
    }

    // MARK: - Actions

    @objc private func cancelTapped() {
        let haptic = UIImpactFeedbackGenerator(style: .light)
        haptic.impactOccurred()
        onCancel?()
    }
}
