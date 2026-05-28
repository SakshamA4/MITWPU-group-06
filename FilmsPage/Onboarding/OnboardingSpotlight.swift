//
//  OnboardingSpotlight.swift
//  FilmsPage — SceneWiz Onboarding
//

import UIKit

/// A `UIView` subclass that renders a full-screen dark overlay with a
/// transparent rectangular "spotlight" cutout.  The cutout has an animated
/// pulsing corner radius and an amber stroke ring.
final class OnboardingSpotlight: UIView {

    // MARK: - Constants

    private let amber = UIColor.white

    // MARK: - Layers

    /// The dark overlay layer.
    private let dimLayer    = CALayer()
    /// The mask layer that punches the cutout hole using the even-odd fill rule.
    private let maskShape   = CAShapeLayer()
    /// The amber stroke ring drawn around the cutout edge.
    private let ringLayer   = CAShapeLayer()
    /// The inner glow layer for the full-screen "glow" steps.
    private let glowLayer   = CAGradientLayer()

    // MARK: - State

    /// The frame of the hole in the overlay.
    private(set) var currentHoleRect: CGRect = .zero
    private var isGlowMode: Bool = false

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setup() {
        backgroundColor = .clear
        isUserInteractionEnabled = false

        // ── Overlay dim layer ────────────────────────────────────────────────
        dimLayer.backgroundColor = UIColor(white: 0, alpha: 0.78).cgColor
        dimLayer.frame = bounds
        layer.addSublayer(dimLayer)

        // ── Mask that cuts the hole in the dim layer ─────────────────────────
        maskShape.fillRule = .evenOdd
        maskShape.fillColor = UIColor.black.cgColor     // colour doesn't matter — mask uses alpha
        dimLayer.mask = maskShape

        // ── Amber stroke ring ─────────────────────────────────────────────────
        ringLayer.fillColor   = UIColor.clear.cgColor
        ringLayer.strokeColor = amber.withAlphaComponent(0.85).cgColor
        ringLayer.lineWidth   = 2.5
        layer.addSublayer(ringLayer)

        // ── Radial glow for Welcome / Finale steps ────────────────────────────
        glowLayer.type   = .radial
        glowLayer.colors = [
            amber.withAlphaComponent(0.22).cgColor,
            UIColor.clear.cgColor
        ]
        glowLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        glowLayer.endPoint   = CGPoint(x: 1, y: 1)
        glowLayer.isHidden   = true
        layer.addSublayer(glowLayer)
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        dimLayer.frame = bounds
        maskShape.frame = bounds
        updateHole(rect: currentHoleRect, animated: false)
        if isGlowMode { layoutGlow() }
    }

    // MARK: - Public Interface

    /// Animates the spotlight cutout to a new rect.
    /// Pass `CGRect.zero` (or call `showGlow()`) for a full-screen glow step.
    func setHole(rect: CGRect, animated: Bool, cornerRadius: CGFloat = 20) {
        isGlowMode   = false
        glowLayer.isHidden = true
        ringLayer.isHidden = rect == .zero

        let newPath = holePath(holeRect: rect, cornerRadius: cornerRadius)

        if animated && currentHoleRect != .zero {
            let anim = CABasicAnimation(keyPath: "path")
            anim.fromValue  = maskShape.path
            anim.toValue    = newPath
            anim.duration   = 0.35
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            maskShape.add(anim, forKey: "pathTransition")

            // Ring
            let ringAnim = CABasicAnimation(keyPath: "path")
            ringAnim.fromValue  = ringLayer.path
            ringAnim.toValue    = ringPath(holeRect: rect, cornerRadius: cornerRadius)
            ringAnim.duration   = 0.35
            ringAnim.timingFunction = anim.timingFunction
            ringLayer.add(ringAnim, forKey: "ringTransition")
        }

        maskShape.path = newPath
        ringLayer.path = ringPath(holeRect: rect, cornerRadius: cornerRadius)
        currentHoleRect = rect

        // Pulse the corner radius continuously
        startPulseAnimation(on: ringLayer, baseRadius: cornerRadius)
    }

    /// Switches to full-screen ambient glow mode (no cutout).
    func showGlow() {
        isGlowMode = true
        // Remove the cutout — fill the mask with one big rect (no hole)
        let path = UIBezierPath(rect: bounds)
        maskShape.path = path.cgPath
        ringLayer.isHidden   = true
        glowLayer.isHidden   = false
        layoutGlow()
        startGlowPulse()
    }

    // MARK: - Private Helpers

    private func updateHole(rect: CGRect, animated: Bool) {
        guard !isGlowMode else { layoutGlow(); return }
        guard rect != .zero else {
            let full = UIBezierPath(rect: bounds)
            maskShape.path = full.cgPath
            return
        }
        maskShape.path  = holePath(holeRect: rect, cornerRadius: 20)
        ringLayer.path  = ringPath(holeRect: rect, cornerRadius: 20)
    }

    private func holePath(holeRect: CGRect, cornerRadius: CGFloat) -> CGPath {
        let path = UIBezierPath(rect: bounds)
        let hole = UIBezierPath(roundedRect: holeRect, cornerRadius: cornerRadius)
        path.append(hole)
        path.usesEvenOddFillRule = true
        return path.cgPath
    }

    private func ringPath(holeRect: CGRect, cornerRadius: CGFloat) -> CGPath {
        return UIBezierPath(roundedRect: holeRect, cornerRadius: cornerRadius).cgPath
    }

    private func layoutGlow() {
        let size  = min(bounds.width, bounds.height) * 0.9
        let x     = (bounds.width  - size) / 2
        let y     = (bounds.height - size) / 2
        glowLayer.frame = CGRect(x: x, y: y, width: size, height: size)
    }

    // MARK: - Animations

    private func startPulseAnimation(on layer: CAShapeLayer, baseRadius: CGFloat) {
        layer.removeAnimation(forKey: "pulse")
        // We pulse the stroke color alpha slightly
        let pulse = CAKeyframeAnimation(keyPath: "strokeColor")
        pulse.values = [
            amber.withAlphaComponent(0.55).cgColor,
            amber.withAlphaComponent(1.0).cgColor,
            amber.withAlphaComponent(0.55).cgColor
        ]
        pulse.keyTimes   = [0, 0.5, 1]
        pulse.duration   = 1.4
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(pulse, forKey: "pulse")
    }

    private func startGlowPulse() {
        glowLayer.removeAnimation(forKey: "glow")
        let pulse = CAKeyframeAnimation(keyPath: "opacity")
        pulse.values   = [0.7, 1.0, 0.7]
        pulse.keyTimes = [0, 0.5, 1]
        pulse.duration = 2.0
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        glowLayer.add(pulse, forKey: "glow")
    }
}
