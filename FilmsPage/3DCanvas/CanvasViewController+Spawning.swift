//
//  CanvasViewController+Spawning.swift
//  3DCanvas
//

import Combine
import PhotosUI
import RealityKit
import UIKit
import ARKit

// MARK: - CharacterDetailDelegate

extension CanvasViewController: CharacterDetailDelegate {}

// MARK: - Spawning

extension CanvasViewController {

    // MARK: Background plane

    func spawnBackgroundPlane(_ item: SpawnItem) {
        if let customImage = item.customImage {
            applyBackgroundImage(customImage)
            return
        }
        if let imageName = item.imageName, let image = UIImage(named: imageName) {
            applyBackgroundImage(image)
            return
        }
        print("Error: No image found for background \(item.title)")
    }

    
    func applySky(type: String) {

            // 1. Remove existing sky (check both naming conventions for backward compatibility)

            if let existingSky = arView.scene.findEntity(named: "ProceduralSky") {

                existingSky.removeFromParent()

            }
            
            // Also remove any ProceduralSky_<type> entities
            if let anchor = arView.scene.findEntity(named: "MainAnchor") as? AnchorEntity {
                for child in anchor.children {
                    if child.name.hasPrefix("ProceduralSky_") {
                        child.removeFromParent()
                    }
                }
            }

            

            var skyMaterial = UnlitMaterial()

            var topColor: UIColor = .systemBlue

            

            // 2. Load Texture or Color

    //        if type == "sky_image_1" {

    //            if let texture = try? TextureResource.load(named: type) {

            let imageSkyTypes: Set<String> = ["Blue_sky", "Evening_sky", "Nighty_night"]  // add new names here



            if imageSkyTypes.contains(type) {

                if let texture = try? TextureResource.load(named: type) {

            

                    skyMaterial.color.texture = .init(texture)

                    arView.environment.background = .color(.black)

                } else {

                    topColor = .systemGray

                    skyMaterial.color.tint = topColor

                    arView.environment.background = .color(topColor)

                }

            }

            // 3. Create Sphere

            let skyMesh = MeshResource.generateSphere(radius: 50)

            let skyEntity = ModelEntity(mesh: skyMesh, materials: [skyMaterial])

            // FIX: Name should include type for proper saving/loading
            skyEntity.name = "ProceduralSky_\(type)"

            

            // 4. THE FIX FOR INVERSION:

            // Instead of just flipping scale, we also apply a 180-degree rotation

            // around the X-axis to fix the "upside down" issue.

            skyEntity.scale *= -1

            skyEntity.orientation = simd_quatf(angle: .pi, axis: [1, 0, 0])

            

            // 5. Final Setup

            skyEntity.components.set(CategoryComponent(toolType: .sky))

            

            if let anchor = arView.scene.findEntity(named: "MainAnchor") {

                anchor.addChild(skyEntity)

            }

        }
    
    func applyBackgroundImage(_ image: UIImage) {
        guard let anchor = mainAnchor else { return }

        // FIX: Use an async Task so we can await TextureResource and also use the
        // sRGB-safe CGImage path — avoids crashes on Display P3 / wide-gamut devices.
        // FIX E: Increment pendingBackgroundTasks so saveAndExit() waits for the
        // texture upload to finish before writing the JSON (otherwise cachedImage may
        // still be nil at save time and the background texture is silently lost).
        pendingBackgroundTasks += 1
        Task { @MainActor in
            defer { pendingBackgroundTasks -= 1 }
            do {
                let safeCG  = image.sRGBCGImage()
                let texture = try await TextureResource(
                    image:   safeCG,
                    options: .init(semantic: .color)
                )
                var material = UnlitMaterial()
                material.color.texture = .init(texture)

                backgroundCounter += 1
                let uniqueName = "Background_\(backgroundCounter)"

                let aspect:    Float = Float(image.size.width / image.size.height)
                let height:    Float = 1.5
                let width:     Float = height * aspect
                let thickness: Float = 0.05

                let mesh  = MeshResource.generateBox(width: width, height: height, depth: thickness)
                let plane = ModelEntity(mesh: mesh, materials: [material])
                plane.name = uniqueName

                // FIX: Assign stable UUID so entity references in animations persist across save/load cycles
                plane.components.set(EntityIDComponent(id: UUID()))

                // Store in the VC-level cache so save() can always find the UIImage
                // even if BackgroundComponent.cachedImage is later lost.
                self.backgroundImageCache[uniqueName] = image

                // FIX: store the original UIImage in the component so the persistence
                // service can extract it during save without needing to decode the GPU texture.
                plane.components.set(
                    BackgroundComponent(width: width, height: height, cachedImage: image)
                )

                plane.generateCollisionShapes(recursive: true)
                plane.components.set(InputTargetComponent())
                plane.orientation = simd_quatf(angle: .pi, axis: [0, 0, 1])  // 180° rotation around Z to flip texture vertically
                plane.components.set(CategoryComponent(toolType: .background))

                let offset = Float(backgroundCounter) * 0.1
                plane.position = [offset, height / 2, -2.1 - offset]

                anchor.addChild(plane)
                backgroundPlane = plane

                refreshSidebarContent()
            } catch {
                print("⚠️ Texture creation failed: \(error)")
            }
        }
    }

