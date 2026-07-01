import XCTest
@testable import WebPicCore

final class ExportServiceTests: XCTestCase {
    func testWritesFilesWithScheme() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("wp-exp-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let results = [
            EncodeResult(format: .webp, width: 1200, height: 600, byteSize: 3, data: Data([1,2,3]), quality: 80),
            EncodeResult(format: .jpeg, width: 1200, height: 600, byteSize: 2, data: Data([4,5]), quality: 80),
        ]
        let urls = try ExportService.write(results: results, to: dir,
                                           originalName: "hero.png", scheme: "{name}-{w}.{format}")
        XCTAssertEqual(urls.map(\.lastPathComponent), ["hero-1200.webp", "hero-1200.jpg"])
        XCTAssertEqual(try Data(contentsOf: urls[0]), Data([1,2,3]))
    }
}
