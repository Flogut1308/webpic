import XCTest
import SwiftUI
@testable import WebPicCore

final class ThemeManagerTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "wp.tests.\(UUID().uuidString)")!
    }

    func testDefaultIsSystem() {
        let tm = ThemeManager(defaults: makeDefaults())
        XCTAssertEqual(tm.appearance, .system)
        XCTAssertNil(tm.preferredColorScheme)
    }

    func testPersistsAndRestores() {
        let d = makeDefaults()
        let tm = ThemeManager(defaults: d)
        tm.appearance = .dark
        let restored = ThemeManager(defaults: d)
        XCTAssertEqual(restored.appearance, .dark)
        XCTAssertEqual(restored.preferredColorScheme, .dark)
    }
}
