import XCTest
@testable import WebPicCore

final class UpdateCheckerTests: XCTestCase {
    private func json(_ version: String) -> Data {
        """
        {"tag_name":"\(version)","html_url":"https://x/rel","body":"- new","assets":[]}
        """.data(using: .utf8)!
    }

    func testReturnsNewer() async {
        let info = await UpdateChecker.fetchLatest(owner: "o", repo: "r", currentVersion: "2.0",
                                                   loader: { _ in self.json("2.1") })
        XCTAssertEqual(info?.version, "2.1")
    }

    func testNilWhenNotNewer() async {
        let info = await UpdateChecker.fetchLatest(owner: "o", repo: "r", currentVersion: "2.0",
                                                   loader: { _ in self.json("2.0") })
        XCTAssertNil(info)
    }

    func testNilOnLoaderFailure() async {
        let info = await UpdateChecker.fetchLatest(owner: "o", repo: "r", currentVersion: "2.0",
                                                   loader: { _ in nil })
        XCTAssertNil(info)
    }
}
