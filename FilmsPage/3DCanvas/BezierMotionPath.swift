import RealityKit
import simd

struct BezierMotionPath: Codable {

    var start: SIMD3<Float>
    var control1: SIMD3<Float>
    var control2: SIMD3<Float>
    var end: SIMD3<Float>

    private(set) var arcLengths: [Float] = []
    private(set) var totalLength: Float = 0

    init(
        start: SIMD3<Float>,
        control1: SIMD3<Float>,
        control2: SIMD3<Float>,
        end: SIMD3<Float>
    ) {
        self.start = start
        self.control1 = control1
        self.control2 = control2
        self.end = end
        rebuildArcLengthTable()
    }

    // ─────────────────────────────
    // RAW BEZIER
    // ─────────────────────────────
    func evaluate(t: Float) -> SIMD3<Float> {

        let u = 1 - t
        let tt = t * t
        let uu = u * u
        let uuu = uu * u
        let ttt = tt * t

        return
            uuu * start +
            3 * uu * t * control1 +
            3 * u * tt * control2 +
            ttt * end
    }



    // ─────────────────────────────
    // ARC LENGTH TABLE
    // ─────────────────────────────
    mutating func rebuildArcLengthTable(steps: Int = 120) {

        arcLengths.removeAll(keepingCapacity: true)

        var previous = evaluate(t: 0)
        var length: Float = 0

        arcLengths.append(0)

        for i in 1...steps {
            let t = Float(i) / Float(steps)
            let current = evaluate(t: t)
            length += simd_distance(previous, current)
            arcLengths.append(length)
            previous = current
        }

        totalLength = length
    }

    // ─────────────────────────────
    // CONSTANT SPEED
    // ─────────────────────────────
    func evaluateConstantSpeed(_ t: Float) -> SIMD3<Float> {

        guard totalLength > 0 else {
            return evaluate(t: t)
        }

        let target = t * totalLength

        var low = 0
        var high = arcLengths.count - 1

        while low < high {
            let mid = (low + high) / 2
            if arcLengths[mid] < target {
                low = mid + 1
            } else {
                high = mid
            }
        }

        let prev = max(low - 1, 0)

        let d0 = arcLengths[prev]
        let d1 = arcLengths[low]

        let segment = d1 - d0
        let localT = segment == 0 ? 0 : (target - d0) / segment

        let steps = Float(arcLengths.count - 1)

        let t0 = Float(prev) / steps
        let t1 = Float(low) / steps

        return evaluate(
            t: simd_mix(t0, t1, localT)
        )
    }
}

// MARK: - Curve Sampling

extension BezierMotionPath {

    func sample(segments: Int) -> [SIMD3<Float>] {
        guard segments > 1 else { return [start, end] }

        return (0...segments).map {
            evaluate(t: Float($0) / Float(segments))
        }
    }
}
