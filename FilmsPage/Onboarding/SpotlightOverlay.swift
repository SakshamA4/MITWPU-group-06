//
//  SpotlightOverlay.swift
//  FilmsPage
//
//  Full-screen UIKit overlay that:
//    • Dims everything outside a spotlight "hole" using CAShapeLayer + .evenOdd fill rule
//    • Displays a premium dark-themed callout card near the spotlighted element
//    • Pulses a glowing white border around the spotlighted control
//    • Passes touches through the hole so the user can interact with the real UI
//    • Shows a "Skip Tutorial" button to exit at any point
//    • Supports 4 modes: standard spotlight, showcase (blocked), hint (full dim), welcome
//

import UIKit

// MARK: - Delegate

protocol SpotlightOverlayDelegate: AnyObject {
    func spotlightOverlayDidRequestSkip(_ overlay: SpotlightOverlay)
    func spotlightOverlayDidTapToContinue(_ overlay: SpotlightOverlay)
}

// MARK: - SpotlightOverlay

final class SpotlightOverlay: UIView {

    // MARK: Public

    weak var delegate: SpotlightOverlayDelegate?
    weak var targetView: UIView?

    /// When true, the overlay shows no spotlight hole — full dimming with a centered card.
    private(set) var isFullDimMode = false

    /// When true, the spotlight hole is visible but touches do NOT pass through.
    /// A tap-anywhere gesture is added so the user taps to continue.
    private(set) var blockSpotlightPassthrough = false

    // MARK: Private layers & views

    private let dimmingLayer     = CAShapeLayer()
    private let ringLayer        = CALayer()
    private let calloutView      = SpotlightCalloutView()
    private let skipButton       = UIButton(type: .system)
    private let progressLabel    = UILabel()

    // Dynamic callout constraints
    private var calloutTopConstraint:      NSLayoutConstraint?
    private var calloutBottomConstraint:   NSLayoutConstraint?
    private var calloutCenterYConstraint:  NSLayoutConstraint?
    private var calloutCenterXConstraint:  NSLayoutConstraint?
    private var calloutLeadingConstraint:  NSLayoutConstraint?
    private var calloutTrailingConstraint: NSLayoutConstraint?

