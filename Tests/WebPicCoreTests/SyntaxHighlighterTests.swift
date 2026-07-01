import XCTest
@testable import WebPicCore

final class SyntaxHighlighterTests: XCTestCase {
    func testRoundTrip() {
        let code = "<img src=\"/img/hero.jpg\" width={1200} />"
        let tokens = SyntaxHighlighter.tokenize(code)
        XCTAssertEqual(tokens.map(\.text).joined(), code)
    }
    func testKinds() {
        let code = "<source srcset=\"x\" />"
        let kinds = Set(SyntaxHighlighter.tokenize(code).map(\.kind))
        XCTAssertTrue(kinds.contains(.tag))
        XCTAssertTrue(kinds.contains(.attribute))
        XCTAssertTrue(kinds.contains(.string))
    }
    func testKeywords() {
        let code = "import Image from \"next/image\";"
        let kinds = SyntaxHighlighter.tokenize(code).map(\.kind)
        XCTAssertTrue(kinds.contains(.keyword))
    }
    func testMultilineRoundTrip() {
        let code = "<picture>\n  <source srcset=\"/img/hero.webp\" type=\"image/webp\">\n</picture>"
        XCTAssertEqual(SyntaxHighlighter.tokenize(code).map(\.text).joined(), code)
    }
}
