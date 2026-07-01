import XCTest
@testable import WebPicCore

final class UpdateParsingTests: XCTestCase {
    func testVersionCompare() {
        XCTAssertTrue(AppVersion("2.1") > AppVersion("2.0"))
        XCTAssertTrue(AppVersion("2.10") > AppVersion("2.9"))
        XCTAssertTrue(AppVersion("v2.1") > AppVersion("2.0"))
        XCTAssertFalse(AppVersion("2.0") > AppVersion("2.0"))
        XCTAssertEqual(AppVersion("2.0"), AppVersion("2.0"))
    }

    func testParseRelease() {
        let json = """
        {
          "tag_name": "v2.1",
          "html_url": "https://github.com/Flogut1308/webpic/releases/tag/v2.1",
          "body": "- AVIF-Encoder um bis zu 3× schneller\\n- Neues Next.js-Snippet\\n- EXIF-Fix",
          "assets": [
            { "browser_download_url": "https://github.com/Flogut1308/webpic/releases/download/v2.1/WebPic.dmg", "size": 14680064 }
          ]
        }
        """.data(using: .utf8)!
        let info = UpdateChecker.parseLatestRelease(json)!
        XCTAssertEqual(info.version, "2.1")
        XCTAssertEqual(info.notes.count, 3)
        XCTAssertEqual(info.notes.first, "AVIF-Encoder um bis zu 3× schneller")
        XCTAssertEqual(info.downloadURL.absoluteString, "https://github.com/Flogut1308/webpic/releases/download/v2.1/WebPic.dmg")
        XCTAssertEqual(info.sizeBytes, 14680064)
    }

    func testParseReleaseNoDMGFallsBackToHTMLURL() {
        let json = """
        {"tag_name":"2.2","html_url":"https://example.com/rel","body":"- x","assets":[]}
        """.data(using: .utf8)!
        let info = UpdateChecker.parseLatestRelease(json)!
        XCTAssertEqual(info.version, "2.2")
        XCTAssertEqual(info.downloadURL.absoluteString, "https://example.com/rel")
        XCTAssertNil(info.sizeBytes)
    }

    func testMalformed() {
        XCTAssertNil(UpdateChecker.parseLatestRelease("not json".data(using: .utf8)!))
    }

    func testParseCRLFBody() throws {
        // GitHub transmits release bodies with CRLF line endings.
        let json = try JSONSerialization.data(withJSONObject: [
            "tag_name": "v2.1",
            "html_url": "https://x/rel",
            "body": "- one\r\n- two\r\n- three",
            "assets": [],
        ])
        let info = UpdateChecker.parseLatestRelease(json)!
        XCTAssertEqual(info.notes, ["one", "two", "three"])
    }
}
