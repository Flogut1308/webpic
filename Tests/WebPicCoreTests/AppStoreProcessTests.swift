import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import WebPicCore

@MainActor
final class AppStoreProcessTests: XCTestCase {
    private func fixtureURL(_ w: Int, _ h: Int) throws -> URL {
        let img = ImageIOEncoderTests.noisyImage(w, h)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("wp-\(UUID().uuidString).png")
        let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(d, img, nil); _ = CGImageDestinationFinalize(d)
        return url
    }

    func testProcessSelectedPopulatesResults() async throws {
        let store = AppStore(defaults: UserDefaults(suiteName: "wp.\(UUID().uuidString)")!)
        let url = try fixtureURL(1600, 1000)
        await store.importFiles([url])
        store.settings.formats = [.webp, .jpeg]
        store.settings.compressionMode = .quality
        await store.processSelected()
        XCTAssertFalse(store.processing)
        XCTAssertEqual(store.results.count, 2)
        XCTAssertNotNil(store.primaryResult)
    }
}
