import XCTest
@testable import WebPicCore

private actor Counter {
    private(set) var value = 0
    func increment() { value += 1 }
}

@MainActor
final class UpdateThrottleTests: XCTestCase {
    private func store() -> AppStore { AppStore(defaults: UserDefaults(suiteName: "wp.\(UUID().uuidString)")!) }
    private nonisolated func json(_ v: String) -> Data { "{\"tag_name\":\"\(v)\",\"html_url\":\"https://x/rel\",\"body\":\"- n\",\"assets\":[]}".data(using: .utf8)! }

    func testThrottleSkipsWithin24h() async {
        let s = store()
        let calls = Counter()
        let loader: @Sendable (URL) async -> Data? = { _ in await calls.increment(); return self.json("99.0") }
        await s.checkForUpdate(now: Date(timeIntervalSince1970: 1000), loader: loader)
        await s.checkForUpdate(now: Date(timeIntervalSince1970: 1000 + 3600), loader: loader)
        let count = await calls.value
        XCTAssertEqual(count, 1)
        XCTAssertNotNil(s.availableUpdate)
    }

    func testSkippedVersionNotShown() async {
        let s = store()
        let loader: @Sendable (URL) async -> Data? = { _ in self.json("99.0") }
        s.skipUpdate("99.0")
        await s.checkForUpdate(now: Date(timeIntervalSince1970: 5000), loader: loader)
        XCTAssertNil(s.availableUpdate)
        XCTAssertFalse(s.showUpdate)
    }

    func testDismissSkips() async {
        let s = store()
        let loader: @Sendable (URL) async -> Data? = { _ in self.json("99.0") }
        await s.checkForUpdate(now: Date(timeIntervalSince1970: 9000), loader: loader)
        XCTAssertTrue(s.showUpdate)
        s.dismissUpdate()
        XCTAssertFalse(s.showUpdate)
        await s.checkForUpdate(now: Date(timeIntervalSince1970: 9000 + 90_000), loader: loader)
        XCTAssertNil(s.availableUpdate)
    }
}
