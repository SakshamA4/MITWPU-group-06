import Combine
import PhotosUI
import RealityKit
import UIKit
import ARKit

// MARK: - CanvasViewController + CharacterDetailDelegate
extension CanvasViewController: CharacterDetailDelegate {}

extension CanvasViewController {


//    func spawnEntity(
//        item: SpawnItem,
//        toolType: ToolType,
//        customName: String? = nil,
//        scale: Float = 1.0
//    ) {
//        saveCurrentStateToUndo()
//
//        Task {
//            do {
//                // 1. Initial Checks for Special Types
//
//                // Camera
//                if item.modelFileName == "cam1" {
//                    spawnSceneCamera()
//                    return
//                }
//                // Walls/Ground
//                if item.modelFileName == "cube" {
//                    spawnWall()
//                    return
//                }
//                if item.modelFileName == "ground" {
//                    spawnGround()
//                    return
//                }
//                if item.isBackground {
//                    spawnBackgroundPlane(item)
//                    return
//                }
//
//                // 2. Load the 3D Model (Character/Prop/Light)
//                // If code reaches here, it assumes a valid .usdz file exists
//                let entity = try await Entity(named: item.modelFileName)
//
//                // --- (Keep your existing Normalization, Scale, and Position logic here) ---
//                // 📍 STEP A: NORMALIZE
//                let bounds = entity.visualBounds(relativeTo: nil)
//                let maxDim = max(
//                    bounds.extents.x,
//                    max(bounds.extents.y, bounds.extents.z)
//                )
//                if maxDim > 0.0001 {
//                    let normalizationFactor = 1.0 / maxDim
//                    entity.scale = SIMD3(repeating: normalizationFactor)
//                }
//
//                // 📍 STEP B: APPLY SCALES
//                var verticalOffset: Float = 0.0
//                // ... (Your existing specific prop scaling logic) ...
//                if item.modelFileName == "Spotlight" {
//                    entity.scale = SIMD3(repeating: 0.01)
//                    verticalOffset = 0.25
//                } else if item.modelFileName.contains("LED") {
//                    entity.scale = SIMD3(repeating: 0.01)
//                } else if item.modelFileName.contains("Lantern") {
//                    entity.scale = SIMD3(repeating: 0.0025)
//                    verticalOffset = 0.25
//                } else if item.modelFileName.contains("Plant") {
//                    entity.scale = SIMD3(repeating: 0.01)
//                } else {
//                    entity.scale = SIMD3<Float>(repeating: scale)
//                }
//
//                // 📍 STEP C: APPLY POSITION
//                let randomX = Float.random(in: -1...1)
//                let randomZ = Float.random(in: -1...1)
//                let finalBounds = entity.visualBounds(relativeTo: nil)
//                let liftToGround = -finalBounds.min.y
//                let finalY = verticalOffset > 0 ? verticalOffset : liftToGround
//
//                entity.name = customName ?? item.modelFileName
//                entity.position = [randomX, finalY, randomZ]
//
//                // 3. Components & Light Attachment
//                entity.components.set(CategoryComponent(toolType: toolType))
//                entity.generateCollisionShapes(recursive: true)
//                entity.components.set(InputTargetComponent())
//
//                // ... (Your light attachment logic) ...
//                if item.title.lowercased() == "light"
//                    || item.modelFileName == "Spotlight"
//                {
//                    addRealLightToModel(entity)
//                } else if item.title.lowercased() == "light"
//                    || item.modelFileName == "LED Panel"
//                {
//                    addLEDPanel(to: entity)
//                } else if item.title.lowercased() == "lantern"
//                    || item.modelFileName == "Lantern"
//                {
//                    addLantern(to: entity)
//                }
//
//                // 4. Add to Scene
//                if let anchor = arView.scene.findEntity(named: "MainAnchor") {
//                    anchor.addChild(entity)
//                    self.refreshSidebarContent()
//                }
//            } catch {
//                print("Failed to load \(item.modelFileName): \(error)")
//            }
//        }
//    }


