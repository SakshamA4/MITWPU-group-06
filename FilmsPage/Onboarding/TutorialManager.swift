//
//  TutorialManager.swift
//  FilmsPage
//
//  Singleton that orchestrates the entire mandatory pre-canvas onboarding flow.
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
    private var hasShownWelcomeOverlay = false

    private let totalSteps = 7   // display total for progress label

    // MARK: - Init

    private override init() { super.init() }

    // MARK: - Entry Points

    func startOnboardingIfNeeded() {
        guard !hasCompletedOnboarding else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            guard let self else { return }
            if self.currentStep == .notStarted {
                self.showWelcomeModal()
            } else {
                self.broadcastStep(self.currentStep)
            }
        }
    }

    // MARK: - Public API

    func advance(to step: TutorialStep) {
        currentStep = step
        PreCanvasTips.activate(for: step)
        dismissCurrentOverlay(animated: true) { [weak self] in
            guard let self else { return }

            if step == .homeCreateScene && !self.hasShownWelcomeOverlay {
                self.hasShownWelcomeOverlay = true
                self.showWelcomeOverlay()
                return
            }

            self.handleNavigation(for: step)
        }
    }

    /// Standard spotlight — touches pass through the hole.
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
            totalSteps: totalSteps
        )
        overlay.show(in: window)
        currentOverlay = overlay
    }

    /// Showcase spotlight — spotlight visible but touches BLOCKED, tap to continue.
    func showShowcaseIfNeeded(targeting targetView: UIView, for step: TutorialStep) {
        guard currentStep == step,
              !hasCompletedOnboarding,
              !isOverlayVisible,
              let window = keyWindow else { return }

        let overlay = SpotlightOverlay()
        overlay.targetView = targetView
        overlay.delegate   = self

        let frame = targetView.convert(targetView.bounds, to: window)
        overlay.configureShowcase(
            spotlightFrame: frame,
            step: step,
            currentStepIndex: step.displayIndex,
            totalSteps: totalSteps
        )
        overlay.show(in: window)
        currentOverlay = overlay
    }

    /// Full-dim hint — no spotlight hole, centered card, tap to continue.
    func showHint(for step: TutorialStep) {
        guard !isOverlayVisible,
              let window = keyWindow else { return }

        let overlay = SpotlightOverlay()
        overlay.delegate = self
        overlay.configureHint(
            title: step.stepTitle,
            message: step.coachMessage,
            stepIndex: step.displayIndex,
            totalSteps: totalSteps
        )
        overlay.show(in: window)
        currentOverlay = overlay
    }

    func skipOnboarding() {
        dismissCurrentOverlay(animated: true)
        PreCanvasTips.deactivateAll()
        markCompleted()
    }

    func restartOnboarding() {
        currentStep            = .notStarted
        hasCompletedOnboarding = false
        tutorialFilmID         = nil
        tutorialSequenceID     = nil
        hasShownWelcomeOverlay = false
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
        dismissCurrentOverlay(animated: true) {
            TutorialManager.shared.advance(to: .tapNewSceneButton)
        }
    }

    /// Called by AddSceneToLibrarayViewController when a scene is saved from the Home tab.
    func handleHomeSceneCreated(_ scene: ScenesModel) {
        guard currentStep == .homeCreateScene || currentStep == .tapNewSceneButton else { return }
        advance(to: .showRecentScene)
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
        advance(to: .canvasHint)
    }

    /// Called by HomeViewController when the user taps a template during highlightTemplate step.
    func handleTemplateTappedOnHome() {
        guard currentStep == .highlightTemplate else { return }
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
            broadcastStep(step)

        case .showRecentScene:
            // Switch to Home tab, wait for collection view to reload, then broadcast
            switchToTab(0) { [weak self] in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.broadcastStep(step)
                }
            }

        case .createFilm:
            switchToTab(1) { [weak self] in
                self?.broadcastStep(step)
            }

        case .createSequence:
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
            guard let seqID = tutorialSequenceID else { broadcastStep(step); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                NotificationCenter.default.post(
                    name: NSNotification.Name(NotificationNames.tutorialNavigateToSequence),
                    object: nil,
                    userInfo: ["sequenceID": seqID.uuidString]
                )
                self?.broadcastStep(step)
            }

        case .canvasHint:
            // Show a full-dim hint overlay wherever the user currently is.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showHint(for: step)
            }

        case .highlightTemplate:
            switchToTab(0) { [weak self] in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.broadcastStep(step)
                }
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

    func spotlightOverlayDidTapToContinue(_ overlay: SpotlightOverlay) {
        dismissCurrentOverlay(animated: true) { [weak self] in
            guard let self else { return }
            switch self.currentStep {
            case .homeCreateScene:
                // Welcome overlay dismissed → proceed to actual spotlight
                self.handleNavigation(for: self.currentStep)
            case .showRecentScene:
                // User saw their recent scene → navigate to Films tab
                self.advance(to: .createFilm)
            case .canvasHint:
                // User acknowledged canvas hint → navigate to template
                self.advance(to: .highlightTemplate)
            default:
                break
            }
        }
    }
}
