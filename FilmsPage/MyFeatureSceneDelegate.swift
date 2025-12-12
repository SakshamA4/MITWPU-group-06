//
// MyFeatureSceneDelegate.swift
// FilmsPage
//
// Created by [Your Name]
//

import UIKit

// Make sure the class name matches the file name: MyFeatureSceneDelegate
class MyFeatureSceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // --- Manual Launch Setup for YOUR Feature ---
        window = UIWindow(windowScene: windowScene)
        
        // 1. Instantiate YOUR custom View Controller
        let rootVC = MyFeatureCanvasVC()
        
        // 2. Embed YOUR View Controller in a Navigation Controller
        let navigationController = UINavigationController(rootViewController: rootVC)
        
        // 3. Set the Navigation Controller as the root view controller
        window?.rootViewController = navigationController
        // -------------------------------------------
        
        window?.makeKeyAndVisible()
    }

    // You can keep the other optional SceneDelegate functions here if needed,
    // but the willConnectTo function is the only one required for launching.
    
    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}
}
