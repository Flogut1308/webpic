import XCTest
import CoreGraphics
@testable import WebPicCore

final class TargetSizeSolverTests: XCTestCase {
    func testConvergesUnderTarget() throws {
        let img = ImageIOEncoderTests.noisyImage(800, 600)
        let target = 25_000
        let r = try TargetSizeSolver.solve(image: img, encoder: ImageIOEncoder(format: .jpeg),
                                           targetBytes: target, maxIterations: 8)
        XCTAssertLessThanOrEqual(r.data.count, target)
        XCTAssertGreaterThanOrEqual(r.quality, 5)
        XCTAssertLessThanOrEqual(r.quality, 100)
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
}
