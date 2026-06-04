//
//  AddSceneOrFilmViewController.swift
//  FilmsPage
//
//  Popover shown when the user taps "+" on the Home tab.
//  Contains two buttons: "New Scene" and "New Film".
//
//  During onboarding, this VC listens for the `.tapNewSceneButton` tutorial step
//  and spotlights the "New Scene" button so the user knows where to tap.
//

import UIKit

class AddSceneOrFilmViewController: UIViewController {

    // MARK: - Tutorial Support

    /// Returns the "New Scene" button — the first UIButton in the view hierarchy.
    private var newSceneButton: UIButton? {
        // The storyboard layout is: view → stackView → [NewSceneButton, NewFilmButton]
        return view.subviews
            .compactMap { $0 as? UIStackView }
            .first?
            .arrangedSubviews
            .compactMap { $0 as? UIButton }
            .first
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTutorialStepChanged(_:)),
            name: NSNotification.Name(NotificationNames.tutorialStepChanged),
            object: nil
        )
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        showSpotlightIfNeeded()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Tutorial Spotlight

    private func showSpotlightIfNeeded() {
        guard TutorialManager.shared.currentStep == .tapNewSceneButton,
              let button = newSceneButton else { return }

        // Short delay so the popover animation finishes first
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            TutorialManager.shared.showSpotlightIfNeeded(
                targeting: button,
                for: .tapNewSceneButton
            )
        }
    }

    @objc private func handleTutorialStepChanged(_ notification: Notification) {
        guard let raw  = notification.userInfo?["step"] as? Int,
              let step = TutorialStep(rawValue: raw),
              step == .tapNewSceneButton else { return }
        showSpotlightIfNeeded()
    }
}
