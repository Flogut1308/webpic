import XCTest
@testable import WebPicCore

final class SmokeTests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(WebPicCore.version, "2.6")
    }
}
