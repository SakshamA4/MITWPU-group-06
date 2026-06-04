//
//  TutorialManager.swift
//  FilmsPage
//
//  Singleton that orchestrates the entire mandatory pre-canvas onboarding flow.
//
//  Responsibilities
//  ─────────────────
//  • Persists current step via UserDefaults (resume after relaunch).
//  • Drives tab-bar navigation between Home ↔ Films when steps require it.
//  • Activates / deactivates TipKit @Parameter rules so TipKit properly tracks
//    which tips have been shown (supports restart via Tips.resetDatastore()).
//  • Owns the SpotlightOverlay instance shown in the key window.
//  • Exposes a clean, event-driven API for ViewControllers:
//      showSpotlightIfNeeded(targeting:for:)
//      handleHomeSceneCreated(_:)
//      handleFilmCreated(_:)
//      handleSequenceCreated(_:)
//      handleSceneCreatedInSequence(_:)
//      handleSceneTappedOnHome()
//      skipOnboarding()
//      restartOnboarding()
//

import UIKit
import TipKit

// MARK: - TutorialManager

final class TutorialManager: NSObject {

    // MARK: - Singleton

    static let shared = TutorialManager()

    // MARK: - Persisted State

    private(set) var currentStep: TutorialStep {
        get {
            TutorialStep(rawValue: UserDefaults.standard.integer(forKey: StorageKeys.tutorialStep))
                ?? .notStarted
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: StorageKeys.tutorialStep) }
    }

    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: StorageKeys.tutorialCompleted) }
        set { UserDefaults.standard.set(newValue, forKey: StorageKeys.tutorialCompleted) }
    }

    private(set) var tutorialFilmID: UUID? {
        get {
            UserDefaults.standard.string(forKey: StorageKeys.tutorialFilmID)
                .flatMap { UUID(uuidString: $0) }
        }
        set { UserDefaults.standard.set(newValue?.uuidString, forKey: StorageKeys.tutorialFilmID) }
    }

    private(set) var tutorialSequenceID: UUID? {
        get {
            UserDefaults.standard.string(forKey: StorageKeys.tutorialSequenceID)
                .flatMap { UUID(uuidString: $0) }
        }
        set { UserDefaults.standard.set(newValue?.uuidString, forKey: StorageKeys.tutorialSequenceID) }
    }

    // MARK: - Private State

    private var currentOverlay: SpotlightOverlay?
    private var isOverlayVisible: Bool { currentOverlay?.superview != nil }
    /// Tracks whether the welcome overlay ("Welcome to SceneWiz") has been shown this session.
    private var hasShownWelcomeOverlay = false

    // MARK: - Init

    private override init() { super.init() }

    // MARK: - Entry Points

    /// Call from SceneDelegate after the root view controller is visible.
    func startOnboardingIfNeeded() {
        guard !hasCompletedOnboarding else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            guard let self else { return }
            if self.currentStep == .notStarted {
                self.showWelcomeModal()
            } else {
                // Resume from an interrupted session
                self.broadcastStep(self.currentStep)
            }
        }
    }

    // MARK: - Public API

    /// Advance to `step`, update TipKit parameters, navigate if needed, and
    /// broadcast the change so every registered VC can react.
    func advance(to step: TutorialStep) {
        currentStep = step
        PreCanvasTips.activate(for: step)
        dismissCurrentOverlay(animated: true) { [weak self] in
            guard let self else { return }

            // On the very first step, show a full-screen welcome overlay first.
            if step == .homeCreateScene && !self.hasShownWelcomeOverlay {
                self.hasShownWelcomeOverlay = true
                self.showWelcomeOverlay()
                return
            }

            self.handleNavigation(for: step)
        }
    }

    /// Show a spotlight for `step` anchored to `targetView` — no-op if the
    /// current step doesn't match or an overlay is already on screen.
    func showSpotlightIfNeeded(targeting targetView: UIView, for step: TutorialStep) {
        guard currentStep == step,
              !hasCompletedOnboarding,
              !isOverlayVisible,
              let window = keyWindow else { return }

        let overlay = SpotlightOverlay()
        overlay.targetView = targetView
        overlay.delegate   = self

        let frame = targetView.convert(targetView.bounds, to: window)
        overlay.configure(
            spotlightFrame: frame,
            step: step,
            currentStepIndex: step.displayIndex,
            totalSteps: 6
        )
        overlay.show(in: window)
        currentOverlay = overlay
    }

    /// Skip the entire tutorial immediately.
    func skipOnboarding() {
        dismissCurrentOverlay(animated: true)
        PreCanvasTips.deactivateAll()
        markCompleted()
    }

    /// Reset all persisted state and restart from the welcome screen.
    func restartOnboarding() {
        currentStep            = .notStarted
        hasCompletedOnboarding = false
        tutorialFilmID         = nil
        tutorialSequenceID     = nil
        UserDefaults.standard.removeObject(forKey: StorageKeys.tutorialStep)

        try? Tips.resetDatastore()
        try? Tips.configure([.displayFrequency(.immediate)])

        dismissCurrentOverlay(animated: true) { [weak self] in
            self?.showWelcomeModal()
        }
    }

    // MARK: - Event Handlers (called by ViewControllers)

    /// Called when the user taps the "+" nav bar button during step 1.
    func handlePlusButtonTapped() {
        guard currentStep == .homeCreateScene else { return }
        // Dismiss the spotlight on "+" so the popover can appear cleanly.
        dismissCurrentOverlay(animated: true) {
            TutorialManager.shared.advance(to: .tapNewSceneButton)
        }
    }

    /// Called by AddSceneToLibrarayViewController when a scene is saved from the Home tab.
    func handleHomeSceneCreated(_ scene: ScenesModel) {
        guard currentStep == .homeCreateScene || currentStep == .tapNewSceneButton else { return }
        advance(to: .createFilm)
    }

    /// Called by AddFilmViewController when a film is saved successfully.
    func handleFilmCreated(_ film: Film) {
        guard currentStep == .createFilm || currentStep == .filmNaming else { return }
        tutorialFilmID = film.id
        advance(to: .createSequence)
    }

    /// Called by AddSequenceViewController when a sequence is saved.
    func handleSequenceCreated(_ sequence: Sequence) {
        guard currentStep == .createSequence else { return }
        tutorialSequenceID = sequence.id
        advance(to: .createSceneInSequence)
    }

    /// Called by AddSceneViewController when a scene is saved inside a sequence.
    func handleSceneCreatedInSequence(_ scene: Scene) {
        guard currentStep == .createSceneInSequence else { return }
        advance(to: .returnToHomeHighlight)
    }

    /// Called by HomeViewController when the user taps a scene card during Step 7.
    func handleSceneTappedOnHome() {
        guard currentStep == .enterScene else { return }
        advance(to: .completed)
    }

    /// Called by CanvasViewController on `viewDidAppear` to complete the handoff.
    func markPreCanvasTutorialCompleted() {
        markCompleted()
    }

    // MARK: - Navigation

    private func handleNavigation(for step: TutorialStep) {
        switch step {

        case .homeCreateScene:
            switchToTab(0) { [weak self] in
                self?.broadcastStep(step)
            }

        case .tapNewSceneButton:
            // The popover is already visible — just broadcast so
            // AddSceneOrFilmViewController can spotlight the "New Scene" button.
            broadcastStep(step)

        case .createFilm:
            switchToTab(1) { [weak self] in
                self?.broadcastStep(step)
            }

        case .createSequence:
            // Switch to Films tab, then tell FilmsViewController to push MyFilmVC
            switchToTab(1) { [weak self] in
                guard let self, let filmID = self.tutorialFilmID else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    NotificationCenter.default.post(
                        name: NSNotification.Name(NotificationNames.tutorialNavigateToFilm),
                        object: nil,
                        userInfo: ["filmID": filmID.uuidString]
                    )
                    self.broadcastStep(step)
                }
            }

        case .createSceneInSequence:
            // Tell MyFilmViewController to push SequenceVC for the tutorial sequence
            guard let seqID = tutorialSequenceID else { broadcastStep(step); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                NotificationCenter.default.post(
                    name: NSNotification.Name(NotificationNames.tutorialNavigateToSequence),
                    object: nil,
                    userInfo: ["sequenceID": seqID.uuidString]
                )
                self?.broadcastStep(step)
            }

        case .returnToHomeHighlight, .enterScene:
            switchToTab(0) { [weak self] in
                self?.broadcastStep(step)
            }

        case .completed:
            PreCanvasTips.deactivateAll()
            markCompleted()
            broadcastStep(step)

        default:
            broadcastStep(step)
        }
    }

    // MARK: - Broadcast

    private func broadcastStep(_ step: TutorialStep) {
        NotificationCenter.default.post(
            name: NSNotification.Name(NotificationNames.tutorialStepChanged),
            object: nil,
            userInfo: ["step": step.rawValue]
        )
    }

    // MARK: - Welcome Overlay

    private func showWelcomeOverlay() {
        guard let window = keyWindow else {
            // Fallback: skip the welcome and go straight to navigation.
            handleNavigation(for: currentStep)
            return
        }

        let overlay = SpotlightOverlay()
        overlay.delegate = self
        overlay.configureWelcomeMode()
        overlay.show(in: window)
        currentOverlay = overlay
    }

    // MARK: - Overlay Lifecycle

    private func dismissCurrentOverlay(animated: Bool = true, completion: (() -> Void)? = nil) {
        guard let overlay = currentOverlay else {
            completion?()
            return
        }
        overlay.dismiss(animated: animated) { [weak self] in
            self?.currentOverlay = nil
            completion?()
        }
    }

    // MARK: - Tab Navigation

    private func switchToTab(_ index: Int, completion: @escaping () -> Void) {
        guard let tab = tabBarController else { completion(); return }
        if tab.selectedIndex == index {
            completion()
        } else {
            tab.selectedIndex = index
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: completion)
        }
    }

    // MARK: - Welcome Modal

    private func showWelcomeModal() {
        guard let root = tabBarController else { return }
        let vc = OnboardingWelcomeViewController()
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle   = .crossDissolve

        func present() { root.present(vc, animated: true) }

        if let presented = root.presentedViewController {
            presented.dismiss(animated: false, completion: present)
        } else {
            present()
        }
    }

    // MARK: - Completion

    private func markCompleted() {
        currentStep            = .completed
        hasCompletedOnboarding = true
        PreCanvasTips.deactivateAll()
        NotificationCenter.default.post(
            name: NSNotification.Name(NotificationNames.tutorialStepChanged),
            object: nil,
            userInfo: ["step": TutorialStep.completed.rawValue]
        )
    }

    // MARK: - Helpers

    private var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }

    private var tabBarController: UITabBarController? {
        keyWindow?.rootViewController as? UITabBarController
    }
}

// MARK: - SpotlightOverlayDelegate

extension TutorialManager: SpotlightOverlayDelegate {
    func spotlightOverlayDidRequestSkip(_ overlay: SpotlightOverlay) {
        skipOnboarding()
    }

    func spotlightOverlayDidDismissWelcome(_ overlay: SpotlightOverlay) {
        // Dismiss the welcome overlay, then proceed to the actual spotlight step.
        dismissCurrentOverlay(animated: true) { [weak self] in
            guard let self else { return }
            self.handleNavigation(for: self.currentStep)
        }
    }
}
