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
    /// Onboarding has not yet been triggered.
    case notStarted             = -1

    // ─── action steps ────────────────────────────────────────────────────────

    /// Step 1 – Home tab: spotlight the "+" nav-bar button.
    case homeCreateScene        = 0

    /// Step 1b – Popover: spotlight the "New Scene" button inside the popover.
    case tapNewSceneButton      = 10

    /// Step 2 – Films tab: spotlight the "Create Film" (+) button.
    case createFilm             = 1

    /// Step 3 – Embedded in AddFilmVC: user must enter a film name (no spotlight).
    case filmNaming             = 2

    /// Step 4 – MyFilmViewController: spotlight the "New Sequence" placeholder.
    case createSequence         = 3

    /// Step 5 – SequenceViewController: spotlight the "New Scene" placeholder.
    case createSceneInSequence  = 4

    /// Step 6 – Return to Home: highlight the newly created scene card.
    case returnToHomeHighlight  = 5

    /// Step 7 – Home tab: coach mark prompting the user to tap the scene card.
    case enterScene             = 6

    /// Step 8 – Tutorial complete; signals CanvasTutorial to begin.
    case completed              = 7

    // MARK: - Content

    var stepTitle: String {
        switch self {
        case .notStarted:              return ""
        case .homeCreateScene:         return "Let's Begin"
        case .tapNewSceneButton:       return "New Scene"
        case .createFilm:              return "Start a Film Project"
        case .filmNaming:              return "Name Your Film"
        case .createSequence:          return "Add a Sequence"
        case .createSceneInSequence:   return "Add a Scene"
        case .returnToHomeHighlight:   return "You're All Set!"
        case .enterScene:              return "Open Your Canvas"
        case .completed:               return ""
        }
    }

    var coachMessage: String {
        switch self {
        case .notStarted:              return ""
        case .homeCreateScene:         return "Tap the + button to start building your first scene."
        case .tapNewSceneButton:       return "Select \"New Scene\" to create a fresh scene for your project."
        case .createFilm:              return "Films are the backbone of your workflow. Tap here to create your first one."
        case .filmNaming:              return "Give your film a name to continue."
        case .createSequence:          return "Sequences keep your scenes organised within a film. Add one now."
        case .createSceneInSequence:   return "Place a scene inside this sequence to complete the structure."
        case .returnToHomeHighlight:   return "Your first scene is ready and waiting for you right here."
        case .enterScene:              return "Tap your scene to jump into the production canvas and start creating."
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
        case .createFilm, .filmNaming:  return 2
        case .createSequence:           return 3
        case .createSceneInSequence:    return 4
        case .returnToHomeHighlight:    return 5
        case .enterScene:               return 6
        default:                        return 0
        }
    }
}
