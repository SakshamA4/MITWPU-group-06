//
//  Instructions.swift
//  FilmsPage
//
//  A custom, lightweight Swift API matching the Ephread/Instructions interface.
//  Uses SwiftUI under the hood for premium, glassmorphic rendering.
//

import UIKit
import SwiftUI

// MARK: - CoachMark
struct CoachMark {
    let title: String
    let message: String
    var hint: String? = nil
    weak var targetView: UIView?
    let isInteractionRequired: Bool
    let stepIndex: Int
    let totalSteps: Int
}

// MARK: - Delegate
protocol CoachMarksControllerDelegate: AnyObject {
    func coachMarksController(_ controller: CoachMarksController, didTapContinueAt index: Int)
    func coachMarksControllerDidSkip(_ controller: CoachMarksController)
}

// MARK: - TouchPassThroughContainerView
final class TouchPassThroughContainerView: UIView {
    var spotlightRect: CGRect?
    var isInteractionRequired: Bool = false

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // If interaction is required, any touch inside the spotlight rect passes through
        if isInteractionRequired, let rect = spotlightRect {
            if rect.contains(point) {
                return nil
            }
        }
        return super.hitTest(point, with: event)
    }
}

// MARK: - CoachMarksController
final class CoachMarksController {
    weak var delegate: CoachMarksControllerDelegate?
    private var hostingVC: UIHostingController<AnyView>?
    private var containerView: TouchPassThroughContainerView?

    func show(coachMark: CoachMark, in parent: UIViewController) {
        dismiss()

        let parentView = parent.view!
        let spotlightFrame = getSpotlightRect(for: coachMark.targetView, in: parentView)

        let overlay = InstructionsOverlayView(
            spotlightRect: spotlightFrame,
            title: coachMark.title,
            message: coachMark.message,
            hint: coachMark.hint ?? (coachMark.isInteractionRequired ? "Action required to proceed" : "Tap anywhere to continue"),
            stepIndex: coachMark.stepIndex,
            totalSteps: coachMark.totalSteps,
            isInteractionRequired: coachMark.isInteractionRequired,
            onTapToContinue: { [weak self] in
                guard let self = self else { return }
                self.delegate?.coachMarksController(self, didTapContinueAt: coachMark.stepIndex)
            },
            onSkip: { [weak self] in
                guard let self = self else { return }
                self.delegate?.coachMarksControllerDidSkip(self)
            }
        )

        let hosted = UIHostingController(rootView: AnyView(overlay))
        hosted.view.backgroundColor = .clear

        let container = TouchPassThroughContainerView(frame: parentView.bounds)
        container.spotlightRect = spotlightFrame
        container.isInteractionRequired = coachMark.isInteractionRequired
        container.backgroundColor = .clear
        container.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        hosted.view.frame = container.bounds
        hosted.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(hosted.view)

        parent.addChild(hosted)
        parentView.addSubview(container)
        hosted.didMove(toParent: parent)

        self.hostingVC = hosted
        self.containerView = container
    }

    func dismiss() {
        if let hosted = hostingVC {
            hosted.willMove(toParent: nil)
            hosted.removeFromParent()
            hostingVC = nil
        }
        if let container = containerView {
            container.removeFromSuperview()
            containerView = nil
        }
    }

    private func getSpotlightRect(for view: UIView?, in parentView: UIView) -> CGRect? {
        guard let view = view, let window = view.window else { return nil }
        let rawRect = view.convert(view.bounds, to: parentView)
        // Add padding around the target view
        return rawRect.insetBy(dx: -10, dy: -10)
    }
}
