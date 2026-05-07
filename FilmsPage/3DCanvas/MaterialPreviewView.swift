//
//  MaterialPreviewView.swift
//  FilmsPage
//
//  Live material preview using SceneKit (lightweight, embeddable in SwiftUI).
//  Shows a wall slab or ground plane with the current material configuration.
//

import SwiftUI
import SceneKit

// MARK: - MaterialPreviewView

struct MaterialPreviewView: UIViewRepresentable {
    let config: CinematicMaterialConfig
    let isWall: Bool  // true = wall slab, false = ground plane

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.backgroundColor = UIColor(white: 0.08, alpha: 1)
        scnView.antialiasingMode = .multisampling4X
        scnView.allowsCameraControl = false
        scnView.autoenablesDefaultLighting = false

        let scene = SCNScene()
        scnView.scene = scene

        // Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 30
        if isWall {
            cameraNode.position = SCNVector3(0, 0, 3.5)
        } else {
            cameraNode.position = SCNVector3(0, 2.5, 2.5)
            cameraNode.eulerAngles = SCNVector3(-Float.pi / 4, 0, 0)
        }
        scene.rootNode.addChildNode(cameraNode)

        // Lighting
        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.intensity = 800
        keyLight.light?.color = UIColor(white: 0.95, alpha: 1)
        keyLight.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 6, 0)
        scene.rootNode.addChildNode(keyLight)

        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .ambient
        fillLight.light?.intensity = 250
        fillLight.light?.color = UIColor(red: 0.7, green: 0.75, blue: 0.85, alpha: 1)
        scene.rootNode.addChildNode(fillLight)

        // Geometry
        let geometry: SCNGeometry
        if isWall {
            geometry = SCNBox(width: 2.0, height: 1.5, length: 0.08, chamferRadius: 0.01)
        } else {
            geometry = SCNPlane(width: 3.0, height: 3.0)
            (geometry as? SCNPlane)?.cornerRadius = 0
        }
        let meshNode = SCNNode(geometry: geometry)
        meshNode.name = "previewMesh"
        if !isWall {
            meshNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        }
        scene.rootNode.addChildNode(meshNode)

        // Apply initial material
        applyMaterial(to: meshNode, config: config)

        return scnView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        guard let meshNode = uiView.scene?.rootNode.childNode(withName: "previewMesh", recursively: true)
        else { return }
        applyMaterial(to: meshNode, config: config)
    }

    private func applyMaterial(to node: SCNNode, config: CinematicMaterialConfig) {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased

        // Generate texture image
        let textureImage = ProceduralTextureGenerator.shared.thumbnail(
            for: config.presetID,
            tint: UIColor(
                red: CGFloat(config.tintR),
                green: CGFloat(config.tintG),
                blue: CGFloat(config.tintB),
                alpha: CGFloat(config.tintA)
            )
        )
        material.diffuse.contents = textureImage
        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .repeat

        // Tiling
        let scale = max(0.1, config.tilingScale)
        material.diffuse.contentsTransform = SCNMatrix4MakeScale(Float(scale), Float(scale), 1)

        // PBR
        material.roughness.contents = CGFloat(config.roughness)
        material.metalness.contents = CGFloat(config.metallic)

        // Opacity / transparency
        if config.opacity < 0.95 || config.presetID == "glass" {
            material.transparency = CGFloat(config.opacity)
            material.isDoubleSided = true
            material.blendMode = .alpha
        }

        node.geometry?.materials = [material]
    }
}

// MARK: - MaterialPreviewCard

/// A styled container wrapping MaterialPreviewView with a label.
struct MaterialPreviewCard: View {
    let config: CinematicMaterialConfig
    let isWall: Bool
    let label: String

    var body: some View {
        VStack(spacing: 0) {
            MaterialPreviewView(config: config, isWall: isWall)
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color(white: 0.3), lineWidth: 0.5)
                )

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 6)
        }
    }
}
