//
//  PreCanvasTips.swift
//  FilmsPage
//
//  TipKit Tip definitions for each onboarding step.
//  @Parameter rules tie each tip's eligibility to TutorialManager's current step,
//  so TipKit correctly tracks display state and supports restart via resetDatastore().
//

import TipKit

// MARK: - Step 1: Home – Create Scene (+ button)

struct HomeCreateSceneTip: Tip {
    @Parameter
    static var isActive: Bool = false

    var title: Text   { Text(TutorialStep.homeCreateScene.stepTitle) }
    var message: Text? { Text(TutorialStep.homeCreateScene.coachMessage) }

    var rules: [Rule] {
        #Rule(Self.$isActive) { $0 == true }
    }
}

// MARK: - Step 1b: Popover – New Scene button

struct TapNewSceneButtonTip: Tip {
    @Parameter
    static var isActive: Bool = false

    var title: Text    { Text(TutorialStep.tapNewSceneButton.stepTitle) }
    var message: Text? { Text(TutorialStep.tapNewSceneButton.coachMessage) }

    var rules: [Rule] {
        #Rule(Self.$isActive) { $0 == true }
    }
}

// MARK: - Step 2: Films – Create Film

struct CreateFilmTip: Tip {
    @Parameter
    static var isActive: Bool = false

    var title: Text    { Text(TutorialStep.createFilm.stepTitle) }
    var message: Text? { Text(TutorialStep.createFilm.coachMessage) }

    var rules: [Rule] {
        #Rule(Self.$isActive) { $0 == true }
    }
}

// MARK: - Step 4: MyFilm – Create Sequence

struct CreateSequenceTip: Tip {
    @Parameter
    static var isActive: Bool = false

    var title: Text    { Text(TutorialStep.createSequence.stepTitle) }
    var message: Text? { Text(TutorialStep.createSequence.coachMessage) }

    var rules: [Rule] {
        #Rule(Self.$isActive) { $0 == true }
    }
}

// MARK: - Step 5: Sequence – Create Scene

struct CreateSceneInSequenceTip: Tip {
    @Parameter
    static var isActive: Bool = false

    var title: Text    { Text(TutorialStep.createSceneInSequence.stepTitle) }
    var message: Text? { Text(TutorialStep.createSceneInSequence.coachMessage) }

    var rules: [Rule] {
        #Rule(Self.$isActive) { $0 == true }
    }
}

// MARK: - Step 6: Home – Scene Card Highlight

struct ReturnToHomeTip: Tip {
    @Parameter
    static var isActive: Bool = false

    var title: Text    { Text(TutorialStep.returnToHomeHighlight.stepTitle) }
    var message: Text? { Text(TutorialStep.returnToHomeHighlight.coachMessage) }

    var rules: [Rule] {
        #Rule(Self.$isActive) { $0 == true }
    }
}

// MARK: - Step 7: Home – Enter Scene

struct EnterSceneTip: Tip {
    @Parameter
    static var isActive: Bool = false

    var title: Text    { Text(TutorialStep.enterScene.stepTitle) }
    var message: Text? { Text(TutorialStep.enterScene.coachMessage) }

    var rules: [Rule] {
        #Rule(Self.$isActive) { $0 == true }
    }
}

// MARK: - Helpers

extension PreCanvasTips {
    /// Deactivate all tip parameters in one call.
    static func deactivateAll() {
        HomeCreateSceneTip.isActive       = false
        TapNewSceneButtonTip.isActive     = false
        CreateFilmTip.isActive            = false
        CreateSequenceTip.isActive        = false
        CreateSceneInSequenceTip.isActive = false
        ReturnToHomeTip.isActive          = false
        EnterSceneTip.isActive            = false
    }

    /// Activate only the tip that corresponds to `step`.
    static func activate(for step: TutorialStep) {
        deactivateAll()
        switch step {
        case .homeCreateScene:                          HomeCreateSceneTip.isActive       = true
        case .tapNewSceneButton:                        TapNewSceneButtonTip.isActive     = true
        case .createFilm, .filmNaming:                  CreateFilmTip.isActive            = true
        case .createSequence:                           CreateSequenceTip.isActive        = true
        case .createSceneInSequence:                    CreateSceneInSequenceTip.isActive = true
        case .returnToHomeHighlight:                    ReturnToHomeTip.isActive          = true
        case .enterScene:                               EnterSceneTip.isActive            = true
        default:                                        break
        }
    }
}

/// Namespace enum – never instantiated, used only as a scope for helpers.
enum PreCanvasTips {}
