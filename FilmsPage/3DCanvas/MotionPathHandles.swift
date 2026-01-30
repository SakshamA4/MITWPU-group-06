//
//  MotionPathHandles.swift
//  3DCanvas
//
//  Created by SDC-USER on 21/01/26.
//

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
        onChange: @escaping (BezierMotionPath) -> Void
    ) -> [Handle] {

        var handles: [Handle] = []

        func makeHandle(
            position: SIMD3<Float>,
            color: UIColor,
            type: HandleType
        ) -> Handle {

            let mesh = MeshResource.generateSphere(radius: 0.035)

            var material = SimpleMaterial()
            material.color = .init(tint: color, texture: nil)

            let entity = ModelEntity(mesh: mesh, materials: [material])
            entity.position = position
            entity.name = "PathHandle_\(type)"

            entity.generateCollisionShapes(recursive: true)
            entity.components.set(InputTargetComponent())

            return Handle(type: type, entity: entity)
        }

        handles.append(makeHandle(
            position: path.start,
            color: .systemGray,
            type: .start
        ))

        handles.append(makeHandle(
            position: path.control1,
            color: .systemBlue,
            type: .control1
        ))

        handles.append(makeHandle(
            position: path.control2,
            color: .systemPurple,
            type: .control2
        ))

        handles.append(makeHandle(
            position: path.end,
            color: .systemGreen,
            type: .end
        ))

        return handles
    }
}