    private var spotlightRect: CGRect = .zero
    private var tapGesture: UITapGestureRecognizer?

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
        ringLayer.opacity      = 0.0
        layer.addSublayer(ringLayer)
    }

    private func setupCallout() {
        calloutView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(calloutView)

        NSLayoutConstraint.activate([
            calloutView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 20),
            calloutView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20)
        ])
    }

    private func setupProgressLabel() {
        progressLabel.font          = UIFont.systemFont(ofSize: 12, weight: .semibold)
        progressLabel.textColor     = UIColor.white.withAlphaComponent(0.45)
        progressLabel.textAlignment = .center
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(progressLabel)
    }

    private func setupSkipButton() {
        var cfg = UIButton.Configuration.plain()
        cfg.title               = "Skip Tutorial"
        cfg.baseForegroundColor = UIColor.white.withAlphaComponent(0.55)
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

    // ──────────────────────────────────────────────────────────────────────────
    // MARK: - Mode 1: Standard Spotlight (touches pass through the hole)
    // ──────────────────────────────────────────────────────────────────────────

    func configure(
        spotlightFrame: CGRect,
        step: TutorialStep,
        currentStepIndex: Int,
        totalSteps: Int
    ) {
        isFullDimMode = false
        blockSpotlightPassthrough = false
        removeTapGesture()

        spotlightRect = spotlightFrame.insetBy(dx: -14, dy: -14)
        let radius: CGFloat = 16

        calloutView.configure(title: step.stepTitle, message: step.coachMessage)

        progressLabel.isHidden = false
        progressLabel.text = currentStepIndex > 0
            ? "Step \(currentStepIndex) of \(totalSteps)"
            : ""

        dimmingLayer.fillRule = .evenOdd
        updateDimmingPath(radius: radius)

        ringLayer.isHidden     = false
        ringLayer.opacity      = 0.9
        ringLayer.frame        = spotlightRect
        ringLayer.cornerRadius = radius

        positionCalloutNearSpotlight()
        updateProgressLabelPosition()
        addPulseAnimation()
    }

    // ──────────────────────────────────────────────────────────────────────────
    // MARK: - Mode 2: Showcase (spotlight visible, touches BLOCKED, tap to continue)
    // ──────────────────────────────────────────────────────────────────────────

    func configureShowcase(
        spotlightFrame: CGRect,
        step: TutorialStep,
        currentStepIndex: Int,
        totalSteps: Int
    ) {
        isFullDimMode = false
        blockSpotlightPassthrough = true

        spotlightRect = spotlightFrame.insetBy(dx: -14, dy: -14)
        let radius: CGFloat = 16

        calloutView.configure(
            title: step.stepTitle,
            message: step.coachMessage,
            hint: "Tap anywhere to continue"
        )

        progressLabel.isHidden = false
        progressLabel.text = currentStepIndex > 0
            ? "Step \(currentStepIndex) of \(totalSteps)"
            : ""

        dimmingLayer.fillRule = .evenOdd
        updateDimmingPath(radius: radius)

        ringLayer.isHidden     = false
        ringLayer.opacity      = 0.9
        ringLayer.frame        = spotlightRect
        ringLayer.cornerRadius = radius

        positionCalloutNearSpotlight()
        updateProgressLabelPosition()
        addPulseAnimation()
        addTapGesture()
    }

    // ──────────────────────────────────────────────────────────────────────────
    // MARK: - Mode 3: Hint (full dim, centered card, tap to continue)
    // ──────────────────────────────────────────────────────────────────────────

    func configureHint(title: String, message: String, stepIndex: Int, totalSteps: Int) {
        isFullDimMode = true
        blockSpotlightPassthrough = true

        ringLayer.opacity  = 0.0
        ringLayer.isHidden = true
        spotlightRect      = .zero

        dimmingLayer.fillRule = .nonZero

        calloutView.configure(
            title: title,
            message: message,
            hint: "Tap anywhere to continue"
        )

        progressLabel.isHidden = false
        progressLabel.text = stepIndex > 0
            ? "Step \(stepIndex) of \(totalSteps)"
            : ""
        skipButton.isHidden = false

        deactivateCalloutPositioning()
        calloutCenterYConstraint = calloutView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -20)
        calloutCenterXConstraint = calloutView.centerXAnchor.constraint(equalTo: centerXAnchor)
        calloutCenterYConstraint?.isActive = true
        calloutCenterXConstraint?.isActive = true

        addTapGesture()
    }

    // ──────────────────────────────────────────────────────────────────────────
    // MARK: - Mode 4: Welcome (full dim, centered card, tap to continue)
    // ──────────────────────────────────────────────────────────────────────────

    func configureWelcomeMode() {
        isFullDimMode = true
        blockSpotlightPassthrough = true

        ringLayer.opacity  = 0.0
        ringLayer.isHidden = true
        spotlightRect      = .zero

        dimmingLayer.fillRule = .nonZero

        calloutView.configureWelcome(
            title: "Welcome to SceneWiz",
            subtitle: "Bringing raw ideas to life.",
            body: "We'll walk you through setting up your first project — from scenes to films to the production canvas.",
            hint: "Tap anywhere to continue"
        )

        progressLabel.isHidden = true
        skipButton.isHidden    = false

        deactivateCalloutPositioning()
        calloutCenterYConstraint = calloutView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -20)
        calloutCenterXConstraint = calloutView.centerXAnchor.constraint(equalTo: centerXAnchor)
        calloutCenterYConstraint?.isActive = true
        calloutCenterXConstraint?.isActive = true

        addTapGesture()
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        if isFullDimMode {
            let full = UIBezierPath(rect: bounds)
            dimmingLayer.path  = full.cgPath
            dimmingLayer.frame = bounds
            return
        }

        guard spotlightRect != .zero else { return }

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
        positionCalloutNearSpotlight()
        updateProgressLabelPosition()
    }

    // MARK: - Positioning Helpers

    private func deactivateCalloutPositioning() {
        calloutTopConstraint?.isActive      = false
        calloutBottomConstraint?.isActive   = false
        calloutCenterYConstraint?.isActive  = false
        calloutCenterXConstraint?.isActive  = false
        calloutLeadingConstraint?.isActive  = false
        calloutTrailingConstraint?.isActive = false
    }

    private func positionCalloutNearSpotlight() {
        deactivateCalloutPositioning()

        let spaceBelow = bounds.height - spotlightRect.maxY
        let spaceAbove = spotlightRect.minY
        let gap: CGFloat = 28

        if spaceBelow >= 180 {
            calloutTopConstraint = calloutView.topAnchor.constraint(
                equalTo: topAnchor, constant: spotlightRect.maxY + gap
            )
            calloutTopConstraint?.isActive = true
        } else if spaceAbove >= 180 {
            calloutBottomConstraint = calloutView.bottomAnchor.constraint(
                equalTo: topAnchor, constant: spotlightRect.minY - gap
            )
            calloutBottomConstraint?.isActive = true
        } else {
            calloutCenterYConstraint = calloutView.centerYAnchor.constraint(equalTo: centerYAnchor)
            calloutCenterYConstraint?.isActive = true
        }

        let spotCenterX = spotlightRect.midX
        let screenCenterX = bounds.midX

        if abs(spotCenterX - screenCenterX) < 80 {
            calloutCenterXConstraint = calloutView.centerXAnchor.constraint(equalTo: centerXAnchor)
            calloutCenterXConstraint?.isActive = true
        } else if spotCenterX < screenCenterX {
            let leading = max(20, spotlightRect.minX)
            calloutLeadingConstraint = calloutView.leadingAnchor.constraint(
                equalTo: leadingAnchor, constant: leading
            )
            calloutLeadingConstraint?.isActive = true
        } else {
            let trailing = max(20, bounds.width - spotlightRect.maxX)
            calloutTrailingConstraint = calloutView.trailingAnchor.constraint(
                equalTo: trailingAnchor, constant: -trailing
            )
            calloutTrailingConstraint?.isActive = true
        }
    }

    private func updateDimmingPath(radius: CGFloat) {
        let full = UIBezierPath(rect: bounds)
        let hole = UIBezierPath(roundedRect: spotlightRect, cornerRadius: radius)
        full.append(hole)
        dimmingLayer.path  = full.cgPath
        dimmingLayer.frame = bounds
    }

    private func updateProgressLabelPosition() {
        progressLabel.sizeToFit()
        let w  = progressLabel.bounds.width
        let h  = progressLabel.bounds.height
        let cx = bounds.midX
        let spaceBelow = bounds.height - spotlightRect.maxY
        let y: CGFloat = spaceBelow >= 180
            ? spotlightRect.maxY + 28 + 120
            : spotlightRect.minY - 28 - 120 - h

        progressLabel.frame = CGRect(
            x: cx - w / 2,
            y: max(safeAreaInsets.top + 50, min(y, bounds.height - safeAreaInsets.bottom - h - 10)),
            width: w, height: h
        )
    }

    // MARK: - Tap Gesture

    private func addTapGesture() {
        removeTapGesture()
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapToContinue))
        addGestureRecognizer(tap)
        tapGesture = tap
    }

    private func removeTapGesture() {
        if let tap = tapGesture {
            removeGestureRecognizer(tap)
            tapGesture = nil
        }
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

        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseOut) {
            self.alpha = 1
        }

        calloutView.transform = CGAffineTransform(scaleX: 0.88, y: 0.88)
        calloutView.alpha = 0
        UIView.animate(
            withDuration: 0.5,
            delay: 0.12,
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
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        delegate?.spotlightOverlayDidRequestSkip(self)
    }

    @objc private func didTapToContinue() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        delegate?.spotlightOverlayDidTapToContinue(self)
    }

    // MARK: - Hit Testing

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Full-dim modes and showcase: capture all touches
        if isFullDimMode || blockSpotlightPassthrough {
            return super.hitTest(point, with: event)
        }
        // Standard spotlight: let taps inside the hole fall through
        if spotlightRect.contains(point) { return nil }
        return super.hitTest(point, with: event)
    }
}

