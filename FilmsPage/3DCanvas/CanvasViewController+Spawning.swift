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
        realLight.light.innerAngleInDegrees = 50
        realLight.light.outerAngleInDegrees = 90
        realLight.light.attenuationRadius  = 20.0
        realLight.shadow    = SpotLightComponent.Shadow()
        // WITH this (rotate slightly to the RIGHT):

        realLight.orientation = simd_quatf()
        realLight.position  = [0, 0, 0]

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

    // MARK: - Procedural Light Builder

    /// Builds a complete procedural light entity from RealityKit primitive geometry.
    /// No .usdz file involved — zero bundle storage cost.
    /// Returns a root Entity ready for `attachLight(to:config:)`.
    func buildProceduralLight(kind: ProceduralLightKind, colorTemp: Float = 5600) -> Entity {
        let root = Entity()

        switch kind {

        // ════════════════════════════════════════════════════════════════════
        // PRACTICAL LANTERN — round paper lantern with warm glow
        // ════════════════════════════════════════════════════════════════════
        case .practicalLantern:
            let lanternColor = UIColor.fromKelvin(colorTemp)

            // Main globe — emissive sphere, OPAQUE so it doesn’t vanish under its own light
            var globeMat = PhysicallyBasedMaterial()
            globeMat.baseColor = .init(tint: lanternColor)
            globeMat.emissiveColor = .init(color: lanternColor)
            globeMat.emissiveIntensity = 2.0
            // No transparency — the model stays visible even when the point light is bright

            let globe = ModelEntity(
                mesh: .generateSphere(radius: 0.30),
                materials: [globeMat]
            )
            globe.name = "ProceduralGlobe"
            root.addChild(globe)

            // Top cap — small dark fitting (doubled proportionally)
            let capMat = SimpleMaterial(color: .darkGray, roughness: 0.8, isMetallic: true)
            let topCap = ModelEntity(
                mesh: .generateCylinder(height: 0.05, radius: 0.08),
                materials: [capMat]
            )
            topCap.name = "ProceduralTopCap"
            topCap.position = [0, 0.28, 0]
            root.addChild(topCap)

            // Bottom cap (doubled proportionally)
            let bottomCap = ModelEntity(
                mesh: .generateCylinder(height: 0.03, radius: 0.06),
                materials: [capMat]
            )
            bottomCap.name = "ProceduralBottomCap"
            bottomCap.position = [0, -0.28, 0]
            root.addChild(bottomCap)

        // ════════════════════════════════════════════════════════════════════
        // FLUORESCENT TUBE — long horizontal strip light
        // ════════════════════════════════════════════════════════════════════
        case .fluorescentTube:
            // Housing — dark grey box
            let housingMat = SimpleMaterial(color: UIColor(white: 0.2, alpha: 1.0), roughness: 0.7, isMetallic: false)
            let housing = ModelEntity(
                mesh: .generateBox(width: 1.2, height: 0.05, depth: 0.08),
                materials: [housingMat]
            )
            housing.name = "ProceduralHousing"
            root.addChild(housing)

            // Tube face — white emissive strip
            var faceMat = PhysicallyBasedMaterial()
            faceMat.baseColor = .init(tint: .white)
            faceMat.emissiveColor = .init(color: UIColor.fromKelvin(colorTemp))
            faceMat.emissiveIntensity = 4.0

            let face = ModelEntity(
                mesh: .generateBox(width: 1.15, height: 0.03, depth: 0.01),
                materials: [faceMat]
            )
            face.name = "ProceduralFace"
            face.position = [0, 0, -0.041]  // offset to front face bottom
            root.addChild(face)

            // End caps
            let endCapMat = SimpleMaterial(color: UIColor(white: 0.25, alpha: 1.0), roughness: 0.6, isMetallic: false)
            for xSign: Float in [-1, 1] {
                let endCap = ModelEntity(
                    mesh: .generateBox(width: 0.02, height: 0.05, depth: 0.08),
                    materials: [endCapMat]
                )
                endCap.name = "ProceduralEndCap"
                endCap.position = [xSign * 0.61, 0, 0]
                root.addChild(endCap)
            }

        // ════════════════════════════════════════════════════════════════════
        // SKY PANEL — large flat rectangular soft panel
        // ════════════════════════════════════════════════════════════════════
        case .skyPanel:
            // Frame — dark grey/black housing
            let frameMat = SimpleMaterial(color: UIColor(white: 0.15, alpha: 1.0), roughness: 0.6, isMetallic: true)
            let frame = ModelEntity(
                mesh: .generateBox(width: 1.25, height: 1.05, depth: 0.06),
                materials: [frameMat]
            )
            frame.name = "ProceduralFrame"
            root.addChild(frame)

            // Face — white emissive plane
            var faceMat = PhysicallyBasedMaterial()
            faceMat.baseColor = .init(tint: .white)
            faceMat.emissiveColor = .init(color: UIColor.fromKelvin(colorTemp))
            faceMat.emissiveIntensity = 5.0

            let face = ModelEntity(
                mesh: .generatePlane(width: 1.15, depth: 0.95),
                materials: [faceMat]
            )
            face.name = "ProceduralFace"
            // Plane generates in XZ, so rotate to face forward (XY plane facing -Z)
            face.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
            face.position = [0, 0, -0.035]  // slightly forward of frame
            root.addChild(face)

            // Speed rail / yoke mount bar on top
            let yokeMat = SimpleMaterial(color: UIColor(white: 0.3, alpha: 1.0), roughness: 0.5, isMetallic: true)
            let yoke = ModelEntity(
                mesh: .generateCylinder(height: 1.35, radius: 0.015),
                materials: [yokeMat]
            )
            yoke.name = "ProceduralYoke"
            yoke.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
            yoke.position = [0, 0.58, 0]
            root.addChild(yoke)
        }
        root.scale = SIMD3<Float>(repeating: 0.25) //new line
        root.generateCollisionShapes(recursive: true)
        return root
    }

    // MARK: - Unified Light Attachment (New Architecture)

    func attachLight(to model: Entity, config: LightConfigComponent) {

        // ── 1. CLEAN UP ────────────────────────────────────────────────────
        for name in ["LightCore", "LensGlow", "BeamCone", "GlowAnchor",
                     "DiffuseFill", "GoboCookie", "GoboBeam", "GoboGate",
                     "LED_Guts_Group", "Lantern_Guts_Group",
                     "LanternInternalLight", "LanternGlowFallback"] {
            model.findEntity(named: name)?.removeFromParent()
        }

        // ── 2. READ BOUNDS — relativeTo: model = LOCAL space ───────────────
        let b = model.visualBounds(relativeTo: model)
        print("LIGHT [\(config.lightKind)] bounds: min=\(b.min) max=\(b.max) center=\(b.center) extents=\(b.extents)")

        // ── 3. COUNTER-SCALE — ONLY for RealityKit light entities ──────────
        let cs: Float = 1.0 / config.modelScale

        switch config.lightKind {

      
        case .point:
            // Place point light in the center of the lantern
            let glowY = b.min.y + (b.extents.y * 0.50)

            let point = PointLight()
            point.name                    = "LightCore"
            point.light.intensity         = config.intensity
            point.light.color             = config.effectiveColor
            point.light.attenuationRadius = config.attenuationRadius
            point.scale                   = SIMD3(repeating: cs)
            point.position = SIMD3<Float>(b.center.x, glowY, b.center.z)
            model.addChild(point)

            // --------------------------------------------------------
            // Visible glowing bulb inside the lantern
            // --------------------------------------------------------
            let bulbRadius = min(b.extents.x, b.extents.z) * 0.12

            let bulb = ModelEntity(
                mesh: .generateSphere(radius: bulbRadius),
                materials: [UnlitMaterial(color: config.effectiveColor)]
            )

            bulb.name = "LanternBulb"
            bulb.position = SIMD3<Float>(b.center.x, glowY, b.center.z)
            model.addChild(bulb)

            // --------------------------------------------------------
            // Apply emissive glow to transparent glass materials
            // --------------------------------------------------------
            var glassFound = false   // <-- REQUIRED

            func addGlassGlow(_ entity: Entity) {
                if let me = entity as? ModelEntity, var mc = me.model {
                    var newMaterials: [any RealityKit.Material] = []
                    var changed = false

                    for mat in mc.materials {
                        if var pbr = mat as? PhysicallyBasedMaterial {
                            if case .transparent = pbr.blending {
                                pbr.emissiveColor     = .init(color: config.effectiveColor)
                                pbr.emissiveIntensity = 3.0
                                newMaterials.append(pbr)
                                changed = true
                                glassFound = true
                                print("LANTERN: emissive applied to \(me.name)")
                            } else {
                                newMaterials.append(mat)
                            }
                        } else {
                            newMaterials.append(mat)
                        }
                    }

                    if changed {
                        mc.materials = newMaterials
                        me.model = mc
                    }
                }

                for child in entity.children {
                    addGlassGlow(child)
                }
            }

            addGlassGlow(model)

            // --------------------------------------------------------
            // Fallback: if no transparent glass materials were found,
            // add an extra glowing sphere.
            // --------------------------------------------------------
            if !glassFound {
                print("LANTERN: no transparent materials found — adding fallback glow sphere")

                let glowRadius = min(b.extents.x, b.extents.z) * 0.15

                let glow = ModelEntity(
                    mesh: .generateSphere(radius: glowRadius),
                    materials: [UnlitMaterial(color: config.effectiveColor)]
                )

                glow.name = "LanternGlowFallback"
                glow.position = SIMD3<Float>(b.center.x, glowY, b.center.z)

                model.addChild(glow)
            }
        // ════════════════════════════════════════════════════════════════════
        // SPOTLIGHT — beam was 180° backwards, now flipped to -X
        // SpotLight positioned at lens face, not model center
        // NO BeamCone — it caused gizmo crashes from extreme bounds
        // ════════════════════════════════════════════════════════════════════
        case .spot:
            // Determine which axis has the largest extent — that's the lens barrel axis
            let xExt = b.extents.x, yExt = b.extents.y, zExt = b.extents.z
            print("SPOTLIGHT extents: X=\(xExt) Y=\(yExt) Z=\(zExt)")

            let spot = SpotLight()
            spot.name                      = "LightCore"
            spot.light.intensity           = config.intensity
            spot.light.innerAngleInDegrees = config.innerAngleDeg
            spot.light.outerAngleInDegrees = config.outerAngleDeg
            spot.light.color               = config.effectiveColor
            spot.light.attenuationRadius   = config.attenuationRadius
            spot.shadow                    = nil
            spot.scale    = SIMD3(repeating: cs)

            // Position at the lens face (min.x end of the barrel), not model center
            let lensPos = SIMD3<Float>(b.min.x, b.center.y, b.center.z)
            spot.position = lensPos

            // Aim forward along +Z

                spot.look(

                    at: SIMD3<Float>(

                        b.center.x,

                        b.center.y,

                        b.max.z + 500

                    ),

                    from: lensPos,

                    relativeTo: model

                )
            print("SPOTLIGHT: lens at \(lensPos), aiming toward -X")
            model.addChild(spot)

            // ── Gobo gate mask ───────────────────────────────────────────
            if config.activeGobo != .none {
                addGoboGateMask(to: spot, config: config)
            }

        // ════════════════════════════════════════════════════════════════════
        // LED PANEL — SpotLight at panel head (85% height), aimed forward-down
        // The panel head with 4×3 LED circles sits at the top of the tripod.
        // ════════════════════════════════════════════════════════════════════
        case .panel:
            // Position the light near the top of the LED panel
            let panelHeadY = b.min.y + (b.extents.y * 0.85)

            let xExt = b.extents.x
            let yExt = b.extents.y
            let zExt = b.extents.z
            print("LED PANEL extents: X=\(xExt) Y=\(yExt) Z=\(zExt) panelHeadY=\(panelHeadY)")

            let spot = SpotLight()
            spot.name                      = "LightCore"
            spot.light.intensity           = config.intensity
            spot.light.innerAngleInDegrees = config.innerAngleDeg
            spot.light.outerAngleInDegrees = config.outerAngleDeg
            spot.light.color               = config.effectiveColor
            spot.light.attenuationRadius   = config.attenuationRadius
            spot.shadow                    = nil
            spot.scale                     = SIMD3(repeating: cs)

            // Light originates from the front face of the LED panel
            // The panel face is on the -Z side (min.z). We position the light
            // at the panel head center and aim it straight forward along -Z.
            let lensPos = SIMD3<Float>(
                b.center.x,
                panelHeadY,
                b.min.z
            )
            spot.position = lensPos

            // Slight downward tilt
            let aimDownY = panelHeadY - (b.extents.y * 0.15)

            // Aim straight forward (pure -Z, no X offset)
            let forwardDistance: Float = 500.0
            let target = SIMD3<Float>(
                b.center.x,
                aimDownY,
                b.min.z - forwardDistance
            )

            spot.look(
                at: target,
                from: lensPos,
                relativeTo: model
            )

            print("LED PANEL: lens at \(lensPos)")
            print("LED PANEL: aiming at \(target)")

            model.addChild(spot)

            // ── Gobo gate mask (panels can also use gobos) ──────────────
            if config.activeGobo != .none {
                addGoboGateMask(to: spot, config: config)
            }

        } // end switch

        model.components.set(config)
    }

    /// Updates live RealityKit light properties without respawning.
    func updateLightProperties(for entity: Entity, config: LightConfigComponent) {
        guard let lightCore = entity.findEntity(named: "LightCore") else { return }

        switch config.lightKind {
        case .spot, .panel:
            guard let spot = lightCore as? SpotLight else { return }
            spot.light.intensity           = config.intensity
            spot.light.innerAngleInDegrees = config.innerAngleDeg
            spot.light.outerAngleInDegrees = config.outerAngleDeg
            spot.light.color               = config.effectiveColor
            spot.light.attenuationRadius   = config.attenuationRadius

            if config.shadowEnabled {
                var shadow       = SpotLightComponent.Shadow()
                shadow.depthBias = 0.01
                spot.shadow      = shadow
                spot.light.attenuationRadius = min(config.attenuationRadius, 6.0)
            } else {
                spot.shadow = nil
            }


            // ============================================================
            // UPDATE LANTERN LIGHT PROPERTIES
            // ============================================================
            case .point:
                guard let point = lightCore as? PointLight else { return }

                point.light.intensity         = config.intensity
                point.light.color             = config.effectiveColor
                point.light.attenuationRadius = config.attenuationRadius

                // Update visible bulb color
                if let bulb = entity.findEntity(named: "LanternBulb") as? ModelEntity {
                    bulb.model?.materials = [
                        UnlitMaterial(color: config.effectiveColor)
                    ]
                }

                // Update glass emissive color
                func updateGlassGlow(_ entity: Entity) {
                    if let me = entity as? ModelEntity, var mc = me.model {
                        var newMaterials: [any RealityKit.Material] = []
                        var changed = false

                        for mat in mc.materials {
                            if var pbr = mat as? PhysicallyBasedMaterial {
                                if case .transparent = pbr.blending {
                                    pbr.emissiveColor     = .init(color: config.effectiveColor)
                                    pbr.emissiveIntensity = 3.0
                                    newMaterials.append(pbr)
                                    changed = true
                                } else {
                                    newMaterials.append(mat)
                                }
                            } else {
                                newMaterials.append(mat)
                            }
                        }

                        if changed {
                            mc.materials = newMaterials
                            me.model = mc
                        }
                    }

                    for child in entity.children {
                        updateGlassGlow(child)
                    }
                }

                updateGlassGlow(entity)

            // Update fallback glow sphere color if present
            if let fb = entity.findEntity(named: "LanternGlowFallback") as? ModelEntity {
                fb.model?.materials = [UnlitMaterial(color: config.effectiveColor)]
            }
        }

        // ── Update procedural light emissive materials ────────────────────────
        if config.proceduralKind != nil {
            updateProceduralEmissiveMaterials(on: entity, config: config)
        }

        // ── Update gobo gate mask ────────────────────────────────────────────
        updateGoboGateMask(on: entity, config: config)

        entity.components.set(config)
    }

    /// Updates emissive PBR materials on procedural light child entities
    /// when the user changes color temperature or intensity via the slider.
    private func updateProceduralEmissiveMaterials(on entity: Entity, config: LightConfigComponent) {
        let color = config.effectiveColor

        // Practical Lantern — globe sphere
        if let globe = entity.findEntity(named: "ProceduralGlobe") as? ModelEntity {
            var mat = PhysicallyBasedMaterial()
            mat.baseColor = .init(tint: color)
            mat.emissiveColor = .init(color: color)
            mat.emissiveIntensity = 3.0
            mat.blending = .transparent(opacity: .init(floatLiteral: 0.85))
            globe.model?.materials = [mat]
        }

        // Fluorescent Tube / Sky Panel — emissive face
        if let face = entity.findEntity(named: "ProceduralFace") as? ModelEntity {
            var mat = PhysicallyBasedMaterial()
            mat.baseColor = .init(tint: .white)
            mat.emissiveColor = .init(color: color)
            // Tube = 4.0, SkyPanel = 5.0
            mat.emissiveIntensity = (config.proceduralKind == .skyPanel) ? 5.0 : 4.0
            face.model?.materials = [mat]
        }
    }

    // MARK: - Gobo Gate Mask (Shadow-Casting Alpha Plane)
    //
    // RealityKit SpotLightComponent has NO projected-texture property.
    // Correct workaround: a thin alpha-tested plane at the spotlight gate.
    // With shadows enabled, the opaque parts cast gobo-shaped shadows onto
    // scene surfaces (floor, walls, actors). The gate plane is paper-thin
    // and invisible from the side — you only see the shaped light/shadows.
    //
    // REQUIREMENT: Shadows are auto-enabled when a gobo is active.

    /// Adds an alpha-tested gate-mask plane as a child of the SpotLight entity.
    private func addGoboGateMask(to spotEntity: Entity, config: LightConfigComponent) {
        guard config.activeGobo != .none else { return }
        guard let cgImage = config.activeGobo.generateTexture(
            lightColor: config.effectiveColor, resolution: 512
        ) else { return }

        guard let texture = try? TextureResource.generate(
            from: cgImage, options: .init(semantic: .color)
        ) else {
            print("GOBO: failed to create TextureResource")
            return
        }

        // PBR material with opacityThreshold — shadow map respects alpha cutoff
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: .black, texture: .init(texture))
        material.opacityThreshold = 0.5
        material.metallic = .init(floatLiteral: 0)
        material.roughness = .init(floatLiteral: 1)

        // Plane sized to cover beam cross-section at gate distance
        let gateDistance: Float = 0.2
        let outerRad = config.outerAngleDeg * (.pi / 180.0)
        let planeHalf = gateDistance * tan(outerRad / 2.0) * 1.2
        let gateSize = max(0.15, planeHalf * 2.0)

        let gate = ModelEntity(
            mesh: .generatePlane(width: gateSize, height: gateSize),
            materials: [material]
        )
        gate.name = "GoboGate"
        gate.position = SIMD3<Float>(0, 0, -gateDistance)

        spotEntity.addChild(gate)

        // Auto-enable shadows (required for gate mask to cast gobo pattern)
        if let spot = spotEntity as? SpotLight, spot.shadow == nil {
            var shadow = SpotLightComponent.Shadow()
            shadow.depthBias = 0.01
            spot.shadow = shadow
        }

        print("GOBO: gate mask '\(config.activeGobo.displayName)', size=\(gateSize)")
    }

    /// Updates or removes the gobo gate mask on a live entity.
    private func updateGoboGateMask(on entity: Entity, config: LightConfigComponent) {
        guard let lightCore = entity.findEntity(named: "LightCore") else { return }
        lightCore.findEntity(named: "GoboGate")?.removeFromParent()

        guard config.activeGobo != .none,
              config.lightKind == .spot || config.lightKind == .panel else { return }

        addGoboGateMask(to: lightCore, config: config)
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
         // Use an explicit box collision shape with slight thickness (5cm)
         // so the ground is reliably hittable from any camera angle.
         // generateCollisionShapes on a zero-thickness plane is unreliable at oblique angles.
         ground.collision = CollisionComponent(shapes: [
             .generateBox(width: 4, height: 0.05, depth: 4)
         ])
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
        // Use an explicit box collision shape with slight thickness
        // so the ground is reliably hittable from any camera angle.
        ground.collision = CollisionComponent(shapes: [
            .generateBox(width: size, height: 0.05, depth: size)
        ])
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
            DispatchQueue.main.async {
                guard let self = self else { return }
                guard let image = image else {
                    self.layersButton.isHidden        = false
                    self.playbackButtonStack.isHidden = false
                    return
                }

                let data: Data? = isPNG
                    ? image.pngData()
                    : image.jpegData(compressionQuality: 0.9)

                guard let exportData  = data,
                      let imageToShare = UIImage(data: exportData) else {
                    self.layersButton.isHidden        = false
                    self.playbackButtonStack.isHidden = false
                    return
                }

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

    // MARK: - Shadow Casting Fix

    /// Ensures all ModelEntity descendants use shadow-casting materials.
    /// Some USDZ exports (notably the male character "LewScene") bake materials
    /// as UnlitMaterial which opts the mesh out of shadow rendering entirely.
    /// This traverses the hierarchy and promotes any UnlitMaterial to a
    /// PhysicallyBasedMaterial with the same base colour, enabling shadow casting.
    /// Only called on character entities — intentional UnlitMaterial usage on
    /// lights, gizmos, and beam visuals is unaffected.
    func ensureShadowCasting(on entity: Entity) {
        func walk(_ e: Entity) {
            if let model = e as? ModelEntity, var mc = model.model {
                var newMats: [any RealityKit.Material] = []
                var changed = false
                for mat in mc.materials {
                    if let unlit = mat as? UnlitMaterial {
                        // Promote to PBR — preserves base colour, gains shadow casting
                        var pbr = PhysicallyBasedMaterial()
                        pbr.baseColor = unlit.color
                        pbr.roughness = .init(floatLiteral: 0.6)
                        newMats.append(pbr)
                        changed = true
                        print("SHADOW FIX: promoted UnlitMaterial → PBR on \(e.name)")
                    } else {
                        newMats.append(mat)
                    }
                }
                if changed {
                    mc.materials = newMats
                    model.model = mc
                }
            }
            for child in e.children { walk(child) }
        }
        walk(entity)
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
