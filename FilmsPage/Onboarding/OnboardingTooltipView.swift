//
//  OnboardingTooltipView.swift
//  FilmsPage — SceneWiz Onboarding
//

import UIKit

// MARK: - Delegate

protocol OnboardingTooltipDelegate: AnyObject {
    func tooltipDidTapNext()
    func tooltipDidTapSkip()
}

// MARK: - OnboardingTooltipView

/// Glass-morphism tooltip card used in the onboarding overlay.
final class OnboardingTooltipView: UIView {

    // MARK: - Accent color

    private let accentColor = UIColor.white

    // MARK: - Subviews

    private let blurView       = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let tintOverlay    = UIView()
    private let accentLine     = UIView()
    private let headingLabel   = UILabel()
    private let subtextLabel   = UILabel()
    private let dotsStack      = UIStackView()
    private let nextButton     = UIButton(type: .system)
    private let skipButton     = UIButton(type: .system)

    // MARK: - State

    private var totalSteps: Int = 11
    weak var delegate: OnboardingTooltipDelegate?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setup() {
        layer.cornerRadius = 20
        clipsToBounds = false
        layer.shadowColor   = UIColor.black.cgColor
        layer.shadowOpacity = 0.5
        layer.shadowRadius  = 24
        layer.shadowOffset  = CGSize(width: 0, height: 8)

        // ── Blur + tint background ────────────────────────────────────────────
        blurView.layer.cornerRadius = 20
        blurView.clipsToBounds      = true
        blurView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(blurView)

        tintOverlay.backgroundColor = UIColor(red: 14/255, green: 14/255, blue: 26/255, alpha: 0.72)
        tintOverlay.translatesAutoresizingMaskIntoConstraints = false
        addSubview(tintOverlay)

        // ── Top accent line ─────────────────────────────────────────────
        accentLine.backgroundColor = accentColor
        accentLine.layer.cornerRadius = 1
        accentLine.translatesAutoresizingMaskIntoConstraints = false
        addSubview(accentLine)

        // ── Heading ──────────────────────────────────────────────────────────
        headingLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        headingLabel.textColor = .white
        headingLabel.numberOfLines = 0
        headingLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(headingLabel)

        // ── Subtext ──────────────────────────────────────────────────────────
        subtextLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        subtextLabel.textColor = UIColor.white.withAlphaComponent(0.78)
        subtextLabel.numberOfLines = 0
        subtextLabel.lineBreakMode = .byWordWrapping
        subtextLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subtextLabel)

        // ── Progress dots ─────────────────────────────────────────────────────
        dotsStack.axis = .horizontal
        dotsStack.spacing = 6
        dotsStack.alignment = .center
        dotsStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dotsStack)

        // ── Next button ──────────────────────────────────────────────────────
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        styleNextButton(label: "Next →")
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        addSubview(nextButton)

        // ── Skip button ───────────────────────────────────────────────────────
        skipButton.setTitle("Skip", for: .normal)
        skipButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        skipButton.setTitleColor(UIColor.white.withAlphaComponent(0.5), for: .normal)
        skipButton.translatesAutoresizingMaskIntoConstraints = false
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        addSubview(skipButton)

        // ── Constraints ───────────────────────────────────────────────────────
        NSLayoutConstraint.activate([
            // Blur fills the card
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),

            // Tint fills the card
            tintOverlay.topAnchor.constraint(equalTo: topAnchor),
            tintOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),
            tintOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            tintOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),

            // Amber top line
            accentLine.topAnchor.constraint(equalTo: topAnchor),
            accentLine.leadingAnchor.constraint(equalTo: leadingAnchor),
            accentLine.trailingAnchor.constraint(equalTo: trailingAnchor),
            accentLine.heightAnchor.constraint(equalToConstant: 2.5),

            // Skip (top-right)
            skipButton.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            skipButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            // Heading
            headingLabel.topAnchor.constraint(equalTo: accentLine.bottomAnchor, constant: 20),
            headingLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            headingLabel.trailingAnchor.constraint(equalTo: skipButton.leadingAnchor, constant: -8),

            // Subtext
            subtextLabel.topAnchor.constraint(equalTo: headingLabel.bottomAnchor, constant: 10),
            subtextLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            subtextLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),

            // Dots
            dotsStack.topAnchor.constraint(equalTo: subtextLabel.bottomAnchor, constant: 20),
            dotsStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            dotsStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -22),

            // Next button
            nextButton.centerYAnchor.constraint(equalTo: dotsStack.centerYAnchor),
            nextButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
            nextButton.heightAnchor.constraint(equalToConstant: 40)
        ])

        buildDots(count: 11, current: 0)
    }

    // MARK: - Configuration

    func configure(step: OnboardingStep) {
        headingLabel.text = step.heading
        subtextLabel.text = step.subtext
        styleNextButton(label: step.nextButtonLabel)
        skipButton.isHidden = (step.stepIndex == OnboardingStep.allSteps.count - 1)
        buildDots(count: OnboardingStep.allSteps.count, current: step.stepIndex)

        if step.isInteractive {
            nextButton.isHidden = true
            nextButton.alpha    = 0
        } else {
            nextButton.isHidden = false
            nextButton.alpha    = 1
        }
    }

    /// Reveals the Next button (used when interaction requirement is satisfied).
    func revealNextButton() {
        nextButton.isHidden = false
        UIView.animate(withDuration: 0.3) {
            self.nextButton.alpha = 1
        }
    }

    // MARK: - Private Helpers

    private func styleNextButton(label: String) {
        var cfg = UIButton.Configuration.filled()
        cfg.title               = label
        cfg.baseForegroundColor = .black
        cfg.baseBackgroundColor = accentColor
        cfg.cornerStyle         = .medium
        cfg.contentInsets       = NSDirectionalEdgeInsets(top: 9, leading: 20, bottom: 9, trailing: 20)
        cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var a = attrs
            a.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
            return a
        }
        nextButton.configuration = cfg
    }

    private func buildDots(count: Int, current: Int) {
        dotsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for i in 0..<count {
            let dot = UIView()
            dot.layer.cornerRadius = 4
            if i < current {
                // Past
                dot.backgroundColor = accentColor.withAlphaComponent(0.45)
                dot.widthAnchor.constraint(equalToConstant: 6).isActive  = true
                dot.heightAnchor.constraint(equalToConstant: 6).isActive = true
            } else if i == current {
                // Current — larger dot
                dot.backgroundColor = accentColor
                dot.widthAnchor.constraint(equalToConstant: 10).isActive  = true
                dot.heightAnchor.constraint(equalToConstant: 8).isActive  = true
                dot.layer.cornerRadius = 4
            } else {
                // Future
                dot.backgroundColor = UIColor.white.withAlphaComponent(0.2)
                dot.widthAnchor.constraint(equalToConstant: 6).isActive  = true
                dot.heightAnchor.constraint(equalToConstant: 6).isActive = true
            }
            dot.layer.cornerRadius = (i == current) ? 4 : 3
            dotsStack.addArrangedSubview(dot)
        }
    }

    // MARK: - Actions

    @objc private func nextTapped() { delegate?.tooltipDidTapNext() }
    @objc private func skipTapped() { delegate?.tooltipDidTapSkip() }
}
