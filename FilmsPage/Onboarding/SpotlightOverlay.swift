//
//  SpotlightOverlay.swift
//  FilmsPage
//
//  Full-screen UIKit overlay that:
//    • Dims everything outside a spotlight "hole" using CAShapeLayer + .evenOdd fill rule
//    • Displays a premium dark-themed callout card above or below the hole
//    • Pulses a glowing white border around the spotlighted control
//    • Passes touches through the hole so the user can interact with the real UI
//    • Shows a "Skip" button to exit the tutorial at any point
//    • Supports a full-screen welcome mode (no spotlight hole, centered card, tap-anywhere)
//
//  Usage (from TutorialManager):
//    let overlay = SpotlightOverlay()
//    overlay.targetView = someButton
//    overlay.delegate   = TutorialManager.shared
//    overlay.configure(spotlightFrame: frame, step: step, currentStepIndex: 1, totalSteps: 7)
//    overlay.show(in: window)
//

import UIKit

// MARK: - Delegate

protocol SpotlightOverlayDelegate: AnyObject {
    func spotlightOverlayDidRequestSkip(_ overlay: SpotlightOverlay)
    func spotlightOverlayDidDismissWelcome(_ overlay: SpotlightOverlay)
}

// Default implementation so existing conformers don't need to add the new method
extension SpotlightOverlayDelegate {
    func spotlightOverlayDidDismissWelcome(_ overlay: SpotlightOverlay) {}
}

// MARK: - SpotlightOverlay

final class SpotlightOverlay: UIView {

    // MARK: Public

    weak var delegate: SpotlightOverlayDelegate?
    /// Weak reference to the spotlighted view; used to recalculate position on layout.
    weak var targetView: UIView?

    /// When true, the overlay shows a centered welcome card with no spotlight hole.
    /// Tapping anywhere on the overlay dismisses it.
    private(set) var isWelcomeMode = false

    // MARK: Private layers & views

    private let dimmingLayer     = CAShapeLayer()
    private let ringLayer        = CALayer()
    private let calloutView      = SpotlightCalloutView()
    private let skipButton       = UIButton(type: .system)
    private let progressLabel    = UILabel()

    // Constraint pairs toggled to place callout above or below spotlight
    private var calloutTopConstraint:    NSLayoutConstraint?
    private var calloutBottomConstraint: NSLayoutConstraint?

    // Welcome-mode centering constraints
    private var calloutCenterYConstraint: NSLayoutConstraint?

    // Current spotlight rect in the overlay's own coordinate space
    private var spotlightRect: CGRect = .zero

    // Tap gesture for welcome mode
    private var welcomeTapGesture: UITapGestureRecognizer?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .clear
        isUserInteractionEnabled = true
        autoresizingMask = [.flexibleWidth, .flexibleHeight]

