import XCTest
@testable import WebPicCore

final class SnippetGeneratorTests: XCTestCase {
    private func input(lazy: Bool = true, formats: [ImageFormat] = [.avif, .webp, .jpeg]) -> SnippetInput {
        SnippetInput(baseName: "hero", formats: formats, width: 1200, height: 600,
                     lazy: lazy, responsive: false, breakpoints: [])
    }

    func testHTML() {
        let expected = """
        <picture>
          <source srcset="/img/hero.avif" type="image/avif">
          <source srcset="/img/hero.webp" type="image/webp">
          <img src="/img/hero.jpg" alt="" width="1200" height="600" loading="lazy" decoding="async">
        </picture>
        """
        XCTAssertEqual(SnippetGenerator.code(framework: .html, input: input()), expected)
    }

    func testLazyOff() {
        let out = SnippetGenerator.code(framework: .html, input: input(lazy: false))
        XCTAssertFalse(out.contains("loading=\"lazy\""))
        XCTAssertTrue(out.contains("decoding=\"async\""))
    }

    func testFallbackPNG() {
        let out = SnippetGenerator.code(framework: .html, input: input(formats: [.webp, .png]))
        XCTAssertTrue(out.contains("src=\"/img/hero.png\""))
        XCTAssertTrue(out.contains("type=\"image/webp\""))
        XCTAssertFalse(out.contains("image/avif"))
    }

    func testReactAndNextAndVue() {
        let react = SnippetGenerator.code(framework: .react, input: input())
        XCTAssertTrue(react.contains("srcSet=\"/img/hero.avif\""))
        XCTAssertTrue(react.contains("width={1200}"))
        let next = SnippetGenerator.code(framework: .next, input: input())
        XCTAssertTrue(next.contains("import Image from \"next/image\""))
        XCTAssertTrue(next.contains("<Image"))
        let vue = SnippetGenerator.code(framework: .vue, input: input())
        XCTAssertTrue(vue.hasPrefix("<template>"))
        XCTAssertTrue(vue.contains("<source srcset=\"/img/hero.webp\""))
    }
}