    func spawnBackgroundPlane(_ item: SpawnItem) {
        // Check for Custom Image first
        if let customImage = item.customImage {
            applyBackgroundImage(customImage)
            return
        }
        // Check for Standard Asset Image
        if let imageName = item.imageName, let image = UIImage(named: imageName)
        {
            applyBackgroundImage(image)
            return
        }
        print("Error: No image found for background \(item.title)")
    }

    
//    func applySky(type: String) {
//        // 1. Remove existing sky
//        if let existingSky = arView.scene.findEntity(named: "ProceduralSky") {
//            existingSky.removeFromParent()
//        }
//        
//        var skyMaterial = UnlitMaterial()
//        var topColor: UIColor = .systemBlue
//        
//        // 2. Load Texture or Color
//        if type == "sky_image_1" {
//            if let texture = try? TextureResource.load(named: type) {
//                skyMaterial.color.texture = .init(texture)
//                arView.environment.background = .color(.black)
//            } else {
//                topColor = .systemGray
//                skyMaterial.color.tint = topColor
//                arView.environment.background = .color(topColor)
//            }
//        } else {
//            switch type {
//            case "sky_sunset": topColor = .orange
//            case "sky_night": topColor = UIColor(red: 0.05, green: 0.05, blue: 0.2, alpha: 1)
//            default: topColor = UIColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1)
//            }
//            skyMaterial.color.tint = topColor
//            arView.environment.background = .color(topColor)
//        }
//        
//        // 3. Create Sphere
//        let skyMesh = MeshResource.generateSphere(radius: 50)
//        let skyEntity = ModelEntity(mesh: skyMesh, materials: [skyMaterial])
////        skyEntity.name = "ProceduralSky"
//        skyEntity.name = "ProceduralSky_\(type)"
//        // 4. THE FIX FOR INVERSION:
//        // Instead of just flipping scale, we also apply a 180-degree rotation
//        // around the X-axis to fix the "upside down" issue.
//        skyEntity.scale *= -1
//        skyEntity.orientation = simd_quatf(angle: .pi, axis: [1, 0, 0])
//        
//        // 5. Final Setup
//        skyEntity.components.set(CategoryComponent(toolType: .sky))
//        
//        if let anchor = arView.scene.findEntity(named: "MainAnchor") {
//            anchor.addChild(skyEntity)
//        }
//    }

    
    func applyBackgroundImage(_ image: UIImage) {
        guard let cgImage = image.cgImage,
              let anchor = arView.scene.findEntity(named: "MainAnchor")
        else { return }
        
        do {
            // Create Material
            let texture = try TextureResource(
                image: cgImage,
                options: .init(semantic: .color)
            )
            var material = UnlitMaterial()
            material.color.texture = .init(texture)

            backgroundCounter += 1
            let uniqueName = "Background \(backgroundCounter)"

            
            // 1. DIMENSIONS
            let aspect = Float(image.size.width / image.size.height)
            let height: Float = 1.5
            let width = height * aspect
            let thickness: Float = 0.05

            
            // 2. BOX MESH (Double-sided and thick)
            let mesh = MeshResource.generateBox(
                width: width,
                height: height,
                depth: thickness
            )
            let plane = ModelEntity(mesh: mesh, materials: [material])
            plane.name = uniqueName
            
            plane.components.set(
                BackgroundComponent(width: width, height: height)
            )
            
            // 3. INTERACTION
            plane.generateCollisionShapes(recursive: true)
            plane.components.set(InputTargetComponent())
            plane.orientation = simd_quatf(angle: 0, axis: [0, 0, 1])
            
            let offset = Float(backgroundCounter) * 0.1
            plane.position = [offset, height / 2, -2.1 - offset]
            
            // 6. GESTURES & CATEGORY
            plane.components.set(CategoryComponent(toolType: .background))
            
            anchor.addChild(plane)
            self.backgroundPlane = plane
            
            self.refreshSidebarContent()
            
        } catch {
            print("Texture failed: \(error)")
        }
    }

    
    func addRealLightToModel(_ model: Entity) {
        let realLight = SpotLight()
        
        // 1. High Intensity & Clear Beam
        realLight.light.intensity = 200000
        realLight.light.innerAngleInDegrees = 10
        realLight.light.outerAngleInDegrees = 30
        realLight.light.attenuationRadius = 20.0
        realLight.shadow = SpotLightComponent.Shadow()
        realLight.orientation = simd_quaternion(Float.pi, [0, 1, 0])
        realLight.position = [0, 0, 0.2]
        
        let lensGlow = ModelEntity(
            mesh: .generateSphere(radius: 0.1),
            materials: [UnlitMaterial(color: .yellow)]
        )
        lensGlow.position = [10, 10, 0.1]
        model.addChild(lensGlow)
        
        // 4. ADD VOLUMETRIC CONE (Visible Beam)
        let beamMesh = MeshResource.generateCone(height: 4.0, radius: 1.0)
        var beamMat = UnlitMaterial(color: .white)
        beamMat.blending = .transparent(opacity: .init(floatLiteral: 0.2))
        let beamVisual = ModelEntity(mesh: beamMesh, materials: [beamMat])
        
        // Rotate and position the cone to match the light path
        beamVisual.orientation = simd_quaternion(-Float.pi / 2, [1, 0, 0])
        beamVisual.position = [0, 0, -2.0]
        realLight.addChild(beamVisual)
        
        model.addChild(realLight)
    }

    
    func addLEDPanel(to model: Entity) {
        let lightGroup = Entity()
        lightGroup.name = "LED_Guts_Group"
        
        // Scale isolation: ensure light math is in meters relative to 0.01 parent scale
        lightGroup.scale = SIMD3(repeating: 80.0)
        
        // 1. Setup the SpotLight (The actual light emitter)
        let ledWash = SpotLight()
        ledWash.light.intensity = 200000
        ledWash.light.innerAngleInDegrees = 65
        ledWash.light.outerAngleInDegrees = 110
        ledWash.light.color = .white
        
        // 📍 PLACEMENT: 1.6m high (center of panel) and 0.02m back from the very front
        ledWash.position = [0, 1.5, 0.02]
        ledWash.orientation = simd_quaternion(
            Float.pi - (.pi * 2 / 3),
            [0, 1, 0]
        )
        
        lightGroup.addChild(ledWash)
        model.addChild(lightGroup)
    }

    
    func addLantern(to model: Entity) {
        let lanternGroup = Entity()
        lanternGroup.name = "Lantern_Guts_Group"
        
        lanternGroup.scale = SIMD3(repeating: 80.0)
        
        let lanternWash = PointLight()
        lanternWash.name = "LanternInternalLight"
        
        lanternWash.light.intensity = 100000
        lanternWash.light.color = .systemYellow
        lanternWash.light.attenuationRadius = 5.0
        lanternWash.position = [0, 0.5, 0]
        
        lanternGroup.addChild(lanternWash)
        model.addChild(lanternGroup)
    }

    
    func spawnPointLight() {
        let lightEntity = PointLight()
        lightEntity.light.intensity = 12000
        lightEntity.light.color = .systemRed
        lightEntity.light.attenuationRadius = 10.0
        let bulb = ModelEntity(
            mesh: .generateSphere(radius: 0.1),
            materials: [UnlitMaterial(color: .yellow)]
        )
        lightEntity.addChild(bulb)
        lightEntity.name = "DynamicPointLight"
        lightEntity.position = [0, 1.0, 0]  // 1 meter
        lightEntity.components.set(
            CollisionComponent(shapes: [.generateSphere(radius: 0.1)])
        )
        lightEntity.components.set(InputTargetComponent())
        
        if let anchor = arView.scene.findEntity(named: "MainAnchor") {
            anchor.addChild(lightEntity)
            if let interactable = lightEntity
                as? (Entity & HasCollision & HasTransform)
            {
                arView.installGestures([.translation], for: interactable)
            }
        }
    }

    
    func setPointLightIntensity(_ lumens: Float) {
        guard
            let light = arView.scene.findEntity(named: "DynamicPointLight")
                as? PointLight
        else { return }
        light.light.intensity = lumens
    }