        setupDimmingLayer()
        setupRingLayer()
        setupCallout()
        setupProgressLabel()
        setupSkipButton()
    }

    // MARK: - Sub-view Setup

    private func setupDimmingLayer() {
        dimmingLayer.fillColor = UIColor.black.withAlphaComponent(0.78).cgColor
        dimmingLayer.fillRule  = .evenOdd
        layer.addSublayer(dimmingLayer)
    }

    private func setupRingLayer() {
        ringLayer.borderColor  = UIColor.white.cgColor
        ringLayer.borderWidth  = 2.5
        ringLayer.opacity      = 0.0  // hidden until needed
        layer.addSublayer(ringLayer)
    }

    private func setupCallout() {
        calloutView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(calloutView)

        NSLayoutConstraint.activate([
            calloutView.centerXAnchor.constraint(equalTo: centerXAnchor),
            calloutView.widthAnchor.constraint(lessThanOrEqualToConstant: 360),
            calloutView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            calloutView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24)
        ])
    }

    private func setupProgressLabel() {
        progressLabel.font        = UIFont.systemFont(ofSize: 12, weight: .semibold)
        progressLabel.textColor   = UIColor.white.withAlphaComponent(0.45)
        progressLabel.textAlignment = .center
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(progressLabel)
    }

    private func setupSkipButton() {
        var cfg = UIButton.Configuration.plain()
        cfg.title                 = "Skip Tutorial"
        cfg.baseForegroundColor   = UIColor.white.withAlphaComponent(0.55)
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var a = attrs
            a.font = UIFont.systemFont(ofSize: 13, weight: .medium)
            return a
        }
        skipButton.configuration = cfg
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        skipButton.addTarget(self, action: #selector(didTapSkip), for: .touchUpInside)
        addSubview(skipButton)

        NSLayoutConstraint.activate([
            skipButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 8),
            skipButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12)
        ])
    }

    // MARK: - Welcome Mode Configuration

    /// Configure the overlay for a full-screen welcome message (no spotlight hole).
    func configureWelcomeMode() {
        isWelcomeMode = true

        // No spotlight ring
        ringLayer.opacity = 0.0
        ringLayer.isHidden = true
        spotlightRect = .zero

        // Full dimming (no hole)
        dimmingLayer.fillRule = .nonZero

        // Configure the callout for welcome content
        calloutView.configureWelcome(
            title: "Welcome to SceneWiz",
            subtitle: "Your cinematic production toolkit.",
            body: "We'll walk you through setting up your first project — from scenes to films to the production canvas.",
            hint: "Tap anywhere to continue"
        )

        // Hide progress for welcome
        progressLabel.isHidden = true
        skipButton.isHidden    = false

        // Center the callout vertically
        calloutTopConstraint?.isActive    = false
        calloutBottomConstraint?.isActive = false
        calloutCenterYConstraint = calloutView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -20)
        calloutCenterYConstraint?.isActive = true

        // Add tap-anywhere gesture
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapWelcome))
        addGestureRecognizer(tap)
        welcomeTapGesture = tap
    }

    // MARK: - Spotlight Mode Configuration

    /// Apply all visual state for the given step.
    func configure(
        spotlightFrame: CGRect,
        step: TutorialStep,
        currentStepIndex: Int,
        totalSteps: Int
    ) {
        isWelcomeMode = false

        // Remove welcome tap gesture if present
        if let tap = welcomeTapGesture {
            removeGestureRecognizer(tap)
            welcomeTapGesture = nil
        }

        spotlightRect = spotlightFrame.insetBy(dx: -14, dy: -14)
        let radius: CGFloat = 16

        // Callout content
        calloutView.configure(title: step.stepTitle, message: step.coachMessage)

        // Progress
        progressLabel.isHidden = false
        progressLabel.text = currentStepIndex > 0
            ? "Step \(currentStepIndex) of \(totalSteps)"
            : ""

        // Dimming path (with hole)
        dimmingLayer.fillRule = .evenOdd
        updateDimmingPath(radius: radius)

        // Ring (visible & pulsing)
        ringLayer.isHidden     = false
        ringLayer.opacity      = 0.9
        ringLayer.frame        = spotlightRect
        ringLayer.cornerRadius = radius

        // Deactivate welcome centering
        calloutCenterYConstraint?.isActive = false

        // Position callout + progress label
        updateCalloutPosition()
        updateProgressLabelPosition()

        // Animate ring pulse
        addPulseAnimation()
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        if isWelcomeMode {
            // Full-screen dimming, no hole
            let full = UIBezierPath(rect: bounds)
            dimmingLayer.path  = full.cgPath
            dimmingLayer.frame = bounds
            return
        }

        guard spotlightRect != .zero else { return }

        // Recalculate spotlight from live target view frame (handles rotation / scroll)
        if let tv = targetView,
           let tvWindow = tv.window,
           let _ = tv.superview {
            let liveFrame = tv.convert(tv.bounds, to: tvWindow)
            if !liveFrame.isEmpty {
                spotlightRect = liveFrame.insetBy(dx: -14, dy: -14)
                ringLayer.frame = spotlightRect
            }
        }

        updateDimmingPath(radius: 16)
        updateCalloutPosition()
        updateProgressLabelPosition()
    }

    // MARK: - Private Helpers

    private func updateDimmingPath(radius: CGFloat) {
        let full = UIBezierPath(rect: bounds)
        let hole = UIBezierPath(roundedRect: spotlightRect, cornerRadius: radius)
        full.append(hole)
        dimmingLayer.path  = full.cgPath
        dimmingLayer.frame = bounds
    }

    private func updateCalloutPosition() {
        // Deactivate both, then pick the correct side
        calloutTopConstraint?.isActive    = false
        calloutBottomConstraint?.isActive = false
        calloutCenterYConstraint?.isActive = false

        let spaceBelow = bounds.height - spotlightRect.maxY
        let useBelow   = spaceBelow >= 160

        if useBelow {
            calloutTopConstraint = calloutView.topAnchor.constraint(
                equalTo: topAnchor,
                constant: spotlightRect.maxY + 28
            )
            calloutTopConstraint?.isActive = true
        } else {
            calloutBottomConstraint = calloutView.bottomAnchor.constraint(
                equalTo: topAnchor,
                constant: spotlightRect.minY - 28
            )
            calloutBottomConstraint?.isActive = true
        }
    }

    private func updateProgressLabelPosition() {
        progressLabel.sizeToFit()
        let w  = progressLabel.bounds.width
        let h  = progressLabel.bounds.height
        let cx = bounds.midX
        let useBelow = bounds.height - spotlightRect.maxY >= 160
        let y: CGFloat = useBelow
            ? spotlightRect.maxY + 28 + 100
            : spotlightRect.minY - 28 - 100 - h

        progressLabel.frame = CGRect(
            x: cx - w / 2,
            y: max(safeAreaInsets.top + 50, min(y, bounds.height - safeAreaInsets.bottom - h - 10)),
            width: w, height: h
        )
    }

    // MARK: - Animation

    private func addPulseAnimation() {
        ringLayer.removeAllAnimations()
        let anim           = CABasicAnimation(keyPath: "opacity")
        anim.fromValue     = 0.9
        anim.toValue       = 0.3
        anim.duration      = 1.0
        anim.autoreverses  = true
        anim.repeatCount   = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        ringLayer.add(anim, forKey: "pulse")
    }

    // MARK: - Presentation

    func show(in window: UIWindow, animated: Bool = true) {
        frame = window.bounds
        window.addSubview(self)

        guard animated else { return }
        alpha = 0

        // Fade in the overlay
        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseOut) {
            self.alpha = 1
        }

        // Scale-in the callout card for a premium feel
        calloutView.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        calloutView.alpha = 0
        UIView.animate(
            withDuration: 0.5,
            delay: 0.15,
            usingSpringWithDamping: 0.78,
            initialSpringVelocity: 0.3,
            options: .curveEaseOut
        ) {
            self.calloutView.transform = .identity
            self.calloutView.alpha = 1
        }
    }

    func dismiss(animated: Bool = true, completion: (() -> Void)? = nil) {
        guard animated else {
            removeFromSuperview()
            completion?()
            return
        }
        UIView.animate(withDuration: 0.25, animations: { self.alpha = 0 }) { _ in
            self.removeFromSuperview()
            completion?()
        }
    }

    // MARK: - Actions

    @objc private func didTapSkip() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        delegate?.spotlightOverlayDidRequestSkip(self)
    }

    @objc private func didTapWelcome() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        delegate?.spotlightOverlayDidDismissWelcome(self)
    }

    // MARK: - Hit Testing

    /// Allow taps inside the spotlight hole to fall through to the real UI.
    /// In welcome mode, capture all taps.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if isWelcomeMode { return super.hitTest(point, with: event) }
        if spotlightRect.contains(point) { return nil }
        return super.hitTest(point, with: event)
    }
}

