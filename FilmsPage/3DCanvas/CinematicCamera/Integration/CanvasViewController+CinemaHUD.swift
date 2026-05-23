//
//  CanvasViewController+CinemaHUD.swift
//  FilmsPage
//
//  Extension that wires the CinematicCameraHUD and all picker
//  bottom sheets to the CanvasViewController. Manages:
//    - HUD lifecycle (show/hide when entering/exiting cinema view)
//    - Picker presentation and callback binding
//    - Real-time configuration forwarding to the cinema pipeline
//

import UIKit
import RealityKit

// MARK: - CanvasViewController + Cinema HUD

extension CanvasViewController {
    
    // MARK: - Associated Keys
    
    private enum CinemaHUDKeys {
        static var hudKey = "cinematicCameraHUD"
    }
    
    /// The cinema HUD overlay — lazily created, retained per VC.
    private var cinemaHUD: CinematicCameraHUD? {
        get { objc_getAssociatedObject(self, &CinemaHUDKeys.hudKey) as? CinematicCameraHUD }
        set { objc_setAssociatedObject(self, &CinemaHUDKeys.hudKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    
    // MARK: - HUD Lifecycle
    
    /// Shows the cinema HUD overlay when entering a cinema camera view.
    /// Called from the camera-switching logic when the active camera is cinematic.
    func showCinemaHUD() {
        guard cinemaHUD == nil else {
            cinemaHUD?.isHidden = false
            refreshCinemaHUD()
            return
        }
        
        let hud = CinematicCameraHUD(frame: view.bounds)
        hud.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Wire callbacks
        hud.onCameraBodyTapped = { [weak self] in self?.presentCameraBodyPicker() }
        hud.onLensTapped = { [weak self] in self?.presentLensPicker() }
        hud.onLookTapped = { [weak self] in self?.presentLookPicker() }
        hud.onAspectRatioTapped = { [weak self] in self?.presentFrameGuidePicker() }
        hud.onFrameGuideTapped = { [weak self] in self?.presentFrameGuidePicker() }
        hud.onMotionStyleTapped = { [weak self] in self?.cycleMotionStyle() }
        
        view.addSubview(hud)
        cinemaHUD = hud
        
        // Initial data
        refreshCinemaHUD()
        
        // Fade in
        hud.alpha = 0
        UIView.animate(withDuration: 0.25) { hud.alpha = 1 }
    }
    
    /// Hides and removes the cinema HUD.
    func hideCinemaHUD() {
        guard let hud = cinemaHUD else { return }
        UIView.animate(withDuration: 0.2, animations: {
            hud.alpha = 0
        }, completion: { _ in
            hud.removeFromSuperview()
            self.cinemaHUD = nil
        })
    }
    
    /// Refreshes HUD data from the current cinema camera components.
    func refreshCinemaHUD() {
        guard let hud = cinemaHUD,
              let camRoot = cameraToVisualMap[activeCamera],
              camRoot.components[CinematicCameraTag.self] != nil else { return }
        
        // Resolve current cinema configuration from ECS components
        let sensorComp = camRoot.components[CineSensorComponent.self]
        let lensComp = camRoot.components[CineLensComponent.self]
        let lookComp = camRoot.components[CineLookComponent.self]
        let aspectComp = camRoot.components[CineAspectRatioComponent.self]
        let motionComp = camRoot.components[CineMotionComponent.self]
        
        // Look up full objects from databases
        let body = sensorComp.flatMap { comp in
            CinemaCameraDatabase.allCameras.first { $0.id == comp.cameraBodyID }
        }
        let lens = lensComp.flatMap { comp in
            CinemaLensDatabase.allFamilies.first { $0.id == comp.lensFamilyID }
        }
        let look = lookComp.flatMap { comp in
            CinematicLookDatabase.allLooks.first { $0.id == comp.lookID }
        }
        
        let focalLength = lensComp?.selectedFocalLength ?? 50
        let aspect = aspectComp?.preset ?? .anamorphicScope
        let motion = motionComp?.style ?? .tripod
        
        // Calculate FOV and crop factor
        let fovDegrees = activeCamera.camera.fieldOfViewInDegrees
        let cropFactor = body?.sensor.cropFactor ?? 1.0
        
        hud.update(
            cameraBody: body,
            lensFamily: lens,
            focalLength: focalLength,
            look: look,
            aspectRatio: aspect,
            motionStyle: motion,
            fovDegrees: fovDegrees,
            cropFactor: cropFactor
        )
    }
    
    // MARK: - Picker Presentations
    
    /// Presents the camera body picker sheet.
    private func presentCameraBodyPicker() {
        let currentID = cameraToVisualMap[activeCamera]?
            .components[CineSensorComponent.self]?.cameraBodyID
        
        let picker = CinemaCameraBodyPicker(currentCameraID: currentID)
        picker.onCameraSelected = { [weak self] body in
            self?.setCinemaBody(body)
            self?.refreshCinemaHUD()
        }
        present(picker, animated: true)
    }
    
    /// Presents the lens picker sheet.
    private func presentLensPicker() {
        let camRoot = cameraToVisualMap[activeCamera]
        let lensComp = camRoot?.components[CineLensComponent.self]
        
        let currentLens = lensComp.flatMap { comp in
            CinemaLensDatabase.allFamilies.first { $0.id == comp.lensFamilyID }
        }
        let currentFL = lensComp?.selectedFocalLength ?? 50
        
        let picker = CinemaLensPicker(currentLens: currentLens, currentFocalLength: currentFL)
        picker.onLensSelected = { [weak self] lens, fl in
            self?.setCinemaLens(lens, focalLength: fl)
            self?.refreshCinemaHUD()
        }
        present(picker, animated: true)
    }
    
    /// Presents the cinematic look picker sheet.
    private func presentLookPicker() {
        let currentID = cameraToVisualMap[activeCamera]?
            .components[CineLookComponent.self]?.lookID
        
        let picker = CinematicLookPicker(currentLookID: currentID)
        picker.onLookSelected = { [weak self] look in
            self?.setCinemaLook(look, animated: true)
            self?.refreshCinemaHUD()
        }
        picker.onIntensityChanged = { [weak self] intensity in
            self?.cinematicPipeline.configure(lookIntensity: intensity)
        }
        picker.onImportLUT = { [weak self] in
            self?.presentLUTImporter()
        }
        present(picker, animated: true)
    }
    
    /// Presents the frame guide + aspect ratio picker sheet.
    private func presentFrameGuidePicker() {
        let camRoot = cameraToVisualMap[activeCamera]
        let aspectComp = camRoot?.components[CineAspectRatioComponent.self]
        let guideComp = camRoot?.components[CineFrameGuideComponent.self]
        
        let currentAspect = aspectComp?.preset ?? .anamorphicScope
        let currentGuides = guideComp?.config ?? FrameGuideConfig()
        
        let picker = FrameGuidePicker(currentAspect: currentAspect, currentGuides: currentGuides)
        picker.onAspectRatioSelected = { [weak self] preset in
            self?.setCinemaAspectRatio(preset)
            self?.refreshCinemaHUD()
        }
        picker.onFrameGuidesChanged = { [weak self] config in
            guard let camRoot = self?.cameraToVisualMap[self?.activeCamera ?? PerspectiveCamera()] else { return }
            var comp = camRoot.components[CineFrameGuideComponent.self] ?? CineFrameGuideComponent()
            comp.config = config
            camRoot.components.set(comp)
        }
        present(picker, animated: true)
    }
    
    /// Cycles through motion styles on tap (no picker — just rotates).
    private func cycleMotionStyle() {
        let styles: [CameraMotionStyle] = [.tripod, .handheldNatural, .handheldHeavy,
                                            .steadicam, .dolly, .crane,
                                            .vehicleMount, .shoulderRig]
        
        guard let camRoot = cameraToVisualMap[activeCamera],
              let current = camRoot.components[CineMotionComponent.self]?.style,
              let idx = styles.firstIndex(of: current) else { return }
        
        let nextIdx = (idx + 1) % styles.count
        setCinemaMotionStyle(styles[nextIdx])
        refreshCinemaHUD()
        
        // Show toast
        showCinemaToast("Motion: \(styles[nextIdx].rawValue)")
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    /// Presents a document picker for LUT file import.
    private func presentLUTImporter() {
        let types = ["public.item"]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data])
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }
    
    // MARK: - Toast
    
    /// Shows a brief toast notification for cinema mode changes.
    func showCinemaToast(_ message: String) {
        let toast = UILabel()
        toast.text = "  \(message)  "
        toast.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        toast.textColor = .white
        toast.backgroundColor = UIColor(red: 0.04, green: 0.04, blue: 0.08, alpha: 0.85)
        toast.layer.cornerRadius = 16
        toast.clipsToBounds = true
        toast.textAlignment = .center
        toast.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toast)
        
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            toast.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        toast.alpha = 0
        toast.transform = CGAffineTransform(translationX: 0, y: -10)
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            toast.alpha = 1
            toast.transform = .identity
        }
        
        UIView.animate(withDuration: 0.25, delay: 1.5, options: .curveEaseIn) {
            toast.alpha = 0
            toast.transform = CGAffineTransform(translationX: 0, y: -10)
        } completion: { _ in
            toast.removeFromSuperview()
        }
    }
}
