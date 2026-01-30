import UIKit
import RealityKit
import simd

final class BezierPathVisual {

    private var segments: [ModelEntity] = []
    private weak var parent: Entity?

    init(parent: Entity) {
        self.parent = parent
    }

    func update(path: BezierMotionPath) {

        // Remove old segments
        segments.forEach { $0.removeFromParent() }
        segments.removeAll()

        guard let parent else { return }

        let resolution = 32

        // ✅ convert world → local
        var previousPoint = path.evaluate(t: 0) - path.start

        for i in 1...resolution {

            let t = Float(i) / Float(resolution)

            // ✅ convert world → local
            let currentPoint = path.evaluate(t: t) - path.start

            let segment = makeSegment(
                from: previousPoint,
                to: currentPoint
            )

            parent.addChild(segment)
            segments.append(segment)

            previousPoint = currentPoint
        }
    }

    private func makeSegment(
        from: SIMD3<Float>,
        to: SIMD3<Float>
    ) -> ModelEntity {

        let direction = to - from
        let length = simd_length(direction)

        let mesh = MeshResource.generateCylinder(
            height: length,
            radius: 0.01
        )

        let material = SimpleMaterial(
            color: .systemGreen,
            isMetallic: false
        )

        let entity = ModelEntity(
            mesh: mesh,
            materials: [material]
        )

        entity.position = (from + to) * 0.5
        entity.look(
            at: to,
            from: entity.position,
            relativeTo: nil
        )

        return entity
    }

    func remove() {
        segments.forEach { $0.removeFromParent() }
        segments.removeAll()
    }
}
