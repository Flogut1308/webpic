import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import WebPicCore

final class OrientationTests: XCTestCase {
    private func jpeg(orientation: UInt32) throws -> Data {
        let img = ImageIOEncoderTests.noisyImage(400, 200)
        let out = NSMutableData()
        let d = CGImageDestinationCreateWithData(out as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(d, img, [kCGImagePropertyOrientation: orientation] as CFDictionary)
        _ = CGImageDestinationFinalize(d)
        return out as Data
    }

    func testOrientation6SwapsDimensions() throws {
        let data = try jpeg(orientation: 6)
        let cg = ImageProcessor().loadCGImage(data: data)!
        XCTAssertEqual(cg.width, 200)
        XCTAssertEqual(cg.height, 400)
    }

    func testOrientation1Unchanged() throws {
        let data = try jpeg(orientation: 1)
        let cg = ImageProcessor().loadCGImage(data: data)!
        XCTAssertEqual(cg.width, 400)
        XCTAssertEqual(cg.height, 200)
    }
}
