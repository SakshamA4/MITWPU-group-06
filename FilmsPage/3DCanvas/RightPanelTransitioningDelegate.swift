//
//  RightPanelTransitioningDelegate.swift
//  FilmsPage
//

import UIKit

class RightPanelTransitioningDelegate: NSObject, UIViewControllerTransitioningDelegate {
    
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        return RightPanelPresentationController(presentedViewController: presented, presenting: presenting)
    }
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return RightPanelAnimator(isPresenting: true)
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return RightPanelAnimator(isPresenting: false)
    }
}

class RightPanelAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    let isPresenting: Bool
    
    init(isPresenting: Bool) {
        self.isPresenting = isPresenting
        super.init()
    }
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return isPresenting ? 0.32 : 0.24
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        // Use correctly-typed keys — viewController(forKey:) uses UITransitionContextViewControllerKey
        // while view(forKey:) uses UITransitionContextViewKey (different types).
        let controllerKey: UITransitionContextViewControllerKey = isPresenting ? .to : .from
        let viewKey: UITransitionContextViewKey = isPresenting ? .to : .from

        guard let controller = transitionContext.viewController(forKey: controllerKey) else {
            transitionContext.completeTransition(false)
            return
        }
        guard let view = transitionContext.view(forKey: viewKey) ?? controller.view else {
            transitionContext.completeTransition(false)
            return
        }

        let container = transitionContext.containerView
        let finalFrame = transitionContext.finalFrame(for: controller)

        if isPresenting {
            container.addSubview(view)
            view.frame = finalFrame
            view.transform = CGAffineTransform(translationX: finalFrame.width + 16, y: 0)

            let animator = UIViewPropertyAnimator(
                duration: transitionDuration(using: transitionContext),
                dampingRatio: 0.82
            ) {
                view.transform = CGAffineTransform.identity
            }
            animator.addCompletion { _ in
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
            animator.startAnimation()
        } else {
            let animator = UIViewPropertyAnimator(
                duration: transitionDuration(using: transitionContext),
                curve: .easeIn
            ) {
                view.transform = CGAffineTransform(translationX: view.bounds.width + 16, y: 0)
            }
            animator.addCompletion { _ in
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
            animator.startAnimation()
        }
    }
}