// MARK: - SpotlightCalloutView

/// A premium dark-themed callout card used for onboarding coach marks.
final class SpotlightCalloutView: UIView {

    // MARK: Private subviews

    private let cardView        = UIView()
    private let titleLabel      = UILabel()
    private let messageLabel    = UILabel()
    private let hintLabel       = UILabel()
    private let accentBar       = UIView()
    private let contentStack    = UIStackView()

    // Separator line between body and hint
    private let separatorLine   = UIView()

    // Switchable leading constraints
    private var contentLeadingAccent:   NSLayoutConstraint!
    private var contentLeadingCard:     NSLayoutConstraint!

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: - Setup

    private func setup() {
        backgroundColor = .clear

        // ── Card ──────────────────────────────────────────────────────────────
        // Deep dark background matching the app's dark theme
        cardView.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 0.97)
        cardView.layer.cornerRadius  = 18
        cardView.layer.cornerCurve   = .continuous
        cardView.layer.borderWidth   = 1.0
        cardView.layer.borderColor   = UIColor.white.withAlphaComponent(0.15).cgColor

        // Premium shadow
        cardView.layer.shadowColor   = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.65
        cardView.layer.shadowRadius  = 28
        cardView.layer.shadowOffset  = CGSize(width: 0, height: 8)

