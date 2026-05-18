//
//  RotaionRingGizmo.swift
//  FilmsPage
//
//  Created by SDC-USER on 09/02/26.
//



import Foundation
import RealityKit
import UIKit




final class RotationRingGizmo: Entity {

    enum Axis {
        case x, y, z
    }

    weak var target: Entity?

    private var xRing: ModelEntity!
    private var yRing: ModelEntity!
    private var zRing: ModelEntity!

    init(target: Entity) {
    self.target = target
    super.init()


   
    let bounds = computeBounds(for: target)

    // Move gizmo to true object center
    self.position = bounds.center

    // Pass radius to ring generator
    setupRings(radius: bounds.radius)
 

    }


    required init() {
//        fatalError()
    }

    private func setupRings(radius: Float) {

   
    xRing = makeRing(color: .systemRed, axis: .x, radius: radius)
    yRing = makeRing(color: .systemGreen, axis: .y, radius: radius)
    zRing = makeRing(color: .systemBlue, axis: .z, radius: radius)

    addChild(xRing)
    addChild(yRing)
    addChild(zRing)
    

    }

    // ✅ THIS CALLS generateTorusMesh
    private func makeRing(
    color: UIColor,
    axis: Axis,
    radius: Float
    ) -> ModelEntity {
        let torus = generateTorusMesh(
            ringRadius: radius,
            pipeRadius: radius * 0.025,   // Thinner for a cleaner DCC look
            segments: 64,                  // Higher for smoother curves
            sides: 16
        )

        // UnlitMaterial ensures consistent visibility regardless of scene lighting
        let material = UnlitMaterial(color: color)

        let ring = ModelEntity(mesh: torus, materials: [material])

        switch axis {
        case .x:
            ring.orientation = simd_quatf(angle: .pi/2, axis: [0,1,0])
            ring.name = "xRing"
        case .y:
            ring.orientation = simd_quatf(angle: .pi/2, axis: [1,0,0])
            ring.name = "yRing"
        case .z:
            ring.orientation = simd_quatf(angle: 0, axis: [0, 0, 1])
            ring.name = "zRing"
        }

        ring.generateCollisionShapes(recursive: false)
        ring.components.set(InputTargetComponent())
        return ring
    }

    // ✅ THIS MUST BE INSIDE THE CLASS
    private func generateTorusMesh(
        ringRadius: Float,
        pipeRadius: Float,
        segments: Int,
        sides: Int
    ) -> MeshResource {

        var positions: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        for i in 0..<segments {
            let theta = Float(i) / Float(segments) * 2 * .pi

            for j in 0..<sides {
                let phi = Float(j) / Float(sides) * 2 * .pi

                let x = (ringRadius + pipeRadius * cos(phi)) * cos(theta)
                let y = (ringRadius + pipeRadius * cos(phi)) * sin(theta)
                let z = pipeRadius * sin(phi)

                positions.append([x, y, z])
            }
        }

        for i in 0..<segments {
            for j in 0..<sides {
                let a = UInt32(i * sides + j)
                let b = UInt32(((i + 1) % segments) * sides + j)
                let c = UInt32(((i + 1) % segments) * sides + (j + 1) % sides)
                let d = UInt32(i * sides + (j + 1) % sides)

                indices += [a, b, d, b, c, d]
            }
        }

        var descriptor = MeshDescriptor()
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.primitives = .triangles(indices)

        return try! MeshResource.generate(from: [descriptor])
    }
    
    private func computeBounds(for entity: Entity) -> (center: SIMD3<Float>, radius: Float) {

    
    let bounds = entity.visualBounds(relativeTo: entity)

    let center = bounds.center
    let extents = bounds.extents

    // Use largest dimension as ring size base
    let maxDimension = max(extents.x, extents.y, extents.z)

    // Add padding so rings don’t clip object
    let radius = maxDimension * 0.75

    return (center, radius)
  

    }

}
