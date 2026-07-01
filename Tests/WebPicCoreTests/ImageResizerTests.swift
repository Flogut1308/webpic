import XCTest
import CoreGraphics
@testable import WebPicCore

final class ImageResizerTests: XCTestCase {
    func testDownscalePreservesAspect() {
        let img = ImageIOEncoderTests.noisyImage(400, 200)
        let out = ImageResizer.resize(img, toWidth: 200)
        XCTAssertEqual(out.width, 200)
        XCTAssertEqual(out.height, 100)
    }
    func testNoUpscale() {
        let img = ImageIOEncoderTests.noisyImage(300, 300)
        let out = ImageResizer.resize(img, toWidth: 600)
        XCTAssertEqual(out.width, 300)
        XCTAssertEqual(out.height, 300)
    }
    func testColorSpaceConversion() {
        let img = ImageIOEncoderTests.noisyImage(50, 50)
        let p3 = ImageResizer.convert(img, to: .displayP3)
        XCTAssertTrue((p3.colorSpace?.name as String? ?? "").contains("P3"))
        let srgb = ImageResizer.convert(img, to: .sRGB)
        XCTAssertTrue((srgb.colorSpace?.name as String? ?? "").localizedCaseInsensitiveContains("srgb"))
    }
}
