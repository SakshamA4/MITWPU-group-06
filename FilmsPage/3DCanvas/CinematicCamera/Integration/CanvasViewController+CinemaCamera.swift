//
//  CanvasViewController+CinemaCamera.swift
//  FilmsPage
//
//  Extension on CanvasViewController that integrates the cinematic camera
//  system with the existing scene camera infrastructure. Provides:
//    - Cinema camera spawning with ECS components
//    - FOV updates from sensor + lens calculations
//    - Cinematic render pipeline lifecycle management
//    - Camera body, lens, and look switching at runtime
//

import RealityKit
import UIKit
import simd

// MARK: - CanvasViewController + Cinema Camera

extension CanvasViewController {
    
    // MARK: - Associated Object Keys
    
    private enum CinemaKeys {
        static var pipelineKey = "cinematicRenderPipeline"
        static var cinemaActiveKey = "isCinematicCameraActive"
    }
    
    /// The shared cinematic render pipeline. Created lazily on first access.
    var cinematicPipeline: CinematicRenderPipeline {
        if let existing = objc_getAssociatedObject(self, &CinemaKeys.pipelineKey) as? CinematicRenderPipeline {
            return existing
        }
        let pipeline = CinematicRenderPipeline()
        objc_setAssociatedObject(self, &CinemaKeys.pipelineKey, pipeline, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return pipeline
    }
    
    /// Whether the active camera is a cinema camera (has CineSensorComponent).
    var isCinematicCameraActive: Bool {
        guard activeCamera !== editorCamera,
              let camRoot = cameraToVisualMap[activeCamera] else {
            return false
        }
        return camRoot.components[CineSensorComponent.self] != nil
    }
    
    // MARK: - Spawn Cinema Camera
    
    /// Spawns a new cinema camera with full cinematic ECS components.
    /// This creates a standard scene camera and attaches cinema-specific
    /// components for sensor simulation, lens optics, and look processing.
    ///
    /// - Parameters:
    ///   - body: The cinema camera body (e.g., ARRI Alexa Mini LF).
    ///   - lens: The lens family (e.g., Cooke S4/i).
    ///   - focalLength: Initial focal length in mm.
    ///   - look: Initial cinematic look preset.
    ///   - motionStyle: Camera motion style (default: tripod).
    ///   - aspectRatio: Cinema aspect ratio preset (default: 2.39:1 Scope).
    func spawnCinemaCamera(
        body: CinemaCameraBody,
        lens: CinemaLensFamily,
        focalLength: Float? = nil,
        look: CinematicLook? = nil,
        motionStyle: CameraMotionStyle = .tripod,
        aspectRatio: CinemaAspectRatioPreset = .scope239
    ) {
        guard let anchor = mainAnchor ?? arView.scene.findEntity(named: "MainAnchor") as? AnchorEntity else {
            return
        }
        
        // Determine initial focal length
        let initialFL = focalLength ?? lens.defaultFocalLength
        
        // Create camera root entity
        let cameraRoot = Entity()
        let cameraID = UUID()
        cameraCounter += 1
        let displayName = "\(body.modelName) #\(cameraCounter)"
        
        cameraRoot.name = "SceneCameraRoot_\(sceneCameras.count)"
        cameraRoot.components.set(CategoryComponent(toolType: .camera))
        cameraRoot.components.set(EntityIDComponent(id: cameraID))
        cameraRoot.components.set(CameraVisualComponent(modelName: "cam1", displayName: body.modelName))
        
        // Map cinema aspect ratio to existing CameraAspectRatio system
        let legacyAspect = aspectRatio.legacyCameraAspectRatio
        cameraRoot.components.set(CameraAspectComponent(aspectRatio: legacyAspect))
        
        // Attach cinema-specific ECS components
        cameraRoot.components.set(CineSensorComponent(cameraBodyID: body.id))
        cameraRoot.components.set(CineLensComponent(
            lensFamilyID: lens.id,
            selectedFocalLengthMM: initialFL
        ))
        
        if let look = look {
            cameraRoot.components.set(CineLookComponent(lookID: look.id))
        } else {
            // Default to Clean Digital look
            let defaultLook = CinematicLookDatabase.allLooks.first
            if let dl = defaultLook {
                cameraRoot.components.set(CineLookComponent(lookID: dl.id))
            }
        }
        
        cameraRoot.components.set(CineMotionComponent(motionStyle: motionStyle))
        cameraRoot.components.set(CineAspectRatioComponent(preset: aspectRatio))
        cameraRoot.components.set(CineFrameGuideComponent())
        cameraRoot.components.set(CinematicCameraTag())
        
        // Create PerspectiveCamera with cinema-accurate FOV
        let camera = PerspectiveCamera()
        camera.name = "SceneCamera_\(sceneCameras.count)"
        camera.isEnabled = false
        camera.orientation = simd_quatf(angle: .pi, axis: [0, 1, 0])
        
        // Calculate physically accurate FOV from sensor + lens
        let fov = SensorSimulationEngine.shared.calculateHorizontalFOV(
            sensorWidth: body.sensor.sensorWidthMM,
            focalLength: initialFL
        )
        camera.camera.fieldOfViewInDegrees = fov
        
        // Position in scene
        let randomX = Float.random(in: -2...2)
        let randomZ = Float.random(in: -2...2)
        cameraRoot.position = [randomX, 1, randomZ]
        
        cameraRoot.addChild(camera)
        anchor.addChild(cameraRoot)
        
        // Register in tracking arrays
        sceneCameras.append(camera)
        cameraToVisualMap[camera] = cameraRoot
        sceneCameraItems.append(SceneCameraItem(
            id: cameraID,
            camera: camera,
            cameraRoot: cameraRoot,
            displayName: displayName,
            aspectRatio: legacyAspect
        ))
        
        cameraCollectionView?.reloadData()
        startCameraPreviewUpdates()
        setCameraPanelExpanded(true, animated: true)
        setupCameraPanelSwipeGestures()
        
        // Load visual model
        loadCameraVisualModel("cam1", onto: cameraRoot, camera: camera)
        
        // Configure pipeline for this camera
        cinematicPipeline.configure(
            cameraBody: body,
            lensFamily: lens,
            focalLength: initialFL,
            look: look ?? CinematicLookDatabase.allLooks.first,
            motionStyle: motionStyle,
            aspectRatio: aspectRatio
        )
        
        print("🎬 Spawned cinema camera: \(displayName) — \(body.sensor.format.rawValue), \(lens.name) \(initialFL)mm")
    }
    
    // MARK: - Runtime Configuration Updates
    
    /// Changes the camera body on the active cinema camera.
    func setCinemaBody(_ body: CinemaCameraBody) {
        guard let camRoot = cameraToVisualMap[activeCamera],
              camRoot.components[CinematicCameraTag.self] != nil else { return }
        
        camRoot.components.set(CineSensorComponent(cameraBodyID: body.id))
        cinematicPipeline.configure(cameraBody: body)
        updateCinemaFOV(on: camRoot, camera: activeCamera)
        
        print("🎬 Camera body → \(body.modelName)")
    }
    
    /// Changes the lens family on the active cinema camera.
    func setCinemaLens(_ lens: CinemaLensFamily, focalLength: Float? = nil) {
        guard let camRoot = cameraToVisualMap[activeCamera],
              camRoot.components[CinematicCameraTag.self] != nil else { return }
        
        let fl = focalLength ?? lens.defaultFocalLength
        camRoot.components.set(CineLensComponent(
            lensFamilyID: lens.id,
            selectedFocalLengthMM: fl
        ))
        cinematicPipeline.configure(lensFamily: lens, focalLength: fl)
        updateCinemaFOV(on: camRoot, camera: activeCamera)
        
        print("🎬 Lens → \(lens.name) \(fl)mm")
    }
    
    /// Changes the focal length on the active cinema camera.
    func setCinemaFocalLength(_ focalLength: Float) {
        guard let camRoot = cameraToVisualMap[activeCamera],
              var lensComp = camRoot.components[CineLensComponent.self] else { return }
        
        lensComp.selectedFocalLengthMM = focalLength
        camRoot.components.set(lensComp)
        cinematicPipeline.configure(focalLength: focalLength)
        updateCinemaFOV(on: camRoot, camera: activeCamera)
    }
    
    /// Changes the cinematic look on the active cinema camera.
    func setCinemaLook(_ look: CinematicLook, animated: Bool = true) {
        guard let camRoot = cameraToVisualMap[activeCamera],
              camRoot.components[CinematicCameraTag.self] != nil else { return }
        
        camRoot.components.set(CineLookComponent(lookID: look.id))
        
        if animated {
            cinematicPipeline.transitionToLook(look, duration: 0.5)
        } else {
            cinematicPipeline.configure(look: look)
        }
        
        print("🎬 Look → \(look.name)")
    }
    
    /// Changes the cinema aspect ratio on the active cinema camera.
    func setCinemaAspectRatio(_ preset: CinemaAspectRatioPreset) {
        guard let camRoot = cameraToVisualMap[activeCamera],
              camRoot.components[CinematicCameraTag.self] != nil else { return }
        
        camRoot.components.set(CineAspectRatioComponent(preset: preset))
        cinematicPipeline.configure(aspectRatio: preset)
        
        // Update the legacy aspect ratio system for letterbox
        let legacyAspect = preset.legacyCameraAspectRatio
        applyAspectRatio(legacyAspect, to: activeCamera, cameraRoot: camRoot)
        
        print("🎬 Aspect ratio → \(preset.displayName)")
    }
    
    /// Changes the camera motion style on the active cinema camera.
    func setCinemaMotionStyle(_ style: CameraMotionStyle) {
        guard let camRoot = cameraToVisualMap[activeCamera],
              camRoot.components[CinematicCameraTag.self] != nil else { return }
        
        camRoot.components.set(CineMotionComponent(motionStyle: style))
        cinematicPipeline.configure(motionStyle: style)
        
        print("🎬 Motion → \(style.rawValue)")
    }
    
    // MARK: - FOV Recalculation
    
    /// Recalculates and applies the physically accurate FOV from cinema components.
    private func updateCinemaFOV(on cameraRoot: Entity, camera: PerspectiveCamera) {
        guard let sensorComp = cameraRoot.components[CineSensorComponent.self],
              let lensComp = cameraRoot.components[CineLensComponent.self] else { return }
        
        // Resolve camera body from database
        guard let body = CinemaCameraDatabase.allCameras.first(where: { $0.id == sensorComp.cameraBodyID }) else {
            return
        }
        
        let fov = SensorSimulationEngine.shared.calculateHorizontalFOV(
            sensorWidth: body.sensor.sensorWidthMM,
            focalLength: lensComp.selectedFocalLength
        )
        
        camera.camera.fieldOfViewInDegrees = fov
        
        // Update the CameraFocusComponent focal length for the HUD display
        var focusComp = cameraRoot.components[CameraFocusComponent.self] ?? CameraFocusComponent()
        focusComp.focalLengthMM = lensComp.selectedFocalLength
        cameraRoot.components.set(focusComp)
    }
    
    // MARK: - Cinema Camera Detection
    
    /// Returns true if the given camera root entity is a cinema camera.
    func isCinemaCamera(_ cameraRoot: Entity) -> Bool {
        return cameraRoot.components[CinematicCameraTag.self] != nil
    }
    
    /// Returns the current cinema configuration summary for display.
    var cinemaConfigSummary: String {
        guard isCinematicCameraActive else { return "" }
        return cinematicPipeline.configurationSummary
    }
}