    // MARK: Lights

    func addRealLightToModel(_ model: Entity) {
        let realLight = SpotLight()
        realLight.light.intensity          = 200_000
        realLight.light.innerAngleInDegrees = 10
        realLight.light.outerAngleInDegrees = 30
        realLight.light.attenuationRadius  = 20.0
        realLight.shadow    = SpotLightComponent.Shadow()
        realLight.orientation = simd_quaternion(Float.pi, [0, 1, 0])
        realLight.position  = [0, 0, 0.2]

        let lensGlow = ModelEntity(
            mesh:      .generateSphere(radius: 0.1),
            materials: [UnlitMaterial(color: .yellow)]
        )
        lensGlow.position = [10, 10, 0.1]
        model.addChild(lensGlow)

        var beamMat = UnlitMaterial(color: .white)
        beamMat.blending = .transparent(opacity: .init(floatLiteral: 0.2))
        let beamVisual = ModelEntity(
            mesh:      MeshResource.generateCone(height: 4.0, radius: 1.0),
            materials: [beamMat]
        )
        beamVisual.orientation = simd_quaternion(-Float.pi / 2, [1, 0, 0])
        beamVisual.position    = [0, 0, -2.0]
        realLight.addChild(beamVisual)

        model.addChild(realLight)
    }

    func addLEDPanel(to model: Entity) {
        let lightGroup      = Entity()
        lightGroup.name     = "LED_Guts_Group"
        lightGroup.scale    = SIMD3(repeating: 80.0)

        let ledWash         = SpotLight()
        ledWash.light.intensity          = 200_000
        ledWash.light.innerAngleInDegrees = 65
        ledWash.light.outerAngleInDegrees = 110
        ledWash.light.color              = .white
        ledWash.position    = [0, 1.5, 0.02]
        ledWash.orientation = simd_quaternion(Float.pi - (.pi * 2 / 3), [0, 1, 0])

        lightGroup.addChild(ledWash)
        model.addChild(lightGroup)
    }

    func addLantern(to model: Entity) {
        let lanternGroup    = Entity()
        lanternGroup.name   = "Lantern_Guts_Group"
        lanternGroup.scale  = SIMD3(repeating: 80.0)

        let lanternWash     = PointLight()
        lanternWash.name    = "LanternInternalLight"
        lanternWash.light.intensity       = 100_000
        lanternWash.light.color           = .systemYellow
        lanternWash.light.attenuationRadius = 5.0
        lanternWash.position = [0, 0.5, 0]

        lanternGroup.addChild(lanternWash)
        model.addChild(lanternGroup)
    }

    // MARK: Point light

