import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import WebPicCore

final class ImageImportServiceTests: XCTestCase {

    /// Write a solid-color PNG of the given size to a temp file, return its URL.
    private func makePNG(width: Int, height: Int) throws -> URL {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                            bytesPerRow: 0, space: cs,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let img = ctx.makeImage()!
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("wp-\(UUID().uuidString).png")
        let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, img, nil)
        XCTAssertTrue(CGImageDestinationFinalize(dest))
        return url
    }

    func testLoadURL() throws {
        let url = try makePNG(width: 400, height: 200)
        let imp = try ImageImportService.load(url: url, thumbnailMaxPixel: 160)
        XCTAssertEqual(imp.pixelWidth, 400)
        XCTAssertEqual(imp.pixelHeight, 200)
        XCTAssertGreaterThan(imp.byteSize, 0)
        XCTAssertNotNil(imp.thumbnailPNG)
        let src = CGImageSourceCreateWithData(imp.thumbnailPNG! as CFData, nil)!
        let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as! [CFString: Any]
        let tw = props[kCGImagePropertyPixelWidth] as! Int
        let th = props[kCGImagePropertyPixelHeight] as! Int
        XCTAssertLessThanOrEqual(max(tw, th), 160)
    }

    func testLoadData() throws {
        let url = try makePNG(width: 300, height: 300)
        let data = try Data(contentsOf: url)
        let imp = try ImageImportService.load(data: data, name: "sq.png", thumbnailMaxPixel: 160)
        XCTAssertEqual(imp.pixelWidth, 300)
        XCTAssertEqual(imp.pixelHeight, 300)
        XCTAssertEqual(imp.name, "sq.png")
    }

    func testNonImageThrows() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("wp-\(UUID().uuidString).txt")
        try? "not an image".data(using: .utf8)!.write(to: url)
        XCTAssertThrowsError(try ImageImportService.load(url: url))
    }
}
