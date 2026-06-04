//
//  TutorialStep.swift
//  FilmsPage
//
//  Defines every discrete step in the mandatory pre-canvas onboarding flow.
//  Raw Int values are persisted to UserDefaults so the flow can be resumed
//  after an app relaunch.
//

import Foundation

// MARK: - TutorialStep

/// Each case represents one milestone in the pre-canvas onboarding journey.
enum TutorialStep: Int, CaseIterable, Codable {

    // ─── sentinel ────────────────────────────────────────────────────────────
    case notStarted             = -1

    // ─── action steps ────────────────────────────────────────────────────────

    /// Step 1 – Home tab: spotlight the "+" nav-bar button.
    case homeCreateScene        = 0

    /// Step 1b – Popover: spotlight the "New Scene" button inside the popover.
    case tapNewSceneButton      = 10

    /// Step 2 – Home tab: showcase the newly-created scene under Recent Scenes
    ///          (no interaction allowed — tap anywhere to continue).
    case showRecentScene        = 11

    /// Step 3 – Films tab: spotlight the "Create Film" (+) button.
    case createFilm             = 1

    /// Step 3b – Embedded in AddFilmVC: user must enter a film name (no spotlight).
    case filmNaming             = 2

    /// Step 4 – MyFilmViewController: spotlight the "New Sequence" placeholder.
    case createSequence         = 3

    /// Step 5 – SequenceViewController: spotlight the "New Scene" placeholder.
    case createSceneInSequence  = 4

    /// Step 6 – After scene created in sequence: full-screen hint telling user
    ///          they can navigate to canvas from here (tap anywhere to continue).
    case canvasHint             = 12

    /// Step 7 – Home tab: spotlight the Outdoor template card so the user can
    ///          try a pre-built scene.
    case highlightTemplate      = 13

    /// Tutorial complete.
    case completed              = 7

    // MARK: - Content

    var stepTitle: String {
        switch self {
        case .notStarted:              return ""
        case .homeCreateScene:         return "Let's Begin"
        case .tapNewSceneButton:       return "New Scene"
        case .showRecentScene:         return "Scene Created!"
        case .createFilm:              return "Start a Film Project"
        case .filmNaming:              return "Name Your Film"
        case .createSequence:          return "Add a Sequence"
        case .createSceneInSequence:   return "Add a Scene"
        case .canvasHint:              return "Canvas Ready"
        case .highlightTemplate:       return "Explore a Pre-Built Scene"
        case .completed:               return ""
        }
    }

    var coachMessage: String {
        switch self {
        case .notStarted:              return ""
        case .homeCreateScene:         return "Tap the + button to start building your first scene."
        case .tapNewSceneButton:       return "Select \"New Scene\" to create a fresh scene for your project."
        case .showRecentScene:         return "Your scene now appears here under Recent Scenes. Every scene you create will show up right here."
        case .createFilm:              return "Films are the backbone of your workflow. Tap here to create your first one."
        case .filmNaming:              return "Give your film a name to continue."
        case .createSequence:          return "Sequences keep your scenes organised within a film. Add one now."
        case .createSceneInSequence:   return "Place a scene inside this sequence to complete the structure."
        case .canvasHint:              return "From here you can navigate to the canvas of any scene and start designing. But first, let's try something fun."
        case .highlightTemplate:       return "Try playing around with a pre-built scene to see what's possible."
        case .completed:               return ""
        }
    }

    /// True for steps that require a visible spotlight overlay.
    var requiresSpotlight: Bool {
        switch self {
        case .notStarted, .filmNaming, .completed: return false
        default: return true
        }
    }

    /// 1-based display index used in "Step X of Y" progress label.
    var displayIndex: Int {
        switch self {
        case .homeCreateScene:          return 1
        case .tapNewSceneButton:        return 1
        case .showRecentScene:          return 2
        case .createFilm, .filmNaming:  return 3
        case .createSequence:           return 4
        case .createSceneInSequence:    return 5
        case .canvasHint:               return 6
        case .highlightTemplate:        return 7
        default:                        return 0
        }
    }
}
