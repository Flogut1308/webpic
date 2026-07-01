import XCTest
@testable import WebPicCore

final class EstimationServiceTests: XCTestCase {
    private func hero() -> WebPicImage {
        WebPicImage(id: "i1", name: "hero-banner.jpg", pixelWidth: 4032, pixelHeight: 2268,
                    byteSize: 6_083_000, status: .done)
    }

    func testFormatFactors() {
        XCTAssertEqual(EstimationService.formatFactor(.avif), 0.30, accuracy: 0.0001)
        XCTAssertEqual(EstimationService.formatFactor(.webp), 0.44, accuracy: 0.0001)
        XCTAssertEqual(EstimationService.formatFactor(.jpeg), 0.64, accuracy: 0.0001)
        XCTAssertEqual(EstimationService.formatFactor(.png), 0.90, accuracy: 0.0001)
    }

    func testPrimaryFormat() {
        XCTAssertEqual(EstimationService.primaryFormat([.jpeg, .avif, .webp]), .avif)
        XCTAssertEqual(EstimationService.primaryFormat([.jpeg, .webp]), .webp)
        XCTAssertEqual(EstimationService.primaryFormat([.jpeg]), .jpeg)
        XCTAssertEqual(EstimationService.primaryFormat([.png]), .png)
        XCTAssertEqual(EstimationService.primaryFormat([]), .webp)
    }

    func testEstimatedBytesQuality() {
        var s = Settings.default
        s.quality = 78
        let area = pow(1920.0 / 4032.0, 2)
        let expected = max(8000, Int((6_083_000.0 * area * 0.44 * (0.14 + 0.78 * 0.86)).rounded()))
        XCTAssertEqual(EstimationService.estimatedBytes(image: hero(), settings: s), expected)
    }

    func testNewDimensions() {
        let d = EstimationService.newDimensions(image: hero(), settings: .default)
        XCTAssertEqual(d.width, 1920)
        XCTAssertEqual(d.height, Int((1920.0 * 2268.0 / 4032.0).rounded()))
    }

    func testTargetBytesAndError() {
        var s = Settings.default
        s.compressionMode = .target
        s.targetValue = "200"; s.targetUnit = .kb
        XCTAssertEqual(EstimationService.targetBytes(s), 200 * 1024, accuracy: 0.5)
        XCTAssertFalse(EstimationService.targetError(image: hero(), settings: s))
        s.targetValue = "1"
        XCTAssertTrue(EstimationService.targetError(image: hero(), settings: s))
        s.targetValue = "abc"
        XCTAssertTrue(EstimationService.targetError(image: hero(), settings: s))
    }

    func testAutoQualityClamped() {
        var s = Settings.default
        s.compressionMode = .target
        s.targetValue = "5"; s.targetUnit = .kb
        XCTAssertEqual(EstimationService.autoQuality(image: hero(), settings: s), 5)
    }

    func testSavingsPercent() {
        let pct = EstimationService.savingsPercent(image: hero(), settings: .default)
        XCTAssertGreaterThan(pct, 0)
        XCTAssertLessThanOrEqual(pct, 100)
    }

    func testCustomTargetWidth() {
        var s = Settings.default
        s.preset = .custom
        XCTAssertEqual(s.targetWidth, 1600, "custom falls back to its default width when unset")
        s.customWidth = 960
        XCTAssertEqual(s.targetWidth, 960)
        // A custom width only applies to the custom preset.
        s.preset = .hero
        XCTAssertEqual(s.targetWidth, 1920)
    }

    func testCustomWidthDrivesEstimateAndDimensions() {
        var s = Settings.default
        s.preset = .custom
        s.customWidth = 800
        XCTAssertEqual(EstimationService.newDimensions(image: hero(), settings: s).width, 800)
    }

    func testPerFormatEstimateOrdersByFormatFactor() {
        var s = Settings.default
        s.quality = 78
        let avif = EstimationService.estimatedBytes(image: hero(), settings: s, format: .avif)
        let webp = EstimationService.estimatedBytes(image: hero(), settings: s, format: .webp)
        let jpeg = EstimationService.estimatedBytes(image: hero(), settings: s, format: .jpeg)
        XCTAssertLessThan(avif, webp)
        XCTAssertLessThan(webp, jpeg)
        // For the primary format in quality mode, the per-format value matches the overall estimate.
        XCTAssertEqual(EstimationService.estimatedBytes(image: hero(), settings: s, format: .webp),
                       EstimationService.estimatedBytes(image: hero(), settings: s))
    }
}