    func moveLight(to position: SIMD3<Float>) {
        arView.scene.findEntity(named: "PointLightSource")?.position = position
    }

    
    func spawnWall() {
        guard let anchor = arView.scene.findEntity(named: "MainAnchor") else {
            return
        }
        
        let wallRoot = ModelEntity()
        wallRoot.name = "Wall"
        
        wallRoot.components.set(
            CategoryComponent(toolType: .wall)
        )
        
        let mesh = MeshResource.generateBox(
            width: 1.5,
            height: 1.2,
            depth: 0.05
        )
        
        let material = SimpleMaterial(
            color: .lightGray,
            roughness: 0.6,
            isMetallic: false
        )
        
        wallRoot.model = ModelComponent(mesh: mesh, materials: [material])
        
        wallRoot.position = [0, 0.6, -2]
        
        wallRoot.generateCollisionShapes(recursive: true)
        wallRoot.components.set(InputTargetComponent())
        
        wallRoot.components.set(WallComponent())
        
        anchor.addChild(wallRoot)
    }

    
    func spawnGround() {
        guard let anchor = arView.scene.findEntity(named: "MainAnchor") else {
            return
        }
        
        let ground = ModelEntity()
        ground.name = "Ground"
        
        ground.components.set(
            CategoryComponent(toolType: .wall)
        )
        
        let mesh = MeshResource.generatePlane(
            width: 4,
            depth: 4
        )
        
        let material = SimpleMaterial(
            color: .darkGray.withAlphaComponent(1),
            roughness: 1.0,
            isMetallic: false
        )
        
        ground.model = ModelComponent(mesh: mesh, materials: [material])
        
        ground.position = [0, 0, 0]
        
        ground.generateCollisionShapes(recursive: true)
        ground.components.set(InputTargetComponent())
        
        ground.components.set(GroundComponent(width: 4, depth: 4))
        
        anchor.addChild(ground)
    }


