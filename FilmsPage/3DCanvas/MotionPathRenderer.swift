import RealityKit
import UIKit

enum MotionPathRenderer {

    static func makePathEntity(path: BezierMotionPath) -> ModelEntity {

        let entity = ModelEntity()
        entity.name = "MotionPath"

        var material = UnlitMaterial()
        material.color = .init(tint: .systemBlue, texture: nil)

        entity.model = ModelComponent(
            mesh: buildTubeMesh(path: path),
            materials: [material]
        )

        return entity
    }

    static func updatePathMesh(
        entity: ModelEntity,
        path: BezierMotionPath
    ) {
        guard var model = entity.model else { return }
        model.mesh = buildTubeMesh(path: path)
        entity.model = model
    }

    private static func buildTubeMesh(
        path: BezierMotionPath
    ) -> MeshResource {

        let points = path.sample(segments: 80)

        let radius: Float = 0.01
        let sides = 10

        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        var vertexIndex: UInt32 = 0

        for i in 0..<points.count {

            // 🔑 LOCAL SPACE
            let center = points[i] - path.start

            let forward: SIMD3<Float>
            if i < points.count - 1 {
                forward = simd_normalize(
                    (points[i + 1] - path.start) -
                    (points[i] - path.start)
                )
            } else {
                forward = simd_normalize(
                    (points[i] - path.start) -
                    (points[i - 1] - path.start)
                )
            }

            var up = SIMD3<Float>(0, 1, 0)
            if abs(simd_dot(up, forward)) > 0.9 {
                up = SIMD3<Float>(1, 0, 0)
            }

            let right = simd_normalize(simd_cross(forward, up))
            up = simd_normalize(simd_cross(right, forward))

            for j in 0..<sides {

                let angle = Float(j) / Float(sides) * (.pi * 2)

                let offset =
                    cos(angle) * right * radius +
                    sin(angle) * up * radius

                positions.append(center + offset)
                normals.append(simd_normalize(offset))
            }

            if i > 0 {
                let base = vertexIndex
                let prev = base - UInt32(sides)

                for j in 0..<sides {
                    let next = (j + 1) % sides

                    indices.append(contentsOf: [
                        prev + UInt32(j),
                        prev + UInt32(next),
                        base + UInt32(j),
                        base + UInt32(j),
                        prev + UInt32(next),
                        base + UInt32(next)
                    ])
                }
            }

            vertexIndex += UInt32(sides)
        }

        var desc = MeshDescriptor()
        desc.positions = MeshBuffers.Positions(positions)
        desc.normals = MeshBuffers.Normals(normals)
        desc.primitives = .triangles(indices)

        guard let mesh = try? MeshResource.generate(from: [desc]) else {
            return MeshResource.generateBox(size: 0.01) // fallback
        }
        return mesh
    }
    static func setPathColor(
        entity: ModelEntity,
        color: UIColor
    ) {
        guard var material = entity.model?.materials.first as? UnlitMaterial else {
            return
        }

        material.color = .init(tint: color, texture: nil)
        entity.model?.materials = [material]
    }

}
