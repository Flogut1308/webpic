import CoreGraphics
import Foundation

public enum TargetSizeSolver {
    public struct Solution: Sendable { public let quality: Int; public let data: Data }

    /// Binary search quality (5...100) so encoded size ≤ targetBytes; if infeasible, returns the smallest (min-quality) result.
    public static func solve(image: CGImage, encoder: ImageEncoder,
                             targetBytes: Int, maxIterations: Int = 8) throws -> Solution {
        var lo = 5, hi = 100
        var best: Solution? = nil          // highest quality that fits under target
        var smallest: Solution? = nil      // fallback: smallest overall
        var iterations = 0
        while lo <= hi && iterations < maxIterations {
            iterations += 1
            let mid = (lo + hi) / 2
            let data = try encoder.encode(image, quality: Double(mid) / 100.0)
            if smallest == nil || data.count < smallest!.data.count {
                smallest = Solution(quality: mid, data: data)
            }
            if data.count <= targetBytes {
                best = Solution(quality: mid, data: data)
                lo = mid + 1
            } else {
                hi = mid - 1
            }
        }
        if let best { return best }
        if let smallest { return smallest }
        return Solution(quality: 5, data: try encoder.encode(image, quality: 0.05))
    }
}
