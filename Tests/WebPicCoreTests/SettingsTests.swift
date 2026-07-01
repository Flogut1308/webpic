import XCTest
@testable import WebPicCore

final class SettingsTests: XCTestCase {
    func testCodableRoundTrip() throws {
        var s = Settings.default
        s.compressionMode = .target
        s.targetValue = "150"
        s.targetUnit = .mb
        s.formats = [.webp, .avif]
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(Settings.self, from: data)
        XCTAssertEqual(s, back)
    }

    func testPresetTable() {
        let hero = Preset.all.first { $0.key == .hero }!
        XCTAssertEqual(hero.width, 1920)
        XCTAssertEqual(hero.defaultQuality, 80)
        XCTAssertEqual(Preset.all.map(\.key), [.hero, .content, .thumb, .icon, .custom])
    }

    func testDefaults() {
        let s = Settings.default
        XCTAssertEqual(s.outputMode, .single)
        XCTAssertEqual(s.preset, .hero)
        XCTAssertEqual(s.formats, [.webp, .jpeg])
        XCTAssertEqual(s.compressionMode, .quality)
        XCTAssertEqual(s.quality, 78)
        XCTAssertEqual(s.targetValue, "200")
        XCTAssertEqual(s.targetUnit, .kb)
    }
}
