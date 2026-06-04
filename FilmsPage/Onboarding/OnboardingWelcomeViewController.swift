//
//  OnboardingWelcomeViewController.swift
//  FilmsPage
//
//  Premium, fully programmatic welcome screen shown on first app launch.
//  No storyboard required — presented as .overFullScreen from SceneDelegate.
//
//  Design language:
//    • Deep cinematic dark gradient background
//    • Film-strip perforation decoration
//    • Animated logo with glowing ring
//    • Staggered entrance animation on all text and CTA
//    • Floating particle dots for depth
//    • Red accent CTA: "Let's Start Creating"
//

import UIKit
import TipKit

final class OnboardingWelcomeViewController: UIViewController {

    // MARK: - UI Elements

    private let gradientLayer     = CAGradientLayer()
    private let particleHost      = UIView()
    private let filmStripTop      = FilmStripView()
    private let filmStripBottom   = FilmStripView()
    private let logoRing          = UIView()
    private let logoIcon          = UIImageView()
    private let taglineLabel      = UILabel()
    private let heroTitleLabel    = UILabel()
    private let bodyLabel         = UILabel()
    private let featurePillsStack = UIStackView()
    private let ctaButton         = UIButton(type: .system)

    // Tracks whether the entrance animation has run
    private var didAnimate = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didAnimate else { return }
        didAnimate = true
        runEntranceAnimation()
    }

    // MARK: - Build UI

    private func buildUI() {
        setupBackground()
        setupParticles()
        setupFilmStrips()
        setupLogo()
        setupTextBlock()
        setupFeaturePills()
        setupCTAButton()
    }

    // MARK: - Background

    private func setupBackground() {
        gradientLayer.colors = [
            UIColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 1).cgColor,
            UIColor(red: 0.09, green: 0.04, blue: 0.06, alpha: 1).cgColor,
            UIColor(red: 0.13, green: 0.06, blue: 0.09, alpha: 1).cgColor
        ]
        gradientLayer.locations   = [0, 0.5, 1]
        gradientLayer.startPoint  = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint    = CGPoint(x: 1, y: 1)
        view.layer.insertSublayer(gradientLayer, at: 0)
    }

    // MARK: - Particles

    private func setupParticles() {
        particleHost.frame                 = view.bounds
        particleHost.isUserInteractionEnabled = false
        particleHost.autoresizingMask      = [.flexibleWidth, .flexibleHeight]
        view.addSubview(particleHost)

        for _ in 0..<22 {
            let size    = CGFloat.random(in: 2...5)
            let dot     = UIView(frame: CGRect(
                x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                y: CGFloat.random(in: 0...UIScreen.main.bounds.height),
                width: size, height: size
            ))
            dot.layer.cornerRadius  = size / 2
            dot.backgroundColor     = UIColor.white.withAlphaComponent(CGFloat.random(in: 0.06...0.22))
            particleHost.addSubview(dot)

            let fade             = CABasicAnimation(keyPath: "opacity")
            fade.fromValue       = dot.backgroundColor?.cgColor.alpha ?? 0.1
            fade.toValue         = 0.02
            fade.duration        = Double.random(in: 1.4...3.2)
            fade.autoreverses    = true
            fade.repeatCount     = .infinity
            fade.timeOffset      = Double.random(in: 0...2.5)
            dot.layer.add(fade, forKey: "flicker")
        }
    }

    // MARK: - Film Strips

    private func setupFilmStrips() {
        filmStripTop.alpha    = 0.10
        filmStripBottom.alpha = 0.10
        filmStripBottom.transform = CGAffineTransform(scaleX: 1, y: -1) // mirror vertically

        [filmStripTop, filmStripBottom].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.isUserInteractionEnabled = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            filmStripTop.topAnchor.constraint(equalTo: view.topAnchor),
            filmStripTop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filmStripTop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            filmStripTop.heightAnchor.constraint(equalToConstant: 72),

            filmStripBottom.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            filmStripBottom.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            filmStripBottom.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            filmStripBottom.heightAnchor.constraint(equalToConstant: 72)
        ])
    }

    // MARK: - Logo

    private func setupLogo() {
        logoRing.backgroundColor     = UIColor(red: 0.75, green: 0.10, blue: 0.15, alpha: 0.18)
        logoRing.layer.cornerRadius  = 56
        logoRing.layer.borderWidth   = 1.8
        logoRing.layer.borderColor   = UIColor(red: 0.80, green: 0.20, blue: 0.20, alpha: 0.65).cgColor
        logoRing.layer.shadowColor   = UIColor(red: 0.75, green: 0.10, blue: 0.15, alpha: 1).cgColor
        logoRing.layer.shadowOpacity = 0.45
        logoRing.layer.shadowRadius  = 22
        logoRing.layer.shadowOffset  = .zero
        logoRing.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logoRing)

        let iconCfg     = UIImage.SymbolConfiguration(pointSize: 38, weight: .semibold)
        logoIcon.image  = UIImage(systemName: "film.fill", withConfiguration: iconCfg)
        logoIcon.tintColor          = UIColor(red: 0.95, green: 0.35, blue: 0.30, alpha: 1)
        logoIcon.contentMode        = .scaleAspectFit
        logoIcon.translatesAutoresizingMaskIntoConstraints = false
        logoRing.addSubview(logoIcon)

        NSLayoutConstraint.activate([
            logoRing.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoRing.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 56),
            logoRing.widthAnchor.constraint(equalToConstant: 112),
            logoRing.heightAnchor.constraint(equalToConstant: 112),

            logoIcon.centerXAnchor.constraint(equalTo: logoRing.centerXAnchor),
            logoIcon.centerYAnchor.constraint(equalTo: logoRing.centerYAnchor),
            logoIcon.widthAnchor.constraint(equalToConstant: 50),
            logoIcon.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    // MARK: - Text Block

    private func setupTextBlock() {
        // "Welcome to"
        taglineLabel.text          = "Welcome to"
        taglineLabel.font          = UIFont.systemFont(ofSize: 17, weight: .regular)
        taglineLabel.textColor     = UIColor.white.withAlphaComponent(0.55)
        taglineLabel.textAlignment = .center

        // App name
        heroTitleLabel.text          = "SceneWiz"
        heroTitleLabel.font          = roundedFont(size: 44, weight: .bold)
        heroTitleLabel.textColor     = .white
        heroTitleLabel.textAlignment = .center

        // Body
        bodyLabel.text = "We'll guide you through creating your first production\nworkflow — from scene to canvas."
        bodyLabel.font          = UIFont.systemFont(ofSize: 16, weight: .regular)
        bodyLabel.textColor     = UIColor.white.withAlphaComponent(0.62)
        bodyLabel.textAlignment = .center
        bodyLabel.numberOfLines = 0

        let vStack = UIStackView(arrangedSubviews: [taglineLabel, heroTitleLabel, bodyLabel])
        vStack.axis      = .vertical
        vStack.spacing   = 8
        vStack.alignment = .center
        vStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(vStack)

        NSLayoutConstraint.activate([
            vStack.topAnchor.constraint(equalTo: logoRing.bottomAnchor, constant: 32),
            vStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            vStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }

    // MARK: - Feature Pills

    private func setupFeaturePills() {
        let features: [(String, String)] = [
            ("film.stack.fill", "Film Projects"),
            ("camera.fill", "Canvas"),
            ("sparkles", "Scene Library")
        ]

        features.map { makePill(icon: $0.0, text: $0.1) }.forEach {
            featurePillsStack.addArrangedSubview($0)
        }

        featurePillsStack.axis       = .horizontal
        featurePillsStack.spacing    = 10
        featurePillsStack.alignment  = .center
        featurePillsStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(featurePillsStack)

        NSLayoutConstraint.activate([
            featurePillsStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            featurePillsStack.bottomAnchor.constraint(
                equalTo: ctaButton.topAnchor, constant: -36
            )
        ])
    }

    private func makePill(icon: String, text: String) -> UIView {
        let pill = UIView()
        pill.backgroundColor       = UIColor.white.withAlphaComponent(0.07)
        pill.layer.cornerRadius    = 20
        pill.layer.borderWidth     = 0.5
        pill.layer.borderColor     = UIColor.white.withAlphaComponent(0.12).cgColor

        let cfg = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        let iv  = UIImageView(image: UIImage(systemName: icon, withConfiguration: cfg))
        iv.tintColor    = UIColor(red: 0.90, green: 0.38, blue: 0.38, alpha: 1)
        iv.translatesAutoresizingMaskIntoConstraints = false

        let lbl = UILabel()
        lbl.text      = text
        lbl.font      = UIFont.systemFont(ofSize: 12, weight: .medium)
        lbl.textColor = UIColor.white.withAlphaComponent(0.70)
        lbl.translatesAutoresizingMaskIntoConstraints = false

        let hs = UIStackView(arrangedSubviews: [iv, lbl])
        hs.axis      = .horizontal
        hs.spacing   = 5
        hs.alignment = .center
        hs.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(hs)

        NSLayoutConstraint.activate([
            hs.topAnchor.constraint(equalTo: pill.topAnchor, constant: 9),
            hs.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -9),
            hs.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 13),
            hs.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -13)
        ])
        return pill
    }

    // MARK: - CTA Button

    private func setupCTAButton() {
        var cfg = UIButton.Configuration.filled()
        cfg.title              = "Let's Start Creating"
        cfg.image              = UIImage(systemName: "arrow.right.circle.fill")
        cfg.imagePlacement     = .trailing
        cfg.imagePadding       = 10
        cfg.baseBackgroundColor = UIColor(red: 0.75, green: 0.10, blue: 0.15, alpha: 1)
        cfg.baseForegroundColor = .white
        cfg.cornerStyle        = .capsule
        cfg.contentInsets      = NSDirectionalEdgeInsets(top: 18, leading: 38, bottom: 18, trailing: 38)
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
            var m = a; m.font = UIFont.systemFont(ofSize: 17, weight: .semibold); return m
        }
        ctaButton.configuration = cfg
        ctaButton.layer.shadowColor   = UIColor(red: 0.75, green: 0.10, blue: 0.15, alpha: 1).cgColor
        ctaButton.layer.shadowOpacity = 0.55
        ctaButton.layer.shadowRadius  = 22
        ctaButton.layer.shadowOffset  = .zero
        ctaButton.translatesAutoresizingMaskIntoConstraints = false
        ctaButton.addTarget(self, action: #selector(didTapStart), for: .touchUpInside)
        view.addSubview(ctaButton)

        NSLayoutConstraint.activate([
            ctaButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            ctaButton.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -44
            )
        ])
    }

    // MARK: - Animations

    private func runEntranceAnimation() {
        let items: [UIView] = [logoRing, taglineLabel, heroTitleLabel, bodyLabel,
                               featurePillsStack, ctaButton]
        items.forEach {
            $0.alpha     = 0
            $0.transform = CGAffineTransform(translationX: 0, y: 28)
        }

        for (i, v) in items.enumerated() {
            UIView.animate(
                withDuration: 0.55,
                delay: Double(i) * 0.10,
                usingSpringWithDamping: 0.82,
                initialSpringVelocity: 0.2,
                options: .curveEaseOut
            ) {
                v.alpha     = 1
                v.transform = .identity
            }
        }

        // Gentle logo pulse after entrance
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in
            self?.pulseLogo()
        }
    }

    private func pulseLogo() {
        UIView.animate(
            withDuration: 1.3,
            delay: 0,
            usingSpringWithDamping: 0.45,
            initialSpringVelocity: 0.1,
            options: [.autoreverse, .repeat, .allowUserInteraction]
        ) { [weak self] in
            self?.logoRing.transform = CGAffineTransform(scaleX: 1.06, y: 1.06)
        }
    }

    // MARK: - Actions

    @objc private func didTapStart() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss(animated: true) {
            TutorialManager.shared.advance(to: .homeCreateScene)
        }
    }

    // MARK: - Helpers

    private func roundedFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let descriptor = UIFont.systemFont(ofSize: size, weight: weight).fontDescriptor
        if let rounded = descriptor.withDesign(.rounded) {
            return UIFont(descriptor: rounded, size: size)
        }
        return UIFont.systemFont(ofSize: size, weight: weight)
    }
}

// MARK: - FilmStripView

/// Decorative view that draws classic film-strip sprocket holes.
private final class FilmStripView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.setFillColor(UIColor.white.cgColor)

        let perf: CGFloat  = 13
        let gap: CGFloat   = 20
        var x: CGFloat     = 8

        while x < rect.width {
            let top    = CGRect(x: x, y: 4, width: perf, height: perf)
            let bottom = CGRect(x: x, y: rect.height - perf - 4, width: perf, height: perf)
            UIBezierPath(roundedRect: top,    cornerRadius: 3).fill()
            UIBezierPath(roundedRect: bottom, cornerRadius: 3).fill()
            x += perf + gap
        }
    }
}
