import Foundation
import UIKit
import RealityKit

final class MotionPathHandles {

    enum HandleType {
        case start
        case control1
        case control2
        case end
    }

    struct Handle {
        let type: HandleType
        let entity: ModelEntity
    }

    static func createHandles(
        path: BezierMotionPath,
        clipID: UUID,
        showStartHandle: Bool
    ) -> [Handle] {

        var handles: [Handle] = []

        func makeHandle(
            position: SIMD3<Float>,
            color: UIColor,
            type: HandleType
        ) -> Handle {

            let mesh = MeshResource.generateSphere(radius: 0.035)

            let material = SimpleMaterial(
                color: color,
                roughness: 0.2,
                isMetallic: true
            )

            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.position = position
            entity.name = "path.\(type)"

            entity.generateCollisionShapes(recursive: true)
            entity.components.set(InputTargetComponent())
            entity.components.set(
                CanvasViewController.MotionPathHandleComponent(clipID: clipID)
            )

            return Handle(type: type, entity: entity)
        }

        // ✅ START HANDLE — CONDITIONAL
        if showStartHandle {
            handles.append(
                makeHandle(
                    position: path.start,
                    color: .systemGray,
                    type: .start
                )
            )
        }

        handles.append(
            makeHandle(
                position: path.control1,
                color: .systemBlue,
                type: .control1
            )
        )

        handles.append(
            makeHandle(
                position: path.control2,
                color: .systemPurple,
                type: .control2
            )
        )

        handles.append(
            makeHandle(
                position: path.end,
                color: .systemGreen,
                type: .end
            )
        )

        return handles
    }
}
