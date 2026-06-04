//
//  CanvasTutorialManager.swift
//  FilmsPage
//
//  Singleton that coordinates the Canvas onboarding tutorial.
//

import UIKit

final class CanvasTutorialManager: NSObject {

    // MARK: - Singleton
    static let shared = CanvasTutorialManager()

    // MARK: - Storage Keys
    private let kCanvasTutorialStepKey = "canvas_tutorial_step"
    private let kCanvasTutorialCompletedKey = "canvas_tutorial_completed"

    // MARK: - State Properties
    private(set) var currentStep: CanvasTutorialStep {
        get {
            guard let val = UserDefaults.standard.value(forKey: kCanvasTutorialStepKey) as? Int,
                  let step = CanvasTutorialStep(rawValue: val) else {
                return .introduction
            }
            return step
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: kCanvasTutorialStepKey)
        }
    }

    var isCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: kCanvasTutorialCompletedKey) }
        set { UserDefaults.standard.set(newValue, forKey: kCanvasTutorialCompletedKey) }
    }

    weak var canvasVC: CanvasViewController?
    private let controller = CoachMarksController()

    private override init() {
        super.init()
    }

    // MARK: - API Entries
    func startTutorialIfNeeded(on vc: CanvasViewController) {
        // Only start canvas tutorial if the pre-canvas tutorial is fully finished
        guard TutorialManager.shared.hasCompletedOnboarding else { return }
        guard !isCompleted else { return }

        self.canvasVC = vc
        controller.delegate = self
        showStep(currentStep)
    }

    func showStep(_ step: CanvasTutorialStep) {
        guard let vc = canvasVC else { return }
        currentStep = step

        if step == .completed {
            isCompleted = true
            controller.dismiss()
            return
        }

        let target = getTargetView(for: step)
        let mark = CoachMark(
            title: step.title,
            message: step.message,
            hint: step.hint,
            targetView: target,
            isInteractionRequired: step.isInteractionRequired,
            stepIndex: step.displayIndex,
            totalSteps: CanvasTutorialStep.totalDisplaySteps
        )
        controller.show(coachMark: mark, in: vc)
    }

    func advance() {
        guard let idx = CanvasTutorialStep.allCases.firstIndex(of: currentStep),
              idx + 1 < CanvasTutorialStep.allCases.count else { return }
        let next = CanvasTutorialStep.allCases[idx + 1]
        showStep(next)
    }

    func skip() {
        isCompleted = true
        currentStep = .completed
        controller.dismiss()
    }

    func restart() {
        isCompleted = false
        showStep(.introduction)
    }

    // MARK: - View Coordinates Resolver
    private func getTargetView(for step: CanvasTutorialStep) -> UIView? {
        guard let vc = canvasVC else { return nil }
        switch step {
        case .hierarchyPanel:
            return vc.layersButton
        case .closeHierarchy:
            // Look up by close tag in the sidebarView
            return vc.sidebarView.viewWithTag(9002)
        case .compass:
            return vc.compassView
        case .shotBreakdown:
            return vc.shotBreakdownBtn
        case .menuBar:
            return vc.view.viewWithTag(8804) // toolbar stack
        case .addProp:
            return getToolbarButton(for: .prop)
        case .rotateProp:
            return vc.view.viewWithTag(8806) // rotateBtn
        case .addCharacter:
            return getToolbarButton(for: .character)
        case .addCamera:
            return getToolbarButton(for: .camera)
        case .addLight:
            return getToolbarButton(for: .light)
        case .addBackground:
            return getToolbarButton(for: .background)
        case .addWall:
            return getToolbarButton(for: .wall)
        case .addSky:
            return getToolbarButton(for: .sky)
        case .selection:
            return vc.arView
        case .longPressMenu:
            return vc.currentActionMenu ?? vc.arView
        default:
            return nil
        }
    }

    private func getToolbarButton(for tool: ToolType) -> UIView? {
        guard let vc = canvasVC,
              let toolbar = vc.view.viewWithTag(8804) as? UIStackView else { return nil }
        guard let index = ToolType.allCases.firstIndex(of: tool),
              index < toolbar.arrangedSubviews.count else { return nil }
        return toolbar.arrangedSubviews[index]
    }

    // MARK: - Action Intercept Handlers
    func handleHierarchyToggled(isOpen: Bool) {
        if currentStep == .hierarchyPanel && isOpen {
            advance()
        } else if currentStep == .closeHierarchy && !isOpen {
            advance()
        }
    }

    func handleCompassInteracted() {
        if currentStep == .compass {
            advance()
        }
    }

    func handleShotBreakdownOpened() {
        if currentStep == .shotBreakdown {
            advance()
        }
    }

    func handleCanvasReturnedFromBreakdown() {
        if currentStep == .dismissBreakdown {
            advance()
        }
    }

    func handlePanGestureEnded() {
        if currentStep == .panGesture {
            advance()
        }
    }

    func handleOrbitGestureEnded() {
        if currentStep == .orbitGesture {
            advance()
        }
    }

    func handleZoomGestureEnded() {
        if currentStep == .zoomGesture {
            advance()
        }
    }

    func handleEntitySpawned(toolType: ToolType) {
        switch currentStep {
        case .addProp where toolType == .prop:
            advance()
        case .addCharacter where toolType == .character:
            advance()
        case .addCamera where toolType == .camera:
            advance()
        case .addLight where toolType == .light:
            advance()
        case .addBackground where toolType == .background:
            advance()
        case .addWall where toolType == .wall:
            advance()
        case .addSky where toolType == .sky:
            advance()
        default:
            break
        }
    }

    func handlePropRotated() {
        if currentStep == .rotateProp {
            advance()
        }
    }

    func handleEntitySelected() {
        if currentStep == .selection {
            advance()
        }
    }

    func handleLongPressMenuOpened() {
        if currentStep == .longPressMenu {
            advance()
        }
    }

    func handleEntityDuplicatedOrRenamed() {
        if currentStep == .entityEditing {
            advance()
        }
    }
}

// MARK: - CoachMarksControllerDelegate Integration
extension CanvasTutorialManager: CoachMarksControllerDelegate {
    func coachMarksController(_ controller: CoachMarksController, didTapContinueAt index: Int) {
        if !currentStep.isInteractionRequired {
            advance()
        }
    }

    func coachMarksControllerDidSkip(_ controller: CoachMarksController) {
        skip()
    }
}
