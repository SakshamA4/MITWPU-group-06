//
//  OnboardingStep.swift
//  FilmsPage — SceneWiz Onboarding
//

import UIKit

/// A single step in the cinematic onboarding walkthrough.
struct OnboardingStep {
    /// Zero-based index (0…12 for the 13-step flow).
    let stepIndex: Int

    /// Bold heading shown in the tooltip card.
    let heading: String

    /// Explanatory sub-text shown below the heading.
    let subtext: String

    /// The `accessibilityIdentifier` of the UI element to spotlight.
    /// `nil` means no specific element — the overlay uses a full-screen glow instead.
    let targetElementID: String?

    /// Label for the primary action button. (Usually hidden if `isInteractive` is true).
    let nextButtonLabel: String

    /// When `true`, the Next button is hidden and the spotlight cutout allows touches to pass through
    /// so the user can interact directly with the app.
    let isInteractive: Bool

    /// If set, the manager waits for this VC type to appear (via `onboardingVCAppeared` notification)
    /// to automatically advance to the next step.
    let autoAdvancesOnVC: String?

    /// When `true` no cutout hole is drawn — the spotlight is a soft amber ring at screen centre.
    let isFullScreenGlow: Bool

    static let allSteps: [OnboardingStep] = [

        // Step 0 — Welcome
        OnboardingStep(
            stepIndex: 0,
            heading: "Welcome to SceneWiz.",
            subtext: "Your personal director's toolkit. Let's take a quick interactive tour.",
            targetElementID: nil,
            nextButtonLabel: "Next →",
            isInteractive: false,
            autoAdvancesOnVC: nil,
            isFullScreenGlow: true
        ),

        // Step 1 — Home Tab
        OnboardingStep(
            stepIndex: 1,
            heading: "Your creative stage.",
            subtext: "These are ready-made templates to spark your vision. But let's build from scratch.",
            targetElementID: "onb_homeTemplatesGrid",
            nextButtonLabel: "Next →",
            isInteractive: false,
            autoAdvancesOnVC: nil,
            isFullScreenGlow: false
        ),

        // Step 2 — Create a New Film
        OnboardingStep(
            stepIndex: 2,
            heading: "Lights. Camera. Create.",
            subtext: "Tap the + to start your first film project.",
            targetElementID: "onb_addFilmButton",
            nextButtonLabel: "",
            isInteractive: true,
            autoAdvancesOnVC: "addFilm",
            isFullScreenGlow: false
        ),

        // Step 3 — Name the Film
        OnboardingStep(
            stepIndex: 3,
            heading: "Name your production.",
            subtext: "Give your film a name and tap 'Add' to jump inside.",
            targetElementID: "onb_filmNameField",
            nextButtonLabel: "",
            isInteractive: true,
            autoAdvancesOnVC: "myFilm",
            isFullScreenGlow: false
        ),

        // Step 4 — Inside Film — Create a Sequence
        OnboardingStep(
            stepIndex: 4,
            heading: "Break it down into sequences.",
            subtext: "A film is built from sequences. Tap here to add your first chapter.",
            targetElementID: "onb_addSequenceButton",
            nextButtonLabel: "",
            isInteractive: true,
            autoAdvancesOnVC: "addSequence",
            isFullScreenGlow: false
        ),

        // Step 5 — Name the Sequence
        OnboardingStep(
            stepIndex: 5,
            heading: "Name your sequence.",
            subtext: "Give it a title and tap 'Add' to enter the sequence.",
            targetElementID: "onb_sequenceNameField",
            nextButtonLabel: "",
            isInteractive: true,
            autoAdvancesOnVC: "sequence",
            isFullScreenGlow: false
        ),

        // Step 6 — Create a Scene
        OnboardingStep(
            stepIndex: 6,
            heading: "Now, build your scene.",
            subtext: "Scenes are where the magic happens. Tap here to create one.",
            targetElementID: "onb_addSceneButton",
            nextButtonLabel: "",
            isInteractive: true,
            autoAdvancesOnVC: "addScene",
            isFullScreenGlow: false
        ),

        // Step 7 — Name the Scene
        OnboardingStep(
            stepIndex: 7,
            heading: "Every scene needs a title.",
            subtext: "Name your scene and tap 'Add' to place it in the sequence.",
            targetElementID: "onb_sceneNameField",
            nextButtonLabel: "",
            isInteractive: true,
            autoAdvancesOnVC: "sequence",
            isFullScreenGlow: false
        ),

        // Step 8 — Open Scene on Canvas
        OnboardingStep(
            stepIndex: 8,
            heading: "Tap to enter your canvas.",
            subtext: "Tap your new scene card to open the director's canvas.",
            targetElementID: "onb_sceneCard",
            nextButtonLabel: "",
            isInteractive: true,
            autoAdvancesOnVC: "canvas",
            isFullScreenGlow: false
        ),

        // Step 9 — Place a Prop
        OnboardingStep(
            stepIndex: 9,
            heading: "Set the stage.",
            subtext: "Tap the Props tool at the bottom to open the library.",
            targetElementID: "onb_propsToolButton",
            nextButtonLabel: "",
            isInteractive: true,
            autoAdvancesOnVC: "toolSheet",
            isFullScreenGlow: false
        ),

        // Step 10 — Move & Rotate the Prop
        OnboardingStep(
            stepIndex: 10,
            heading: "Take control of your shot.",
            subtext: "Select any prop from the sheet. Once it's placed on the canvas, try dragging or rotating it.",
            targetElementID: nil,
            nextButtonLabel: "",
            isInteractive: true,
            autoAdvancesOnVC: nil, // This one is advanced via onboardingGestureDetected
            isFullScreenGlow: true // We use a glow here because the user is moving around
        ),

        // Step 11 — Finale
        OnboardingStep(
            stepIndex: 11,
            heading: "And… action.",
            subtext: "You're officially behind the lens. Your canvas is yours — go direct something extraordinary.",
            targetElementID: nil,
            nextButtonLabel: "Let's Go",
            isInteractive: false,
            autoAdvancesOnVC: nil,
            isFullScreenGlow: true
        )
    ]
}
