import XCTest
@testable import WebPicCore

@MainActor
final class AppStoreSettingsTests: XCTestCase {
    private func store(_ d: UserDefaults) -> AppStore { AppStore(defaults: d) }

    func testSelectPresetSetsQuality() {
        let s = store(UserDefaults(suiteName: "wp.\(UUID().uuidString)")!)
        s.selectPreset(.thumb)
        XCTAssertEqual(s.settings.preset, .thumb)
        XCTAssertEqual(s.settings.quality, 65)
        s.selectPreset(.icon)
        XCTAssertEqual(s.settings.quality, 90)
    }

    func testToggleFormat() {
        let s = store(UserDefaults(suiteName: "wp.\(UUID().uuidString)")!)
        XCTAssertTrue(s.settings.formats.contains(.webp))
        s.toggleFormat(.webp)
        XCTAssertFalse(s.settings.formats.contains(.webp))
        s.toggleFormat(.avif)
        XCTAssertTrue(s.settings.formats.contains(.avif))
    }

    func testSettingsPersist() {
        let d = UserDefaults(suiteName: "wp.\(UUID().uuidString)")!
        let s = store(d)
        s.selectPreset(.content)
        let reloaded = store(d)
        XCTAssertEqual(reloaded.settings.preset, .content)
        XCTAssertEqual(reloaded.settings.quality, 72)
    }
}
