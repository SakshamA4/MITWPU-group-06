// MARK: - Mesh Generators Extension
import RealityKit

extension MeshResource {
    
    // 1. CONE GENERATOR (For the Arrow Tip)
    static func generateCone(height: Float, radius: Float) -> MeshResource {
        var descriptor = MeshDescriptor()
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        
        let segments = 36
        let pi = Float.pi
        
        // Tip
        positions.append([0, height, 0])
        normals.append([0, 1, 0])
        
        // Base Circle
        for i in 0...segments {
            let angle = (Float(i) / Float(segments)) * pi * 2
            let x = radius * cos(angle)
            let z = radius * sin(angle)
            positions.append([x, 0, z])
            
            // Sloped normals
            let slope = sqrt(height * height + radius * radius)
            let yNorm = radius / slope
            let hNorm = height / slope
            normals.append([hNorm * cos(angle), yNorm, hNorm * sin(angle)])
        }
        
        // Bottom Cap Center
        let centerIndex = UInt32(positions.count)
        positions.append([0, 0, 0])
        normals.append([0, -1, 0])
        
        // Bottom Cap Edge
        let baseStartIndex = UInt32(positions.count)
        for i in 0...segments {
            let angle = (Float(i) / Float(segments)) * pi * 2
            let x = radius * cos(angle)
            let z = radius * sin(angle)
            positions.append([x, 0, z])
            normals.append([0, -1, 0])
        }
        
        // Indices (Triangles)
        for i in 1...UInt32(segments) {
            indices.append(0)
            indices.append(i + 1)
            indices.append(i)
        }
        for i in 0..<UInt32(segments) {
            let current = baseStartIndex + i
            let next = baseStartIndex + i + 1
            indices.append(centerIndex)
            indices.append(current)
            indices.append(next)
        }
        
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)
        
        return try! MeshResource.generate(from: [descriptor])
    }

    // 2. TORUS GENERATOR (For the "Circle Line" Ring)
    static func generateTorus(majorRadius: Float, minorRadius: Float) -> MeshResource {
        var descriptor = MeshDescriptor()
        var positions: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        var normals: [SIMD3<Float>] = []
        
        let majorSegments = 64
        let minorSegments = 16
        let pi = Float.pi
        
        for i in 0...majorSegments {
            let majorAngle = (Float(i) / Float(majorSegments)) * pi * 2.0
            let cosMajor = cos(majorAngle)
            let sinMajor = sin(majorAngle)
            let center = SIMD3<Float>(cosMajor * majorRadius, 0, sinMajor * majorRadius)
            
            for j in 0...minorSegments {
                let minorAngle = (Float(j) / Float(minorSegments)) * pi * 2.0
                let cosMinor = cos(minorAngle)
                let sinMinor = sin(minorAngle)
                
                let x = (majorRadius + minorRadius * cosMinor) * cosMajor
                let z = (majorRadius + minorRadius * cosMinor) * sinMajor
                let y = minorRadius * sinMinor
                
                let pos = SIMD3<Float>(x, y, z)
                positions.append(pos)
                normals.append(simd_normalize(pos - center))
            }
        }
        
        for i in 0..<majorSegments {
            for j in 0..<minorSegments {
                let current = UInt32(i * (minorSegments + 1) + j)
                let next = current + UInt32(minorSegments + 1)
                
                indices.append(contentsOf: [current, next, current + 1])
                indices.append(contentsOf: [current + 1, next, next + 1])
            }
        }
        
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)
        
        return try! MeshResource.generate(from: [descriptor])
    }
}
