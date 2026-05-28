//
//  OnboardingManager.swift
//  FilmsPage — SceneWiz Onboarding
//

import UIKit

// MARK: - Notification Names

extension Notification.Name {
    /// Posted by each VC in viewDidAppear so the manager knows which screen is live.
    static let onboardingVCAppeared     = Notification.Name("onboardingVCAppeared")
    /// Posted by CanvasViewController's gesture handler when a prop is moved/rotated.
    static let onboardingGestureDetected = Notification.Name("onboardingGestureDetected")
    /// Posted internally when a step should advance.
    static let onboardingAdvanceStep    = Notification.Name("onboardingAdvanceStep")
}

// MARK: - UserDefaults Keys

private enum OnboardingDefaults {
    static let hasSeenOnboarding    = "hasSeenOnboarding"
    static let savedStepIndex       = "onboardingSavedStepIndex"
}

// MARK: - OnboardingManager

/// Singleton that owns the onboarding overlay window and drives step transitions.
final class OnboardingManager {

    static let shared = OnboardingManager()
    private init() {}

    // MARK: - State

    private(set) var currentStepIndex: Int = 0
    private(set) var isActive: Bool = false

    /// The dedicated UIWindow that hosts the overlay.
    private var overlayWindow: UIWindow?
    private var overlayVC: OnboardingOverlayViewController?

    // MARK: - Public API

    /// Call from SceneDelegate after makeKeyAndVisible(). Shows the walkthrough only on first launch.
    func startIfNeeded(from window: UIWindow) {
        guard !UserDefaults.standard.bool(forKey: OnboardingDefaults.hasSeenOnboarding) else { return }
        let savedIndex = UserDefaults.standard.integer(forKey: OnboardingDefaults.savedStepIndex)
        currentStepIndex = savedIndex
        start(from: window)
    }

    /// Resets to step 0 and starts the walkthrough regardless of the stored flag.
    /// Called from the Profile "Replay Tutorial" row.
    func replayTutorial(from window: UIWindow) {
        currentStepIndex = 0
        UserDefaults.standard.set(0, forKey: OnboardingDefaults.savedStepIndex)
        start(from: window)
    }

    /// Advances to the next step.
    func advance() {
        guard isActive else { return }
        let nextIndex = currentStepIndex + 1
        if nextIndex >= OnboardingStep.allSteps.count {
            complete()
        } else {
            currentStepIndex = nextIndex
            showCurrentStep()
        }
    }

    /// Saves progress and dismisses the overlay. The user can resume from Profile.
    func skip() {
        guard isActive else { return }
        UserDefaults.standard.set(currentStepIndex, forKey: OnboardingDefaults.savedStepIndex)
        dismissOverlay()
    }

    /// Marks the tutorial as fully completed and dismisses the overlay.
    func complete() {
        UserDefaults.standard.set(true, forKey: OnboardingDefaults.hasSeenOnboarding)
        UserDefaults.standard.set(0, forKey: OnboardingDefaults.savedStepIndex)
        dismissOverlay()
    }

    // MARK: - Private Helpers

    private func start(from window: UIWindow) {
        guard !isActive else { return }
        isActive = true
        createOverlayWindow(relativeTo: window)
        showCurrentStep()
        observeNotifications()
    }

    private func createOverlayWindow(relativeTo keyWindow: UIWindow) {
        guard let windowScene = keyWindow.windowScene else { return }

        let vc = OnboardingOverlayViewController()
        overlayVC = vc

        let window = UIWindow(windowScene: windowScene)
        window.windowLevel = UIWindow.Level.statusBar + 1
        window.rootViewController = vc
        window.makeKeyAndVisible()
        overlayWindow = window
    }

    private func showCurrentStep() {
        guard currentStepIndex < OnboardingStep.allSteps.count else { complete(); return }
        let step = OnboardingStep.allSteps[currentStepIndex]
        let spotlightFrame = spotlightRect(for: step)
        DispatchQueue.main.async { [weak self] in
            self?.overlayVC?.show(step: step, spotlightFrame: spotlightFrame)
        }
    }

    private func dismissOverlay() {
        isActive = false
        overlayVC?.dismiss()
        // A brief delay so the fade-out animation finishes before we nuke the window.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            self?.overlayWindow?.isHidden = true
            self?.overlayWindow = nil
            self?.overlayVC = nil
        }
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Element Frame Resolution

    /// Walks the entire *app* view hierarchy (all windows) to find the view with
    /// the given accessibility identifier and returns its frame in screen coordinates.
    private func spotlightRect(for step: OnboardingStep) -> CGRect {
        guard let id = step.targetElementID else { return .zero }
        // Search all windows except our own overlay window
        for window in UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            where window !== overlayWindow {
                if let frame = findFrame(ofViewWithID: id, in: window) {
                    return frame
                }
        }
        return .zero
    }

    private func findFrame(ofViewWithID id: String, in view: UIView) -> CGRect? {
        if view.accessibilityIdentifier == id {
            // Convert to screen coordinates
            guard let keyWindow = overlayWindow else { return nil }
            return view.convert(view.bounds, to: keyWindow)
        }
        
        // Fallback for iPadOS sidebar tabs (or other hidden elements) that use accessibilityLabel instead
        if view.accessibilityLabel == id && view.isUserInteractionEnabled && !(view is UILabel) {
            guard let keyWindow = overlayWindow else { return nil }
            return view.convert(view.bounds, to: keyWindow)
        }
        
        for subview in view.subviews {
            if let found = findFrame(ofViewWithID: id, in: subview) {
                return found
            }
        }
        return nil
    }

    // MARK: - Notification Observation

    private func observeNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleGestureDetected),
            name: .onboardingGestureDetected,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVCAppeared(_:)),
            name: .onboardingVCAppeared,
            object: nil
        )
    }

    @objc private func handleVCAppeared(_ notification: Notification) {
        guard isActive,
              currentStepIndex < OnboardingStep.allSteps.count,
              let userInfo = notification.userInfo,
              let vcType = userInfo["vcType"] as? String else { return }
        
        let step = OnboardingStep.allSteps[currentStepIndex]
        
        // If the VC that just appeared matches what this step is waiting for, automatically advance!
        if step.autoAdvancesOnVC == vcType {
            // Add a tiny delay so the navigation animation can finish before we move the spotlight
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.advance()
            }
        }
    }

    @objc private func handleGestureDetected() {
        // Step 11 requires a real interaction before Next is unlocked (or we can just advance!)
        guard isActive,
              currentStepIndex == 11 else { return }
              
        // We can just automatically advance when they move the prop since it's fully interactive!
        DispatchQueue.main.async { [weak self] in
            self?.advance()
        }
    }
}
