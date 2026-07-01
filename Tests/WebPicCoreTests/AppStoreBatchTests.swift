import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import WebPicCore

@MainActor
final class AppStoreBatchTests: XCTestCase {
    private func fixtureURL(_ w: Int, _ h: Int) throws -> URL {
        let img = ImageIOEncoderTests.noisyImage(w, h)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("wp-\(UUID().uuidString).png")
        let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(d, img, nil); _ = CGImageDestinationFinalize(d)
        return url
    }

    func testProcessAllCompletesEveryImage() async throws {
        let store = AppStore(defaults: UserDefaults(suiteName: "wp.\(UUID().uuidString)")!)
        let urls = try (0..<3).map { _ in try fixtureURL(800, 500) }
        await store.importFiles(urls)
        store.settings.formats = [.webp, .jpeg]
        store.settings.compressionMode = .quality
        await store.processAll()
        XCTAssertEqual(store.images.count, 3)
        for img in store.images {
            XCTAssertEqual(img.status, .done)
            XCTAssertFalse(img.results.isEmpty)
        }
    }

    func testProcessAllMarksBadImageError() async throws {
        let store = AppStore(defaults: UserDefaults(suiteName: "wp.\(UUID().uuidString)")!)
        let bad = FileManager.default.temporaryDirectory.appendingPathComponent("wp-\(UUID().uuidString).png")
        try "not an image".data(using: .utf8)!.write(to: bad)
        store.images = [WebPicImage(id: "x", name: "bad.png", pixelWidth: 10, pixelHeight: 10,
                                    byteSize: 5, status: .waiting, url: bad)]
        await store.processAll()
        if case .error = store.images[0].status {} else { XCTFail("expected .error, got \(store.images[0].status)") }
    }

    func testConcurrencyCap() {
        XCTAssertLessThanOrEqual(AppStore.batchConcurrency, 4)
        XCTAssertGreaterThanOrEqual(AppStore.batchConcurrency, 1)
    }

    func testSameForAllDefault() {
        let store = AppStore(defaults: UserDefaults(suiteName: "wp.\(UUID().uuidString)")!)
        XCTAssertTrue(store.sameForAll)
    }
}
