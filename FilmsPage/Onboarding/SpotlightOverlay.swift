//
//  SpotlightOverlay.swift
//  FilmsPage
//
//  Full-screen UIKit overlay that:
//    • Dims everything outside a spotlight "hole" using CAShapeLayer + .evenOdd fill rule
//    • Displays a TipKit-styled callout bubble above or below the hole
//    • Pulses a glowing border around the spotlighted control
//    • Passes touches through the hole so the user can interact with the real UI
//    • Shows a "Skip" button to exit the tutorial at any point
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
}

// MARK: - SpotlightOverlay

final class SpotlightOverlay: UIView {

    // MARK: Public

    weak var delegate: SpotlightOverlayDelegate?
    /// Weak reference to the spotlighted view; used to recalculate position on layout.
    weak var targetView: UIView?

    // MARK: Private layers & views

    private let dimmingLayer     = CAShapeLayer()
    private let ringLayer        = CALayer()
    private let calloutView      = SpotlightCalloutView()
    private let skipButton       = UIButton(type: .system)
    private let progressLabel    = UILabel()

    // Constraint pairs toggled to place callout above or below spotlight
    private var calloutTopConstraint:    NSLayoutConstraint?
    private var calloutBottomConstraint: NSLayoutConstraint?

    // Current spotlight rect in the overlay's own coordinate space
    private var spotlightRect: CGRect = .zero

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
        dimmingLayer.fillColor = UIColor.black.withAlphaComponent(0.72).cgColor
        dimmingLayer.fillRule  = .evenOdd
        layer.addSublayer(dimmingLayer)
    }

    private func setupRingLayer() {
        ringLayer.borderColor  = UIColor(red: 0.9, green: 0.25, blue: 0.25, alpha: 1).cgColor
        ringLayer.borderWidth  = 2
        ringLayer.opacity      = 0.9
        layer.addSublayer(ringLayer)
    }

    private func setupCallout() {
        calloutView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(calloutView)

        NSLayoutConstraint.activate([
            calloutView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            calloutView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20)
        ])
    }

    private func setupProgressLabel() {
        progressLabel.font        = UIFont.systemFont(ofSize: 12, weight: .semibold)
        progressLabel.textColor   = UIColor.white.withAlphaComponent(0.55)
        progressLabel.textAlignment = .center
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(progressLabel)
    }

    private func setupSkipButton() {
        var cfg = UIButton.Configuration.plain()
        cfg.title                 = "Skip Tutorial"
        cfg.baseForegroundColor   = UIColor.white.withAlphaComponent(0.65)
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var a = attrs
            a.font = UIFont.systemFont(ofSize: 14, weight: .medium)
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

    // MARK: - Public Configuration

    /// Apply all visual state for the given step.
    func configure(
        spotlightFrame: CGRect,
        step: TutorialStep,
        currentStepIndex: Int,
        totalSteps: Int
    ) {
        spotlightRect = spotlightFrame.insetBy(dx: -14, dy: -14)
        let radius: CGFloat = 16

        // Callout content
        calloutView.configure(title: step.stepTitle, message: step.coachMessage)

        // Progress
        progressLabel.text = currentStepIndex > 0
            ? "Step \(currentStepIndex) of \(totalSteps)"
            : ""

        // Dimming path
        updateDimmingPath(radius: radius)

        // Ring
        ringLayer.frame        = spotlightRect
        ringLayer.cornerRadius = radius

        // Position callout + progress label
        updateCalloutPosition()
        updateProgressLabelPosition()

        // Animate ring pulse
        addPulseAnimation()
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
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

        let spaceBelow = bounds.height - spotlightRect.maxY
        let useBelow   = spaceBelow >= 160

        if useBelow {
            calloutTopConstraint = calloutView.topAnchor.constraint(
                equalTo: topAnchor,
                constant: spotlightRect.maxY + 24
            )
            calloutTopConstraint?.isActive = true
            calloutView.arrowPosition      = .top
        } else {
            calloutBottomConstraint = calloutView.bottomAnchor.constraint(
                equalTo: topAnchor,
                constant: spotlightRect.minY - 24
            )
            calloutBottomConstraint?.isActive = true
            calloutView.arrowPosition          = .bottom
        }
    }

    private func updateProgressLabelPosition() {
        progressLabel.sizeToFit()
        let w  = progressLabel.bounds.width
        let h  = progressLabel.bounds.height
        let cx = bounds.midX
        let useBelow = bounds.height - spotlightRect.maxY >= 160
        let y: CGFloat = useBelow
            ? spotlightRect.maxY + 24 + 90
            : spotlightRect.minY - 24 - 90 - h

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
        anim.toValue       = 0.25
        anim.duration      = 0.85
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
        UIView.animate(withDuration: 0.35, delay: 0, options: .curveEaseOut) {
            self.alpha = 1
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

    // MARK: - Hit Testing

    /// Allow taps inside the spotlight hole to fall through to the real UI.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if spotlightRect.contains(point) { return nil }
        return super.hitTest(point, with: event)
    }
}

// MARK: - SpotlightCalloutView

/// A TipKit-inspired callout card that shows a step's title and coach message.
final class SpotlightCalloutView: UIView {

    enum ArrowPosition { case top, bottom }

    // MARK: Properties

    var arrowPosition: ArrowPosition = .top

    // MARK: Private subviews

    private let cardView      = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel    = UILabel()
    private let messageLabel  = UILabel()

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

        // Card
        cardView.backgroundColor = UIColor(red: 0.11, green: 0.11, blue: 0.13, alpha: 0.97)
        cardView.layer.cornerRadius  = 18
        cardView.layer.borderWidth   = 1
        cardView.layer.borderColor   = UIColor.white.withAlphaComponent(0.10).cgColor
        cardView.layer.shadowColor   = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.55
        cardView.layer.shadowRadius  = 14
        cardView.layer.shadowOffset  = CGSize(width: 0, height: 5)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cardView)

        // Icon
        let iconCfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        iconImageView.image            = UIImage(systemName: "lightbulb.fill", withConfiguration: iconCfg)
        iconImageView.tintColor        = UIColor.systemYellow
        iconImageView.contentMode      = .scaleAspectFit
        iconImageView.setContentHuggingPriority(.required, for: .horizontal)
        iconImageView.translatesAutoresizingMaskIntoConstraints = false

        // Title
        titleLabel.font            = UIFont.systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor       = .white
        titleLabel.numberOfLines   = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Message
        messageLabel.font          = UIFont.systemFont(ofSize: 13, weight: .regular)
        messageLabel.textColor     = UIColor.white.withAlphaComponent(0.72)
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false

        // Header row
        let headerStack = UIStackView(arrangedSubviews: [iconImageView, titleLabel])
        headerStack.axis      = .horizontal
        headerStack.spacing   = 8
        headerStack.alignment = .center
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        // Content stack
        let contentStack = UIStackView(arrangedSubviews: [headerStack, messageLabel])
        contentStack.axis      = .vertical
        contentStack.spacing   = 7
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            // Card fills self (with 8 pt top/bottom for the callout arrow zone)
            cardView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            cardView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor),

            // Content insets
            contentStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            contentStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16),
            contentStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 18),
            contentStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -18),

            iconImageView.widthAnchor.constraint(equalToConstant: 22),
            iconImageView.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    // MARK: - Configuration

    func configure(title: String, message: String) {
        titleLabel.text         = title
        messageLabel.text       = message
        messageLabel.isHidden   = message.isEmpty
    }
}