    func spawnPointLight() {
        let lightEntity = PointLight()
        lightEntity.light.intensity       = 12_000
        lightEntity.light.color           = .systemRed
        lightEntity.light.attenuationRadius = 10.0

        let bulb = ModelEntity(
            mesh:      .generateSphere(radius: 0.1),
            materials: [UnlitMaterial(color: .yellow)]
        )
        lightEntity.addChild(bulb)
        lightEntity.name     = "DynamicPointLight"
        lightEntity.position = [0, 1.0, 0]
        lightEntity.components.set(
            CollisionComponent(shapes: [.generateSphere(radius: 0.1)])
        )
        lightEntity.components.set(InputTargetComponent())

        // FIX: use cached mainAnchor — not a new AnchorEntity
        if let anchor = mainAnchor {
            anchor.addChild(lightEntity)
        }
    }

    func setPointLightIntensity(_ lumens: Float) {
        guard let light = mainAnchor?.findEntity(named: "DynamicPointLight") as? PointLight
        else { return }
        light.light.intensity = lumens
    }

    func moveLight(to position: SIMD3<Float>) {
        mainAnchor?.findEntity(named: "PointLightSource")?.position = position
    }

    // MARK: Wall / Ground

    /// Legacy wall spawn (color-only, for backward compat).
    func spawnWall(color: UIColor? = nil) -> ModelEntity? {
        guard let anchor = mainAnchor else { return nil }

        let wallRoot = ModelEntity()
        wallRoot.name = {
            let base     = "Wall"
            let existing = anchor.children.filter {
                $0.name == base || $0.name.hasPrefix(base + "_")
            }.count
            return existing == 0 ? base : "\(base)_\(existing + 1)"
        }()

        var wallComp = WallComponent()
        if let color = color {
            wallComp.uiColor = color
        }
        wallRoot.model = ModelComponent(
            mesh: MeshResource.generateBox(width: 1.5, height: 1.2, depth: 0.05),
            materials: [SimpleMaterial(color: wallComp.uiColor, roughness: 0.6, isMetallic: false)]
        )
        wallRoot.position = [0, 0.6, -2]
        wallRoot.generateCollisionShapes(recursive: true)
        wallRoot.components.set(InputTargetComponent())
        wallRoot.components.set(CategoryComponent(toolType: .wall))
        wallRoot.components.set(wallComp)

        anchor.addChild(wallRoot)
        return wallRoot as? ModelEntity
    }

    /// Cinematic wall spawn with material configuration.
    func spawnCinematicWall(width: Float, height: Float, thickness: Float,
                            materialConfig: CinematicMaterialConfig) -> ModelEntity? {
        guard let anchor = mainAnchor else { return nil }

        let wallRoot = ModelEntity()
        wallRoot.name = {
            let base     = "Wall"
            let existing = anchor.children.filter {
                $0.name == base || $0.name.hasPrefix(base + "_")
            }.count
            return existing == 0 ? base : "\(base)_\(existing + 1)"
        }()

        var wallComp = WallComponent()
        wallComp.width = width
        wallComp.height = height
        wallComp.thickness = thickness
        wallComp.materialConfig = materialConfig
        wallComp.uiColor = materialConfig.tintColor

        // Start with a simple material placeholder; async material applied below
        let simpleMat = CinematicMaterialManager.shared.buildSimpleMaterial(from: materialConfig)
        wallRoot.model = ModelComponent(
            mesh: MeshResource.generateBox(width: width, height: height, depth: thickness),
            materials: [simpleMat]
        )
        wallRoot.position = [0, height / 2, -2]
        wallRoot.generateCollisionShapes(recursive: true)
        wallRoot.components.set(InputTargetComponent())
        wallRoot.components.set(CategoryComponent(toolType: .wall))
        wallRoot.components.set(wallComp)

        anchor.addChild(wallRoot)

        // Apply full PBR material asynchronously
        Task { @MainActor in
            await CinematicMaterialManager.shared.applyMaterial(materialConfig, to: wallRoot)
        }

        return wallRoot as? ModelEntity
    }

