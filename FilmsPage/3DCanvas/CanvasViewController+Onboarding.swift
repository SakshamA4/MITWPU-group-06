//
//  CanvasViewController+Onboarding.swift
//  FilmsPage — SceneWiz Onboarding
//
//  Thin extension for onboarding-related concerns on the canvas.
//  Keeps all onboarding code isolated from core canvas logic.
//

import UIKit

extension CanvasViewController {

    /// Call this from any entity gesture handler (drag, ring-rotate, etc.).
    /// When the onboarding is on Step 9 (the "interact with a prop" step),
    /// it posts the notification that unlocks the Next button on the tooltip card.
    func reportOnboardingPropGestureIfNeeded() {
        guard OnboardingManager.shared.isActive,
              OnboardingManager.shared.currentStepIndex == 9 else { return }
        // Post once — the manager will unlock the button and ignore subsequent calls.
        NotificationCenter.default.post(name: .onboardingGestureDetected, object: nil)
    }
}
