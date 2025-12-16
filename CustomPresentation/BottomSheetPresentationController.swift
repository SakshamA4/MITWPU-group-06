//
// BottomSheetPresentationController.swift
// FilmsPage
//
// Created by [Your Name]
//

import UIKit

class BottomSheetPresentationController: UIPresentationController {

    // The dimming view that covers the background
    private let dimmingView = UIView()

    override init(presentedViewController: UIViewController, presenting presentingViewController: UIViewController?) {
        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)

        // Set the dimming view color and alpha 
        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        dimmingView.alpha = 0
        
        // Add tap gesture to dismiss when user taps outside the modal
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissModal))
        dimmingView.addGestureRecognizer(tapGesture)
    }
    
    // Method called when the dimming view is tapped
    @objc func dismissModal() {
        presentingViewController.dismiss(animated: true, completion: nil)
    }

    // MARK: - Layout and Sizing
    
    // Defines the final size and position of the presented view (ItemPickerVC)
    override var frameOfPresentedViewInContainerView: CGRect {
        guard let container = containerView else { return .zero }

        let height: CGFloat = 560   // Fixed height for the bottom sheet
        let width: CGFloat = container.bounds.width

        // Calculate the starting Y position
        return CGRect(
            x: 0,
            y: container.bounds.height - height,
            width: width,
            height: height
        )
    }
    
    // Applies the top rounded corners to the modal view
    override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()
        // This targets the view of ItemPickerVC
        presentedView?.layer.cornerRadius = 16
        presentedView?.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    }

    // MARK: - Transition Animations
    
    // Runs right before the modal appears
    override func presentationTransitionWillBegin() {
        guard let container = containerView else { return }
        
        // Add the dimming view to the container
        dimmingView.frame = container.bounds
        container.insertSubview(dimmingView, at: 0)

        // Animate the dimming view to fade in
        presentedViewController.transitionCoordinator?.animate(alongsideTransition: { _ in
            self.dimmingView.alpha = 1
        })
    }

    // Runs right before the modal disappears
    override func dismissalTransitionWillBegin() {
        // Animate the dimming view to fade out
        presentedViewController.transitionCoordinator?.animate(alongsideTransition: { _ in
            self.dimmingView.alpha = 0
        })
    }

    // Cleans up the dimming view after dismissal is complete
    override func dismissalTransitionDidEnd(_ completed: Bool) {
        if completed {
            dimmingView.removeFromSuperview()
        }
    }
}
