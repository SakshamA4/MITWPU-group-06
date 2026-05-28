//
//  OnboardingStep.swift
//  FilmsPage — SceneWiz Onboarding
//

import UIKit

/// A single step in the cinematic onboarding walkthrough.
struct OnboardingStep {
    /// Zero-based index (0…10 for the 11-step flow).
    let stepIndex: Int

    /// Bold heading shown in the tooltip card.
    let heading: String

    /// Explanatory sub-text shown below the heading.
    let subtext: String

    /// The `accessibilityIdentifier` of the UI element to spotlight.
    /// `nil` means no specific element — the overlay uses a full-screen glow instead.
    let targetElementID: String?

    /// Label for the primary action button.  "Next →" for most steps, "Let's Go" for the last.
    let nextButtonLabel: String

    /// When `true` the Next button starts hidden and is only revealed after the user
    /// performs a gesture inside the spotlight area.  Used for Step 10 (move/rotate prop).
    let requiresInteraction: Bool

    /// When `true` no cutout hole is drawn — the spotlight is a soft amber ring at screen centre.
    /// Used for the Welcome (step 0) and Finale (step 10) steps.
    let isFullScreenGlow: Bool

    // ── Factory ──────────────────────────────────────────────────────────────

    static let allSteps: [OnboardingStep] = [

        // Step 0 — Welcome
        OnboardingStep(
            stepIndex: 0,
            heading: "Welcome to SceneWiz.",
            subtext: "Your personal director's toolkit. Let's take 2 minutes to show you around.",
            targetElementID: nil,
            nextButtonLabel: "Next →",
            requiresInteraction: false,
            isFullScreenGlow: true
        ),

        // Step 1 — Home Tab
        OnboardingStep(
            stepIndex: 1,
            heading: "Your creative stage.",
            subtext: "These are ready-made templates to spark your vision. Tap any to explore a scene layout instantly.",
            targetElementID: "onb_homeTemplatesGrid",
            nextButtonLabel: "Next →",
            requiresInteraction: false,
            isFullScreenGlow: false
        ),

        // Step 2 — Films Tab
        OnboardingStep(
            stepIndex: 2,
            heading: "Every great story starts with a film.",
            subtext: "Head over to the Films tab — this is where your productions live.",
            targetElementID: "onb_filmsTabItem",
            nextButtonLabel: "Next →",
            requiresInteraction: false,
            isFullScreenGlow: false
        ),

        // Step 3 — Create a New Film
        OnboardingStep(
            stepIndex: 3,
            heading: "Lights. Camera. Create.",
            subtext: "Tap the + to start your first film. Give it a name — this is your project container.",
            targetElementID: "onb_addFilmButton",
            nextButtonLabel: "Next →",
            requiresInteraction: false,
            isFullScreenGlow: false
        ),

        // Step 4 — Inside Film — Create a Sequence
        OnboardingStep(
            stepIndex: 4,
            heading: "Break it down into sequences.",
            subtext: "A film is built from sequences. Tap here to add your first one — think of it as a chapter.",
            targetElementID: "onb_addSequenceButton",
            nextButtonLabel: "Next →",
            requiresInteraction: false,
            isFullScreenGlow: false
        ),

        // Step 5 — Create a Scene
        OnboardingStep(
            stepIndex: 5,
            heading: "Now, build your scene.",
            subtext: "Scenes are where the magic happens. Tap here to create one inside your sequence.",
            targetElementID: "onb_addSceneButton",
            nextButtonLabel: "Next →",
            requiresInteraction: false,
            isFullScreenGlow: false
        ),

        // Step 6 — Name the Scene
        OnboardingStep(
            stepIndex: 6,
            heading: "Every scene needs a title.",
            subtext: "Give your scene a name — something that captures the moment you're creating.",
            targetElementID: "onb_sceneNameField",
            nextButtonLabel: "Next →",
            requiresInteraction: false,
            isFullScreenGlow: false
        ),

        // Step 7 — Open Scene on Canvas
        OnboardingStep(
            stepIndex: 7,
            heading: "Tap to enter your canvas.",
            subtext: "Tap your scene to open the director's canvas — where you'll stage everything.",
            targetElementID: "onb_sceneCard",
            nextButtonLabel: "Next →",
            requiresInteraction: false,
            isFullScreenGlow: false
        ),

        // Step 8 — Place a Prop
        OnboardingStep(
            stepIndex: 8,
            heading: "Set the stage.",
            subtext: "Pick a prop and place it on your canvas. Drag it anywhere you like.",
            targetElementID: "onb_propsToolButton",
            nextButtonLabel: "Next →",
            requiresInteraction: false,
            isFullScreenGlow: false
        ),

        // Step 9 — Move & Rotate the Prop
        OnboardingStep(
            stepIndex: 9,
            heading: "Take control of your shot.",
            subtext: "Move the prop around freely. Tap the bottom-left button to rotate it and perfect your composition.",
            targetElementID: "onb_rotateMoveButton",
            nextButtonLabel: "Next →",
            requiresInteraction: true,
            isFullScreenGlow: false
        ),

        // Step 10 — Finale
        OnboardingStep(
            stepIndex: 10,
            heading: "And… action.",
            subtext: "You're officially behind the lens. Your canvas is yours — go direct something extraordinary.",
            targetElementID: nil,
            nextButtonLabel: "Let's Go",
            requiresInteraction: false,
            isFullScreenGlow: true
        )
    ]
}
