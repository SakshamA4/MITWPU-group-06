//
//  OnboardingOverlayViewController.swift
//  FilmsPage — SceneWiz Onboarding
//

import UIKit

/// Fullscreen view controller hosted in a dedicated UIWindow above all app UI.
/// It renders the dim overlay, spotlight cutout, and the animated tooltip card.
final class OnboardingOverlayViewController: UIViewController {

    // MARK: - Subviews

    private let spotlight = OnboardingSpotlight()
    private let tooltip   = OnboardingTooltipView()

    // MARK: - State

    private var currentStep: OnboardingStep?
    private var isFirstShow = true

    /// Tooltip leading/trailing/top/bottom constraint references so we can reposition it.
    private var tooltipCenterX: NSLayoutConstraint?
    private var tooltipTopOrBottom: NSLayoutConstraint?
    private var tooltipWidthConstraint: NSLayoutConstraint?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        // ── Spotlight (full-screen dim + cutout) ──────────────────────────────
        spotlight.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spotlight)
        NSLayoutConstraint.activate([
            spotlight.topAnchor.constraint(equalTo: view.topAnchor),
            spotlight.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            spotlight.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            spotlight.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        // Swallow taps outside the spotlight (non-interactive steps)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleOverlayTap))
        tapGesture.cancelsTouchesInView = false
        spotlight.addGestureRecognizer(tapGesture)

        // ── Tooltip card ──────────────────────────────────────────────────────
        tooltip.translatesAutoresizingMaskIntoConstraints = false
        tooltip.alpha = 0
        tooltip.delegate = self
        view.addSubview(tooltip)

        // Fixed width — responsive but capped
        let tooltipWidth: CGFloat = min(520, view.bounds.width - 80)
        tooltipWidthConstraint = tooltip.widthAnchor.constraint(equalToConstant: tooltipWidth)
        tooltipCenterX         = tooltip.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        // Placeholder bottom anchor (will be repositioned per step)
        tooltipTopOrBottom = tooltip.bottomAnchor.constraint(equalTo: view.centerYAnchor, constant: -40)

        NSLayoutConstraint.activate([
            tooltipWidthConstraint!,
            tooltipCenterX!,
            tooltipTopOrBottom!
        ])
    }

    // MARK: - Public API

    /// Shows a step for the first time or transitions from the current step.
    func show(step: OnboardingStep, spotlightFrame: CGRect) {
        currentStep = step
        tooltip.configure(step: step)

        if isFirstShow {
            isFirstShow = false
            applySpotlight(frame: spotlightFrame, step: step, animated: false)
            positionTooltip(relativeTo: spotlightFrame, step: step, animated: false)
            animateIn()
        } else {
            transition(to: step, spotlightFrame: spotlightFrame)
        }
    }

    /// Transitions the overlay to a new step with a fade + slide animation.
    func transition(to step: OnboardingStep, spotlightFrame: CGRect) {
        UIView.animate(withDuration: 0.18, animations: {
            self.tooltip.alpha = 0
            self.tooltip.transform = CGAffineTransform(translationX: 0, y: 8)
        }) { _ in
            self.currentStep = step
            self.tooltip.configure(step: step)
            self.applySpotlight(frame: spotlightFrame, step: step, animated: true)
            self.positionTooltip(relativeTo: spotlightFrame, step: step, animated: true)

            UIView.animate(
                withDuration: 0.32,
                delay: 0.05,
                usingSpringWithDamping: 0.82,
                initialSpringVelocity: 0.4
            ) {
                self.tooltip.alpha     = 1
                self.tooltip.transform = .identity
            }
        }
    }

    /// Reveals the Next button on the current tooltip (step-9 interaction gate).
    func unlockNextButton() {
        tooltip.revealNextButton()
    }

    /// Fades out the overlay so the manager can destroy the window.
    func dismiss() {
        UIView.animate(withDuration: 0.35) {
            self.view.alpha = 0
        }
    }

    // MARK: - Private

    private func animateIn() {
        tooltip.transform = CGAffineTransform(translationX: 0, y: 20)
        UIView.animate(
            withDuration: 0.5,
            delay: 0.1,
            usingSpringWithDamping: 0.75,
            initialSpringVelocity: 0.5
        ) {
            self.tooltip.alpha     = 1
            self.tooltip.transform = .identity
        }
    }

    private func applySpotlight(frame: CGRect, step: OnboardingStep, animated: Bool) {
        if step.isFullScreenGlow || frame == .zero {
            spotlight.showGlow()
        } else {
            // Inset the spotlight slightly so padding shows around the element
            let padding: CGFloat = 12
            let paddedFrame = frame.insetBy(dx: -padding, dy: -padding)
            spotlight.setHole(rect: paddedFrame, animated: animated)
        }
    }

    private func positionTooltip(relativeTo spotlightFrame: CGRect,
                                 step: OnboardingStep,
                                 animated: Bool) {
        // Deactivate old constraint
        tooltipTopOrBottom?.isActive = false

        let margin: CGFloat = 24
        let screenH = view.bounds.height

        // Default: place tooltip below the spotlight
        var newConstraint: NSLayoutConstraint
        if step.isFullScreenGlow || spotlightFrame == .zero {
            // Centre vertically
            newConstraint = tooltip.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        } else {
            let spottomY = spotlightFrame.maxY + 12
            let tooltipH: CGFloat = 210   // estimated height
            if spottomY + tooltipH + margin < screenH {
                // Below
                newConstraint = tooltip.topAnchor.constraint(
                    equalTo: view.topAnchor,
                    constant: spottomY + margin
                )
            } else {
                // Above
                newConstraint = tooltip.bottomAnchor.constraint(
                    equalTo: view.topAnchor,
                    constant: spotlightFrame.minY - margin
                )
            }
        }

        newConstraint.isActive = true
        tooltipTopOrBottom = newConstraint

        if animated {
            UIView.animate(withDuration: 0.35, delay: 0,
                           usingSpringWithDamping: 0.82,
                           initialSpringVelocity: 0.3) {
                self.view.layoutIfNeeded()
            }
        } else {
            view.layoutIfNeeded()
        }
    }

    @objc private func handleOverlayTap() {
        // Tapping outside does nothing — intentional UX choice.
        // The only actions are Next / Skip buttons inside the tooltip card.
    }
}

// MARK: - OnboardingTooltipDelegate

extension OnboardingOverlayViewController: OnboardingTooltipDelegate {
    func tooltipDidTapNext() {
        OnboardingManager.shared.advance()
    }
    func tooltipDidTapSkip() {
        OnboardingManager.shared.skip()
    }
}
