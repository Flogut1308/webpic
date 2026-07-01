import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import WebPicCore

final class ImageProcessorTests: XCTestCase {
    /// A smooth gradient with mild detail — photograph-like content where lossy
    /// encoding genuinely beats a full-resolution PNG. (Pure random noise is
    /// pathological: PNG run-length-compresses it while lossy cannot.)
    private func gradientImage(_ w: Int, _ h: Int) -> CGImage {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        for x in 0..<w {
            let t = CGFloat(x) / CGFloat(max(1, w - 1))
            ctx.setFillColor(red: t, green: 0.35 + 0.3 * t, blue: 1 - t, alpha: 1)
            ctx.fill(CGRect(x: x, y: 0, width: 1, height: h))
        }
        return ctx.makeImage()!
    }

    private func pngData(_ w: Int, _ h: Int) throws -> Data {
        let img = gradientImage(w, h)
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
