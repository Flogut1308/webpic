import XCTest
@testable import WebPicCore

final class FilenameFormatterTests: XCTestCase {
    func testExpand() {
        XCTAssertEqual(
            FilenameFormatter.expand("{name}-{w}.{format}", name: "hero-banner", width: 1200, format: .webp),
            "hero-banner-1200.webp")
    }
    func testStripsSourceExtension() {
        XCTAssertEqual(
            FilenameFormatter.expand("{name}.{format}", name: "photo.jpeg", width: 800, format: .avif),
            "photo.avif")
    }
    func testExtensions() {
        XCTAssertEqual(FilenameFormatter.fileExtension(.jpeg), "jpg")
        XCTAssertEqual(FilenameFormatter.fileExtension(.png), "png")
        XCTAssertEqual(FilenameFormatter.fileExtension(.avif), "avif")
        XCTAssertEqual(FilenameFormatter.fileExtension(.webp), "webp")
    }
}
