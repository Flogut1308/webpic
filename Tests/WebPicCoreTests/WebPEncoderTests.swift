import XCTest
import CoreGraphics
import ImageIO
@testable import WebPicCore

final class WebPEncoderTests: XCTestCase {
    func testWebPHeaderAndDecode() throws {
        let img = ImageIOEncoderTests.noisyImage(320, 200)
        let data = try WebPEncoder().encode(img, quality: 0.75)
        XCTAssertGreaterThan(data.count, 12)
        let bytes = [UInt8](data.prefix(12))
        XCTAssertEqual(Array(bytes[0..<4]), Array("RIFF".utf8))
        XCTAssertEqual(Array(bytes[8..<12]), Array("WEBP".utf8))
        let src = CGImageSourceCreateWithData(data as CFData, nil)!
        let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as! [CFString: Any]
        XCTAssertEqual(props[kCGImagePropertyPixelWidth] as? Int, 320)
        XCTAssertEqual(props[kCGImagePropertyPixelHeight] as? Int, 200)
    }

    func testWebPQualityAffectsSize() throws {
        let img = ImageIOEncoderTests.noisyImage(400, 300)
        let lo = try WebPEncoder().encode(img, quality: 0.2)
        let hi = try WebPEncoder().encode(img, quality: 0.9)
        XCTAssertLessThan(lo.count, hi.count)
    }
}
