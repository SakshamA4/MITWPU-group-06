//
//  PreCanvasTips.swift
//  FilmsPage
//
//  TipKit Tip definitions for each onboarding step.
//

import TipKit

// MARK: - Step 1: Home – Tap + button

struct HomeCreateSceneTip: Tip {
    @Parameter static var isActive: Bool = false
    var title: Text   { Text(TutorialStep.homeCreateScene.stepTitle) }
    var message: Text? { Text(TutorialStep.homeCreateScene.coachMessage) }
    var rules: [Rule] { #Rule(Self.$isActive) { $0 == true } }
}

// MARK: - Step 1b: Popover – New Scene button

struct TapNewSceneButtonTip: Tip {
    @Parameter static var isActive: Bool = false
    var title: Text    { Text(TutorialStep.tapNewSceneButton.stepTitle) }
    var message: Text? { Text(TutorialStep.tapNewSceneButton.coachMessage) }
    var rules: [Rule] { #Rule(Self.$isActive) { $0 == true } }
}

// MARK: - Step 2: Home – Show Recent Scene (showcase)

struct ShowRecentSceneTip: Tip {
    @Parameter static var isActive: Bool = false
    var title: Text    { Text(TutorialStep.showRecentScene.stepTitle) }
    var message: Text? { Text(TutorialStep.showRecentScene.coachMessage) }
    var rules: [Rule] { #Rule(Self.$isActive) { $0 == true } }
}

// MARK: - Step 3: Films – Create Film

struct CreateFilmTip: Tip {
    @Parameter static var isActive: Bool = false
    var title: Text    { Text(TutorialStep.createFilm.stepTitle) }
    var message: Text? { Text(TutorialStep.createFilm.coachMessage) }
    var rules: [Rule] { #Rule(Self.$isActive) { $0 == true } }
}

// MARK: - Step 4: MyFilm – Create Sequence

struct CreateSequenceTip: Tip {
    @Parameter static var isActive: Bool = false
    var title: Text    { Text(TutorialStep.createSequence.stepTitle) }
    var message: Text? { Text(TutorialStep.createSequence.coachMessage) }
    var rules: [Rule] { #Rule(Self.$isActive) { $0 == true } }
}

// MARK: - Step 5: Sequence – Create Scene

struct CreateSceneInSequenceTip: Tip {
    @Parameter static var isActive: Bool = false
    var title: Text    { Text(TutorialStep.createSceneInSequence.stepTitle) }
    var message: Text? { Text(TutorialStep.createSceneInSequence.coachMessage) }
    var rules: [Rule] { #Rule(Self.$isActive) { $0 == true } }
}

// MARK: - Step 7: Home – Highlight Template

struct HighlightTemplateTip: Tip {
    @Parameter static var isActive: Bool = false
    var title: Text    { Text(TutorialStep.highlightTemplate.stepTitle) }
    var message: Text? { Text(TutorialStep.highlightTemplate.coachMessage) }
    var rules: [Rule] { #Rule(Self.$isActive) { $0 == true } }
}

// MARK: - Helpers

extension PreCanvasTips {
    static func deactivateAll() {
        HomeCreateSceneTip.isActive       = false
        TapNewSceneButtonTip.isActive     = false
        ShowRecentSceneTip.isActive       = false
        CreateFilmTip.isActive            = false
        CreateSequenceTip.isActive        = false
        CreateSceneInSequenceTip.isActive = false
        HighlightTemplateTip.isActive     = false
    }

    static func activate(for step: TutorialStep) {
        deactivateAll()
        switch step {
        case .homeCreateScene:       HomeCreateSceneTip.isActive       = true
        case .tapNewSceneButton:     TapNewSceneButtonTip.isActive     = true
        case .showRecentScene:       ShowRecentSceneTip.isActive       = true
        case .createFilm, .filmNaming: CreateFilmTip.isActive          = true
        case .createSequence:        CreateSequenceTip.isActive        = true
        case .createSceneInSequence: CreateSceneInSequenceTip.isActive = true
        case .highlightTemplate:     HighlightTemplateTip.isActive     = true
        default:                     break
        }
    }
}

/// Namespace enum – never instantiated, used only as a scope for helpers.
enum PreCanvasTips {}