    /// Legacy ground spawn (color-only, for backward compat).
     func spawnGround(color: UIColor? = nil) -> ModelEntity? {
         guard let anchor = mainAnchor else { return nil }

         let ground = ModelEntity()
         ground.name = {
             let base     = "Ground"
             let existing = anchor.children.filter {
                 $0.name == base || $0.name.hasPrefix(base + "_")
             }.count
             return existing == 0 ? base : "\(base)_\(existing + 1)"
         }()

         var groundComp = GroundComponent(width: 4, depth: 4)
         if let color = color {
             groundComp.uiColor = color
         }
         ground.model = ModelComponent(
             mesh: MeshResource.generatePlane(width: 4, depth: 4),
             materials: [SimpleMaterial(color: groundComp.uiColor, roughness: 1.0, isMetallic: false)]
         )
         ground.position = [0, 0, 0]
         ground.generateCollisionShapes(recursive: true)
         ground.components.set(InputTargetComponent())
         ground.components.set(CategoryComponent(toolType: .wall))
         ground.components.set(groundComp)

         anchor.addChild(ground)
         return ground as? ModelEntity
     }

    /// Cinematic ground spawn with material configuration.
    func spawnCinematicGround(size: Float, materialConfig: CinematicMaterialConfig) -> ModelEntity? {
        guard let anchor = mainAnchor else { return nil }

        let ground = ModelEntity()
        ground.name = {
            let base     = "Ground"
            let existing = anchor.children.filter {
                $0.name == base || $0.name.hasPrefix(base + "_")
            }.count
            return existing == 0 ? base : "\(base)_\(existing + 1)"
        }()

        var groundComp = GroundComponent(width: size, depth: size)
        groundComp.materialConfig = materialConfig
        groundComp.uiColor = materialConfig.tintColor

        let simpleMat = CinematicMaterialManager.shared.buildSimpleMaterial(from: materialConfig)
        ground.model = ModelComponent(
            mesh: MeshResource.generatePlane(width: size, depth: size),
            materials: [simpleMat]
        )
        ground.position = [0, 0, 0]
        ground.generateCollisionShapes(recursive: true)
        ground.components.set(InputTargetComponent())
        ground.components.set(CategoryComponent(toolType: .wall))
        ground.components.set(groundComp)

        anchor.addChild(ground)

        // Apply full PBR material asynchronously
        Task { @MainActor in
            await CinematicMaterialManager.shared.applyMaterial(materialConfig, to: ground)
        }

        return ground as? ModelEntity
    }

     // MARK: - Color Management

     func applyColor(_ color: UIColor, to entity: ModelEntity) {
         // Update the visual material and component color for walls
         if var comp = entity.components[WallComponent.self] {
             if let config = comp.materialConfig {
                 // Cinematic wall — update tint and re-apply material
                 var updated = config
                 updated.tintColor = color
                 comp.materialConfig = updated
                 comp.uiColor = color
                 entity.components.set(comp)
                 Task { @MainActor in
                     await CinematicMaterialManager.shared.applyMaterial(updated, to: entity)
                 }
             } else {
                 // Legacy wall — simple color
                 entity.model?.materials = [SimpleMaterial(color: color, roughness: 0.6, isMetallic: false)]
                 comp.uiColor = color
                 entity.components.set(comp)
             }
         }
         // Update the visual material and component color for ground
         else if var comp = entity.components[GroundComponent.self] {
             if let config = comp.materialConfig {
                 var updated = config
                 updated.tintColor = color
                 comp.materialConfig = updated
                 comp.uiColor = color
                 entity.components.set(comp)
                 Task { @MainActor in
                     await CinematicMaterialManager.shared.applyMaterial(updated, to: entity)
                 }
             } else {
                 entity.model?.materials = [SimpleMaterial(color: color, roughness: 1.0, isMetallic: false)]
                 comp.uiColor = color
                 entity.components.set(comp)
             }
         }
     }

    // MARK: Character

    /// Legacy synchronous loader — retained for backward compatibility.
    /// Prefer `spawnEntity(item:toolType:)` for new code.
    func spawnCharacter(item: SpawnItem, scale: Float) {
        guard !item.modelFileName.isEmpty else {
            print("⚠️ spawnCharacter: empty modelFileName")
            return
        }
        // FIX: was creating a new AnchorEntity per character (memory leak).
        // Now correctly places the entity under the shared MainAnchor.
        guard let anchor = mainAnchor else { return }
        do {
            let entity = try Entity.load(named: item.modelFileName)
            entity.scale = SIMD3(repeating: scale)
            anchor.addChild(entity)
            print("✅ Character spawned: \(item.title)")
        } catch {
            print("⚠️ Failed to load character model '\(item.modelFileName)': \(error)")
        }
    }

