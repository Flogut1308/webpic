import XCTest
@testable import WebPicCore

final class AppStoreTests: XCTestCase {
    func testAddSeedsAndSelects() {
        let s = AppStore(defaults: Self.tmpDefaults())
        s.addImages()
        XCTAssertEqual(s.images.count, 4)
        XCTAssertEqual(s.selectedID, s.images.first?.id)
        XCTAssertEqual(s.tab, .settings)
    }

    func testSelectFromBatchGoesToSettings() {
        let s = AppStore(defaults: Self.tmpDefaults())
        s.addImages()
        s.tab = .batch
        s.select(id: s.images[2].id)
        XCTAssertEqual(s.selectedID, s.images[2].id)
        XCTAssertEqual(s.tab, .settings)
    }

    func testRemoveReselects() {
        let s = AppStore(defaults: Self.tmpDefaults())
        s.addImages()
        let firstID = s.images[0].id
        s.remove(id: firstID)
        XCTAssertEqual(s.images.count, 3)
        XCTAssertEqual(s.selectedID, s.images.first?.id)
        XCTAssertNotEqual(s.selectedID, firstID)
    }

    func testFormatBytes() {
        XCTAssertEqual(formatBytes(6_083_000), "6,1 MB")
        XCTAssertEqual(formatBytes(430_000), "420 KB")
        XCTAssertEqual(formatBytes(512), "512 B")
    }

    private static func tmpDefaults() -> UserDefaults {
        UserDefaults(suiteName: "wp.tests.\(UUID().uuidString)")!
    }
}