// MARK: - SpotlightCalloutView

/// A premium dark-themed callout card for onboarding coach marks.
final class SpotlightCalloutView: UIView {

    // MARK: Private subviews

    private let cardView        = UIView()
    private let titleLabel      = UILabel()
    private let messageLabel    = UILabel()
    private let hintLabel       = UILabel()
    private let accentBar       = UIView()
    private let contentStack    = UIStackView()
    private let separatorLine   = UIView()

    private var contentLeadingAccent: NSLayoutConstraint!
    private var contentLeadingCard:   NSLayoutConstraint!

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

        cardView.backgroundColor    = UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 0.97)
        cardView.layer.cornerRadius = 20
        cardView.layer.cornerCurve  = .continuous
        cardView.layer.borderWidth  = 1.0
        cardView.layer.borderColor  = UIColor.white.withAlphaComponent(0.15).cgColor
        cardView.layer.shadowColor   = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.65
        cardView.layer.shadowRadius  = 28
        cardView.layer.shadowOffset  = CGSize(width: 0, height: 8)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cardView)

        accentBar.backgroundColor    = UIColor(red: 0.75, green: 0.12, blue: 0.18, alpha: 1.0)
        accentBar.layer.cornerRadius = 2
        accentBar.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(accentBar)

        titleLabel.font          = roundedFont(size: 20, weight: .bold)
        titleLabel.textColor     = .white
        titleLabel.numberOfLines = 0

        messageLabel.font          = UIFont.systemFont(ofSize: 16, weight: .regular)
        messageLabel.textColor     = UIColor.white.withAlphaComponent(0.72)
        messageLabel.numberOfLines = 0
        messageLabel.lineBreakMode = .byWordWrapping

        separatorLine.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        separatorLine.isHidden = true

        hintLabel.font          = UIFont.systemFont(ofSize: 13, weight: .medium)
        hintLabel.textColor     = UIColor.white.withAlphaComponent(0.38)
        hintLabel.numberOfLines = 1
        hintLabel.textAlignment = .center
        hintLabel.isHidden      = true

        contentStack.axis      = .vertical
        contentStack.spacing   = 10
        contentStack.alignment = .fill
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        [titleLabel, messageLabel, separatorLine, hintLabel].forEach {
            contentStack.addArrangedSubview($0)
        }
        cardView.addSubview(contentStack)

        contentLeadingAccent = contentStack.leadingAnchor.constraint(
            equalTo: accentBar.trailingAnchor, constant: 16
        )
        contentLeadingCard = contentStack.leadingAnchor.constraint(
            equalTo: cardView.leadingAnchor, constant: 28
        )
        contentLeadingAccent.isActive = true

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: topAnchor),
            cardView.bottomAnchor.constraint(equalTo: bottomAnchor),
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor),

            accentBar.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            accentBar.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 20),
            accentBar.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -20),
            accentBar.widthAnchor.constraint(equalToConstant: 3),

            contentStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 22),
            contentStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -22),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -22),

            separatorLine.heightAnchor.constraint(equalToConstant: 0.5)
        ])
    }

    // MARK: - Configuration (Standard + Showcase)

    func configure(title: String, message: String, hint: String? = nil) {
        titleLabel.text          = title
        titleLabel.font          = roundedFont(size: 20, weight: .bold)
        titleLabel.textAlignment = .natural
        messageLabel.text        = message
        messageLabel.font        = UIFont.systemFont(ofSize: 16, weight: .regular)
        messageLabel.textColor   = UIColor.white.withAlphaComponent(0.72)
        messageLabel.textAlignment = .natural
        messageLabel.isHidden    = message.isEmpty

        if let hint = hint {
            separatorLine.isHidden = false
            hintLabel.text         = hint
            hintLabel.isHidden     = false
            contentStack.spacing   = 12
        } else {
            separatorLine.isHidden = true
            hintLabel.isHidden     = true
            contentStack.spacing   = 10
        }

        contentStack.alignment = .fill
        accentBar.isHidden = false
        contentLeadingCard.isActive   = false
        contentLeadingAccent.isActive = true
    }

    // MARK: - Configuration (Welcome / Hint - centered)

    func configureWelcome(title: String, subtitle: String, body: String, hint: String) {
        titleLabel.text          = title
        titleLabel.font          = roundedFont(size: 28, weight: .bold)
        titleLabel.textAlignment = .center

        messageLabel.text      = "\(subtitle)\n\n\(body)"
        messageLabel.font      = UIFont.systemFont(ofSize: 16, weight: .regular)
        messageLabel.textColor = UIColor.white.withAlphaComponent(0.65)
        messageLabel.textAlignment = .center
        messageLabel.isHidden  = false

        separatorLine.isHidden = false
        hintLabel.text         = hint
        hintLabel.isHidden     = false

        contentStack.spacing   = 16
        contentStack.alignment = .center

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
