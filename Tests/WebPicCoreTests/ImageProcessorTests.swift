import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import WebPicCore

final class ImageProcessorTests: XCTestCase {
    private func pngData(_ w: Int, _ h: Int) throws -> Data {
        let img = ImageIOEncoderTests.noisyImage(w, h)
        let out = NSMutableData()
        let d = CGImageDestinationCreateWithData(out as CFMutableData, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(d, img, nil); _ = CGImageDestinationFinalize(d)
        return out as Data
    }

    func testProcessResizesAndEncodes() throws {
        let source = try pngData(2000, 1000)
        var s = Settings.default
        s.preset = .content            // 1200
        s.formats = [.webp, .jpeg]
        s.compressionMode = .quality
        s.quality = 80
        let cg = ImageProcessor().loadCGImage(data: source)!
        let results = try ImageProcessor().process(source: cg, settings: s)
        XCTAssertEqual(results.count, 2)
        for r in results {
            XCTAssertEqual(r.width, 1200)
            XCTAssertEqual(r.height, 600)
            XCTAssertLessThan(r.byteSize, source.count)
        }
        XCTAssertEqual(results.map(\.format), [.webp, .jpeg])
    }
}