    func didConfirmCharacterSelection(item: SpawnItem, scale: Float, name: String) {
        print("✅ Character confirmed: \(item.title)")
        print("📝 Model file: \(item.modelFileName)")

        var finalItem   = item
        finalItem.title = name

        Task {
            await spawnEntity(item: finalItem, toolType: .character, customName: name, scale: scale)
        }

        dismiss(animated: true)
    }

    func handleBackgroundSelection(_ item: BackgroundItem) {
        print("Canvas received background: \(item.title)")
        let spawnItem = SpawnItem(background: item)
        spawnEntity(item: spawnItem, toolType: .background)
    }

    // MARK: Export / snapshot

    private func captureCanvasAndShare(isPNG: Bool) {
        layersButton.isHidden        = true
        playbackButtonStack.isHidden = true

        arView.snapshot(saveToHDR: false) { [weak self] image in
            guard let self = self, let image = image else { return }

            let data: Data? = isPNG
                ? image.pngData()
                : image.jpegData(compressionQuality: 0.9)

            guard let exportData  = data,
                  let imageToShare = UIImage(data: exportData) else { return }

            let activityVC = UIActivityViewController(
                activityItems: [imageToShare],
                applicationActivities: nil
            )

            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = self.view
                popover.sourceRect = CGRect(
                    x: self.view.bounds.midX,
                    y: self.view.bounds.midY,
                    width: 0, height: 0
                )
            }

            self.present(activityVC, animated: true) {
                self.layersButton.isHidden        = false
                self.playbackButtonStack.isHidden = false
            }
        }
    }

    @objc func exportTapped() {
        let exportVC         = ExportVC()
        exportVC.projectName = "Film: Project Alpha"

        exportVC.onFormatSelected = { [weak self] format in
            guard let self = self else { return }
            exportVC.dismiss(animated: true) {
                switch format {
                case "JPEG": self.captureCanvasAndShare(isPNG: false)
                case "PNG":  self.captureCanvasAndShare(isPNG: true)
                default:
                    let alert = UIAlertController(
                        title:   "Info",
                        message: "\(format) export coming soon!",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }

        if let sheet = exportVC.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }

        present(exportVC, animated: true)
    }
}

// MARK: - UIImage → sRGB CGImage (internal — shared with ScenePersistence)

extension UIImage {
    /// Returns a CGImage guaranteed to be in the sRGB colour space.
    ///
    /// `UIImage.cgImage` can be nil for CIImage-backed images and may use a wide-gamut
    /// colour space (Display P3) on modern devices, which causes
    /// `TextureResource(image:options:)` to fail or produce incorrect colours.
    /// Drawing into a fresh Device-RGB `CGContext` always yields a compatible result.
    ///
    /// NOTE: The fast path (`if let cg = cgImage { return cg }`) has been intentionally
    /// removed.  On Display P3 / wide-gamut devices `cgImage` is a P3 image; passing it
    /// directly to TextureResource either throws or produces washed-out colours.
    /// We ALWAYS re-render through a Device-RGB context to guarantee sRGB output.
    func sRGBCGImage() -> CGImage {
        // Always render into a Device-RGB bitmap context.
        // This normalises CIImage-backed UIImages, wide-gamut P3 images, and images with
        // non-standard colour spaces into a single compatible format for TextureResource.
        let w  = Int(size.width  * scale)
        let h  = Int(size.height * scale)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data:             nil,
            width:            max(w, 1),
            height:           max(h, 1),
            bitsPerComponent: 8,
            bytesPerRow:      0,
            space:            cs,
            bitmapInfo:       CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            fatalError("sRGBCGImage: failed to create CGContext for \(self)")
        }
        UIGraphicsPushContext(ctx)
        draw(in: CGRect(x: 0, y: 0, width: w, height: h))
        UIGraphicsPopContext()
        return ctx.makeImage()!
    }
}