        cardView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cardView)

        // ── Accent bar (left edge) ────────────────────────────────────────────
        // A thin vertical accent strip matching the app's red/maroon accent
        accentBar.backgroundColor = UIColor(red: 0.75, green: 0.12, blue: 0.18, alpha: 1.0)
        accentBar.layer.cornerRadius = 2
        accentBar.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(accentBar)

        // ── Title ─────────────────────────────────────────────────────────────
        titleLabel.font            = roundedFont(size: 18, weight: .bold)
        titleLabel.textColor       = .white
        titleLabel.numberOfLines   = 0

        // ── Message ───────────────────────────────────────────────────────────
        messageLabel.font          = UIFont.systemFont(ofSize: 15, weight: .regular)
        messageLabel.textColor     = UIColor.white.withAlphaComponent(0.72)
        messageLabel.numberOfLines = 0

        // ── Separator ─────────────────────────────────────────────────────────
        separatorLine.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        separatorLine.isHidden = true

        // ── Hint ──────────────────────────────────────────────────────────────
        hintLabel.font           = UIFont.systemFont(ofSize: 12, weight: .medium)
        hintLabel.textColor      = UIColor.white.withAlphaComponent(0.38)
        hintLabel.numberOfLines  = 1
        hintLabel.textAlignment  = .center
        hintLabel.isHidden       = true

        // ── Content Stack ─────────────────────────────────────────────────────
        contentStack.axis      = .vertical
        contentStack.spacing   = 10
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        [titleLabel, messageLabel, separatorLine, hintLabel].forEach {
            contentStack.addArrangedSubview($0)
        }
        cardView.addSubview(contentStack)

        // ── Switchable leading constraints ────────────────────────────────────
        // Accent mode: content starts after the accent bar
        contentLeadingAccent = contentStack.leadingAnchor.constraint(
            equalTo: accentBar.trailingAnchor, constant: 14
        )
        // Welcome mode: content has equal padding on both sides
        contentLeadingCard = contentStack.leadingAnchor.constraint(
            equalTo: cardView.leadingAnchor, constant: 24
        )

        // ── Constraints ───────────────────────────────────────────────────────
        contentLeadingAccent.isActive = true  // default: accent mode

        NSLayoutConstraint.activate([
            // Card fills self
            cardView.topAnchor.constraint(equalTo: topAnchor),
            cardView.bottomAnchor.constraint(equalTo: bottomAnchor),
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor),

            // Accent bar (left edge)
            accentBar.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            accentBar.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 18),
            accentBar.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -18),
            accentBar.widthAnchor.constraint(equalToConstant: 3),

            // Content stack (top, bottom, trailing — leading is switchable)
            contentStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 20),
            contentStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),

            // Separator height
            separatorLine.heightAnchor.constraint(equalToConstant: 0.5)
        ])
    }

    // MARK: - Configuration (Spotlight Steps)

    func configure(title: String, message: String) {
        titleLabel.text         = title
        titleLabel.font         = roundedFont(size: 18, weight: .bold)
        titleLabel.textAlignment = .natural
        messageLabel.text       = message
        messageLabel.font       = UIFont.systemFont(ofSize: 15, weight: .regular)
        messageLabel.textColor  = UIColor.white.withAlphaComponent(0.72)
        messageLabel.textAlignment = .natural
        messageLabel.isHidden   = message.isEmpty

        // Hide welcome-only elements
        separatorLine.isHidden  = true
        hintLabel.isHidden      = true

        // Standard spacing
        contentStack.spacing    = 8
        contentStack.alignment  = .fill

        // Show accent bar, use accent leading
        accentBar.isHidden = false
        contentLeadingCard.isActive   = false
        contentLeadingAccent.isActive = true
    }

    // MARK: - Configuration (Welcome Mode)

    func configureWelcome(title: String, subtitle: String, body: String, hint: String) {
        // Title — app name
        titleLabel.text      = title
        titleLabel.font      = roundedFont(size: 26, weight: .bold)
        titleLabel.textAlignment = .center

        // Subtitle + body
        messageLabel.text    = "\(subtitle)\n\n\(body)"
        messageLabel.font    = UIFont.systemFont(ofSize: 15, weight: .regular)
        messageLabel.textColor = UIColor.white.withAlphaComponent(0.65)
        messageLabel.textAlignment = .center
        messageLabel.isHidden = false

        // Separator
        separatorLine.isHidden = false

        // Hint
        hintLabel.text    = hint
        hintLabel.isHidden = false

        // Wider spacing for the welcome card
        contentStack.spacing   = 14
        contentStack.alignment = .center

        // Hide accent bar, use card leading
        accentBar.isHidden = true
        contentLeadingAccent.isActive = false
        contentLeadingCard.isActive   = true
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

