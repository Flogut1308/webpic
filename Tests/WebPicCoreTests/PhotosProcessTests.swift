import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import WebPicCore

@MainActor
final class PhotosProcessTests: XCTestCase {
    private func pngData(_ w: Int, _ h: Int) -> Data {
        let img = ImageIOEncoderTests.noisyImage(w, h)
        let out = NSMutableData()
        let d = CGImageDestinationCreateWithData(out as CFMutableData, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(d, img, nil); _ = CGImageDestinationFinalize(d)
        return out as Data
    }

    func testDataImportProcesses() async throws {
        let store = AppStore(defaults: UserDefaults(suiteName: "wp.\(UUID().uuidString)")!)
        await store.importData([(data: pngData(1200, 800), name: "photo-1.jpg")])
        XCTAssertEqual(store.images.count, 1)
        XCTAssertNil(store.images[0].url)
        XCTAssertNotNil(store.images[0].sourceData)
        store.settings.formats = [.webp, .jpeg]
        await store.processSelected()
        XCTAssertEqual(store.results.count, 2)
    }
}
