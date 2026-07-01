import XCTest
@testable import WebPicCore

final class SnippetResponsiveTests: XCTestCase {
    private func responsiveInput() -> SnippetInput {
        SnippetInput(baseName: "hero", formats: [.avif, .webp, .jpeg], width: 800, height: 400,
                     lazy: true, responsive: true, breakpoints: [400, 800])
    }
    func testResponsiveHTMLSrcset() {
        let out = SnippetGenerator.code(framework: .html, input: responsiveInput())
        XCTAssertTrue(out.contains("srcset=\"/img/hero-400.avif 400w, /img/hero-800.avif 800w\""))
        XCTAssertTrue(out.contains("sizes=\"100vw\""))
        XCTAssertTrue(out.contains("src=\"/img/hero-800.jpg\""))
    }
    func testResponsiveVue() {
        let out = SnippetGenerator.code(framework: .vue, input: responsiveInput())
        XCTAssertTrue(out.contains("srcset=\"/img/hero-400.webp 400w, /img/hero-800.webp 800w\""))
        XCTAssertTrue(out.hasPrefix("<template>"))
    }
}
