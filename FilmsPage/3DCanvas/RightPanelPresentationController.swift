//
//  RightPanelPresentationController.swift
//  FilmsPage
//

import UIKit

private enum PanelLayout {
    static let widthRatio: CGFloat = 0.42
    static let maxPhoneWidth: CGFloat = 300
    static let maxPadWidth: CGFloat = 360

    static let minPanelHeight: CGFloat = 320
    static let maxSafeAreaRatio: CGFloat = 0.85
    static let rightInset: CGFloat = 16

    static let swipeDismissThreshold: CGFloat = 60
    static let dampingRatioSwipeSpring: CGFloat = 0.7
}

class RightPanelPresentationController: UIPresentationController {

    private let dimmingView = UIView()
    private var panGesture: UIPanGestureRecognizer!
    private var initialTransform: CGAffineTransform = .identity

    override init(presentedViewController: UIViewController, presenting presentingViewController: UIViewController?) {
        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
        dimmingView.backgroundColor = UIColor.black.withAlphaComponent(0.0) // Clear dimming
        dimmingView.isUserInteractionEnabled = false // Allow interaction with the canvas
    }

    override var frameOfPresentedViewInContainerView: CGRect {
        guard let container = containerView else { return .zero }

        let isIPad = container.traitCollection.userInterfaceIdiom == .pad
        let maxWidth: CGFloat = isIPad ? PanelLayout.maxPadWidth : PanelLayout.maxPhoneWidth

        let computedWidth = container.bounds.width * PanelLayout.widthRatio
        let panelWidth = min(computedWidth, maxWidth)

        let safeArea = container.safeAreaLayoutGuide.layoutFrame

        // Let the view controller specify its intrinsic content size
        let intrinsicHeight = presentedViewController.preferredContentSize.height
        let targetHeight = intrinsicHeight > 0 ? intrinsicHeight : 600

        let clampedHeight = min(max(targetHeight, PanelLayout.minPanelHeight), safeArea.height * PanelLayout.maxSafeAreaRatio)

        // Vertically centered within safe area
        let y = safeArea.midY - (clampedHeight / 2)

        // Anchored to the right
        let x = container.bounds.width - container.safeAreaInsets.right - PanelLayout.rightInset - panelWidth

        return CGRect(x: x, y: y, width: panelWidth, height: clampedHeight)
    }

    override func presentationTransitionWillBegin() {
        guard let container = containerView, let view = presentedView else { return }

        dimmingView.frame = container.bounds
        container.insertSubview(dimmingView, at: 0)

        // Setup styling based on the audit
        view.layer.cornerRadius = 16
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 8
        view.layer.shadowOpacity = 0.1
        view.clipsToBounds = true

        // Actually shadow won't show if clipsToBounds is true on the view, so we wrap it or set masksToBounds to false.
        // Wait, if it's true, shadow is clipped. Let's make it false.
        view.clipsToBounds = false
        view.layer.masksToBounds = false

        // But the background color is set on the view itself and its corners should be rounded. 
        // We can just rely on the view's own clipsToBounds or use a container view.
        // The view background is already dark, cornerRadius = 16 will round the corners.
        // But if masksToBounds = false, the content might bleed outside the corners.
        // We'll set masksToBounds = true on the view, and use a separate shadow layer if needed, 
        // but since UIKit UIViews can't do both easily without a wrapper, we'll just set it to false and rely on the background color's own rounding,
        // or just let the shadow clip if masksToBounds = false.
        // Actually, if we set background color on `view`, cornerRadius works with masksToBounds=false as long as subviews don't bleed.

        // Setup Pan Gesture for swipe-to-dismiss
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.delegate = self
        view.addGestureRecognizer(panGesture)
    }

    override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()
        presentedView?.frame = frameOfPresentedViewInContainerView
        dimmingView.frame = containerView?.bounds ?? .zero
    }
}

extension RightPanelPresentationController: UIGestureRecognizerDelegate {

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let view = presentedView else { return }
        let translation = gesture.translation(in: view)

        switch gesture.state {
        case .began:
            initialTransform = view.transform
        case .changed:
            if translation.x > 0 {
                view.transform = initialTransform.translatedBy(x: translation.x, y: 0)
            }
        case .ended, .cancelled:
            if translation.x > PanelLayout.swipeDismissThreshold {
                presentedViewController.dismiss(animated: true)
            } else {
                let animator = UIViewPropertyAnimator(duration: 0.3, dampingRatio: PanelLayout.dampingRatioSwipeSpring) {
                    view.transform = self.initialTransform
                }
                animator.startAnimation()
            }
        default: break
        }
    }

    // Only begin the pan gesture if swiping horizontally to the right.
    // This prevents interference with the internal UIScrollView.
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let pan = gestureRecognizer as? UIPanGestureRecognizer, let view = presentedView {
            let velocity = pan.velocity(in: view)
            return abs(velocity.x) > abs(velocity.y) && velocity.x > 0
        }
        return true
    }
}
