//
//  SequencePreviewViewController.swift
//  FilmsPage
//
//  Full-screen video preview shown after a sequence export finishes.
//  Plays the exported MP4 with native AVPlayerViewController controls.
//  Provides a Share button to send the video via UIActivityViewController
//  and a close button to dismiss.
//

import UIKit
import AVKit

final class SequencePreviewViewController: UIViewController {

    // MARK: - Data

    private let videoURL: URL
    private let sequenceName: String

    // MARK: - Player

    private var player: AVPlayer?
    private var playerVC: AVPlayerViewController?

    // MARK: - Init

    init(videoURL: URL, sequenceName: String) {
        self.videoURL = videoURL
        self.sequenceName = sequenceName
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupPlayer()
        setupOverlayButtons()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        player?.play()
    }

    override var prefersStatusBarHidden: Bool { true }

    // MARK: - Player Setup

    private func setupPlayer() {
        let player = AVPlayer(url: videoURL)
        self.player = player

        let playerVC = AVPlayerViewController()
        playerVC.player = player
        playerVC.showsPlaybackControls = true
        playerVC.videoGravity = .resizeAspect

        addChild(playerVC)
        playerVC.view.frame = view.bounds
        playerVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(playerVC.view)
        playerVC.didMove(toParent: self)
        self.playerVC = playerVC

        // Loop playback
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }
    }

    // MARK: - Overlay Buttons

    private func setupOverlayButtons() {
        // Close button (top-left)
        let closeButton = makeGlassButton(systemName: "xmark")
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        // Share button (top-right)
        let shareButton = makeGlassButton(systemName: "square.and.arrow.up")
        shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)

        // Title label
        let titleLabel = UILabel()
        titleLabel.text = sequenceName
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(closeButton)
        view.addSubview(shareButton)
        view.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            closeButton.widthAnchor.constraint(equalToConstant: 36),
            closeButton.heightAnchor.constraint(equalToConstant: 36),

            shareButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            shareButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            shareButton.widthAnchor.constraint(equalToConstant: 36),
            shareButton.heightAnchor.constraint(equalToConstant: 36),

            titleLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: closeButton.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: shareButton.leadingAnchor, constant: -12),
        ])
    }

    private func makeGlassButton(systemName: String) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: systemName, withConfiguration:
            UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)), for: .normal)
        btn.tintColor = .white
        btn.backgroundColor = UIColor(white: 0, alpha: 0.35)
        btn.layer.cornerRadius = 18
        btn.clipsToBounds = true

        // Add blur
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blur.isUserInteractionEnabled = false
        blur.frame = CGRect(x: 0, y: 0, width: 36, height: 36)
        blur.layer.cornerRadius = 18
        blur.clipsToBounds = true
        btn.insertSubview(blur, at: 0)

        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        player?.pause()
        dismiss(animated: true)
    }

    @objc private func shareTapped() {
        player?.pause()
        let shareVC = UIActivityViewController(
            activityItems: [videoURL],
            applicationActivities: nil
        )
        shareVC.popoverPresentationController?.sourceView = view
        shareVC.popoverPresentationController?.sourceRect = CGRect(
            x: view.bounds.maxX - 50, y: 60, width: 36, height: 36
        )
        present(shareVC, animated: true)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
