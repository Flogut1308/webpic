import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import WebPicCore

@MainActor
final class AppStoreImportTests: XCTestCase {
    private func makePNG(_ w: Int, _ h: Int) throws -> URL {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("wp-\(UUID().uuidString).png")
        let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(d, ctx.makeImage()!, nil)
        _ = CGImageDestinationFinalize(d)
        return url
    }
    private func store() -> AppStore { AppStore(defaults: UserDefaults(suiteName: "wp.\(UUID().uuidString)")!) }

    func testImportAppendsAndSelects() async throws {
        let s = store()
        let u1 = try makePNG(400, 200)
        await s.importFiles([u1])
        XCTAssertEqual(s.images.count, 1)
        XCTAssertEqual(s.images[0].status, .waiting)
        XCTAssertNotNil(s.images[0].thumbnailData)
        XCTAssertEqual(s.selectedID, s.images.first?.id)
    }

    func testImportDedupesByURL() async throws {
        let s = store()
        let u1 = try makePNG(400, 200)
        await s.importFiles([u1])
        await s.importFiles([u1])
        XCTAssertEqual(s.images.count, 1)
    }

    func testSeedMockStillWorks() {
        let s = store()
        s.seedMockImages()
        XCTAssertEqual(s.images.count, 4)
    }
}