    func spawnCharacter(item: SpawnItem, scale: Float) {

        guard !item.modelFileName.isEmpty else {
            print(" Empty modelFileName")
            return
        }

        do {
            let entity = try Entity.load(named: item.modelFileName)
            entity.scale = SIMD3(repeating: scale)

            let anchor = AnchorEntity(world: .zero)
            anchor.addChild(entity)
            arView.scene.addAnchor(anchor)

            print(" Character spawned successfully")

        } catch {
            print("Failed to load character model:", error)
        }
    }


    func didConfirmCharacterSelection(
        item: SpawnItem,
        scale: Float,
        name: String
    ) {
        print("✅ Character confirmed:", item.title)
        print("📝 Model File To Load:", item.modelFileName)  // Verify this prints "Woman1Sit"

        // 1. Create a copy of the item to ensure the name is correct
        var finalItem = item
        finalItem.title = name

        // 2. CRITICAL FIX: Wrap the async call in 'Task' and use the correct function name
        Task {
            // Use 'spawnEntity', NOT 'spawnCharacter'
            await spawnEntity(
                item: finalItem,
                toolType: .character,
                customName: name,
                scale: scale
            )
        }

        dismiss(animated: true)
    }




    func handleBackgroundSelection(_ item: BackgroundItem) {
        print("Canvas received background: \(item.title)")
        let spawnItem = SpawnItem(background: item)
        self.spawnEntity(item: spawnItem, toolType: .background)
    }


    private func captureCanvasAndShare(isPNG: Bool) {
        // Hide UI elements you don't want in the final photo
        layersButton.isHidden = true
        playbackButtonStack.isHidden = true
        
        // Use RealityKit's native snapshot for high-quality 3D rendering
        arView.snapshot(saveToHDR: false) { [weak self] image in
            guard let self = self, let image = image else { return }
            
            let data: Data? =
            isPNG
            ? image.pngData() : image.jpegData(compressionQuality: 0.9)
            
            guard let exportData = data,
                  let imageToShare = UIImage(data: exportData)
            else { return }
            
            let activityVC = UIActivityViewController(
                activityItems: [imageToShare],
                applicationActivities: nil
            )
            
            // iPad Support
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = self.view
                popover.sourceRect = CGRect(
                    x: self.view.bounds.midX,
                    y: self.view.bounds.midY,
                    width: 0,
                    height: 0
                )
            }
            
            self.present(activityVC, animated: true) {
                // Bring UI back after capture
                self.layersButton.isHidden = false
                self.playbackButtonStack.isHidden = false
            }
        }
    }


    @objc func exportTapped() {
        let exportVC = ExportVC()
        
        exportVC.projectName = "Film: Project Alpha"
        
        exportVC.onFormatSelected = { [weak self] format in
            guard let self = self else { return }
            
            // 1. Dismiss the modal first
            exportVC.dismiss(animated: true) {
                // 2. Based on the selection, trigger the capture
                if format == "JPEG" {
                    self.captureCanvasAndShare(isPNG: false)
                } else if format == "PNG" {
                    self.captureCanvasAndShare(isPNG: true)
                } else {
                    // Placeholder for PDF/MP4
                    let alert = UIAlertController(
                        title: "Info",
                        message: "\(format) export coming soon!",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
        
        // 3. Presentation Logic for a nice half-screen sheet
        if let sheet = exportVC.sheetPresentationController {
            sheet.detents = [.medium()]  // Only takes up half the screen
            sheet.prefersGrabberVisible = true  // Shows the little handle at the top
        }
        
        self.present(exportVC, animated: true)
    }

}
