import XCTest
@testable import WebPicCore

final class WebPicImageTests: XCTestCase {
    func testThumbnailDefaultsNil() {
        let img = WebPicImage(id: "x", name: "a.png", pixelWidth: 10, pixelHeight: 10,
                              byteSize: 100, status: .waiting)
        XCTAssertNil(img.thumbnailData)
    }
    func testThumbnailStored() {
        let d = Data([1, 2, 3])
        let img = WebPicImage(id: "x", name: "a.png", pixelWidth: 10, pixelHeight: 10,
                              byteSize: 100, status: .waiting, thumbnailData: d)
        XCTAssertEqual(img.thumbnailData, d)
    }
}
