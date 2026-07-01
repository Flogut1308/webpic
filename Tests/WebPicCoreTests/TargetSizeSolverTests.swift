import XCTest
import CoreGraphics
@testable import WebPicCore

final class TargetSizeSolverTests: XCTestCase {
    func testConvergesUnderFeasibleTarget() throws {
        // Noisy 800×600 JPEG spans ~77 KB (q5) … several hundred KB (q100).
        // Pick a target inside that range so the search must actually converge.
        let img = ImageIOEncoderTests.noisyImage(800, 600)
        let target = 120_000
        let r = try TargetSizeSolver.solve(image: img, encoder: ImageIOEncoder(format: .jpeg),
                                           targetBytes: target, maxIterations: 8)
        XCTAssertLessThanOrEqual(r.data.count, target)
        XCTAssertGreaterThanOrEqual(r.quality, 5)
        XCTAssertLessThanOrEqual(r.quality, 100)
    }

    func testInfeasibleTargetReturnsSmallest() throws {
        // A 1 KB target is unreachable → solver returns the smallest (min-quality) result.
        let img = ImageIOEncoderTests.noisyImage(800, 600)
        let r = try TargetSizeSolver.solve(image: img, encoder: ImageIOEncoder(format: .jpeg),
                                           targetBytes: 1_000, maxIterations: 8)
        XCTAssertEqual(r.quality, 5)
        XCTAssertGreaterThan(r.data.count, 1_000)   // documented: can't actually reach the target
    }

    func testProcessForTargetUsesSolvedQuality() throws {
        let img = ImageIOEncoderTests.noisyImage(1600, 1000)
        var s = Settings.default
        s.preset = .content
        s.formats = [.jpeg, .webp]
        s.compressionMode = .target
        s.targetValue = "40"; s.targetUnit = .kb
        let out = try ImageProcessor().processForTarget(source: img, settings: s)
        XCTAssertEqual(Set(out.results.map(\.format)), [.jpeg, .webp])
        XCTAssertGreaterThanOrEqual(out.chosenQuality, 5)
        XCTAssertLessThanOrEqual(out.chosenQuality, 100)
    }

    func testProcessForTargetHandlesNonNumericTarget() throws {
        // A cleared/invalid target field → targetBytes is NaN. Must not crash (Int(NaN) traps).
        let img = ImageIOEncoderTests.noisyImage(400, 300)
        var s = Settings.default
        s.compressionMode = .target
        s.targetValue = ""            // NaN
        s.formats = [.jpeg]
        let out = try ImageProcessor().processForTarget(source: img, settings: s)
        XCTAssertEqual(out.results.count, 1)
    }
}
