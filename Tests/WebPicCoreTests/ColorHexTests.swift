import XCTest
import SwiftUI
@testable import WebPicCore

final class ColorHexTests: XCTestCase {
    func testHexComponents() {
        let c = Color(hex: 0x0A84FF)
        let ns = NSColor(c).usingColorSpace(.sRGB)!
        XCTAssertEqual(Double(ns.redComponent),   10.0/255,  accuracy: 0.01)
        XCTAssertEqual(Double(ns.greenComponent), 132.0/255, accuracy: 0.01)
        XCTAssertEqual(Double(ns.blueComponent),  255.0/255, accuracy: 0.01)
    }
}
