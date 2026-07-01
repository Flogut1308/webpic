import XCTest
import CoreGraphics
import ImageIO
@testable import WebPicCore

final class MetadataTests: XCTestCase {
    func testJPEGMetadataRoundTrips() throws {
        let img = ImageIOEncoderTests.noisyImage(64, 64)
        let meta: [CFString: Any] = [kCGImagePropertyExifDictionary: [kCGImagePropertyExifUserComment: "webpic"]]
        let data = try ImageIOEncoder(format: .jpeg).encode(img, quality: 0.8, metadata: meta)
        let src = CGImageSourceCreateWithData(data as CFData, nil)!
        let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as! [CFString: Any]
        let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
        XCTAssertEqual(exif?[kCGImagePropertyExifUserComment] as? String, "webpic")
    }

    func testNoMetadataWhenNil() throws {
        // ImageIO's JPEG encoder always writes a minimal Exif dict (pixel dimensions) regardless
        // of the properties passed in — that's pre-existing CGImageDestination behavior, not
        // something we inject. Assert our specific key is absent rather than the whole dict.
        let img = ImageIOEncoderTests.noisyImage(64, 64)
        let data = try ImageIOEncoder(format: .jpeg).encode(img, quality: 0.8, metadata: nil)
        let src = CGImageSourceCreateWithData(data as CFData, nil)!
        let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as! [CFString: Any]
        let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
        XCTAssertNil(exif?[kCGImagePropertyExifUserComment])
    }
}
