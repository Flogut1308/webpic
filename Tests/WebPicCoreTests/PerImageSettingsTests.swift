import XCTest
@testable import WebPicCore

@MainActor
final class PerImageSettingsTests: XCTestCase {
    private func store() -> AppStore {
        let s = AppStore(defaults: UserDefaults(suiteName: "wp.\(UUID().uuidString)")!)
        s.images = [
            WebPicImage(id: "a", name: "a.jpg", pixelWidth: 100, pixelHeight: 100, byteSize: 1, status: .waiting),
            WebPicImage(id: "b", name: "b.jpg", pixelWidth: 100, pixelHeight: 100, byteSize: 1, status: .waiting),
        ]
        s.selectedID = "a"
        return s
    }

    func testGlobalWhenSameForAll() {
        let s = store(); s.sameForAll = true
        s.selectPreset(.thumb)
        XCTAssertEqual(s.settings.preset, .thumb)
        XCTAssertNil(s.images[0].settingsOverride)
    }

    func testPerImageOverrideIsolated() {
        let s = store(); s.sameForAll = false
        s.selectPreset(.icon)
        XCTAssertEqual(s.images[0].settingsOverride?.preset, .icon)
        XCTAssertNil(s.images[1].settingsOverride)
        XCTAssertEqual(s.effectiveSettings(for: s.images[1]).preset, s.settings.preset)
        XCTAssertEqual(s.effectiveSettings(for: s.images[0]).preset, .icon)
    }
}
