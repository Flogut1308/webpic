import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import WebPicCore

final class ImageIOEncoderTests: XCTestCase {
    /// A noisy RGB image so lossy quality actually changes size. Reused by other M4 test files.
    static func noisyImage(_ w: Int, _ h: Int) -> CGImage {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        var seed: UInt64 = 0x9E3779B97F4A7C15
        func rnd() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1; return CGFloat((seed >> 33) & 0xff) / 255 }
        for y in stride(from: 0, to: h, by: 4) {
            for x in stride(from: 0, to: w, by: 4) {
                ctx.setFillColor(red: rnd(), green: rnd(), blue: rnd(), alpha: 1)
                ctx.fill(CGRect(x: x, y: y, width: 4, height: 4))
            }
        }
        return ctx.makeImage()!
    }

    /// In the real pipeline `process()` hands the SAME metadata dict to every encoder, so the
    /// WebP-private XMP key rides along to ImageIO too. It must not corrupt the JPEG output.
    func testPrivateXMPKeyInMetadataIsHarmless() throws {
        let img = Self.noisyImage(48, 32)
        let meta: [CFString: Any] = [WebPEncoder.xmpDataKey: Data("<x:xmpmeta/>".utf8)]
        let data = try ImageIOEncoder(format: .jpeg).encode(img, quality: 0.8, metadata: meta)
        XCTAssertEqual(decodeDims(data)?.0, 48)
        XCTAssertEqual(decodeDims(data)?.1, 32)
    }

    private func decodeDims(_ data: Data) -> (Int, Int)? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return (w, h)
    }

    func testEncodesEachFormat() throws {
        let img = Self.noisyImage(320, 200)
        for fmt in [ImageFormat.jpeg, .png, .avif] {
            let data = try ImageIOEncoder(format: fmt).encode(img, quality: 0.7)
            XCTAssertFalse(data.isEmpty, "\(fmt) empty")
            let dims = decodeDims(data)
            XCTAssertNotNil(dims, "\(fmt) not decodable")
            XCTAssertEqual(dims?.0, 320); XCTAssertEqual(dims?.1, 200)
        }
    }

    func testJpegQualityAffectsSize() throws {
        let img = Self.noisyImage(400, 300)
        let lo = try ImageIOEncoder(format: .jpeg).encode(img, quality: 0.3)
        let hi = try ImageIOEncoder(format: .jpeg).encode(img, quality: 0.9)
        XCTAssertLessThan(lo.count, hi.count)
    }
}
