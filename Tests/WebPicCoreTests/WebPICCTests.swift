import XCTest
import CoreGraphics
import ImageIO
@testable import WebPicCore

final class WebPICCTests: XCTestCase {
    private func p3Image(_ w: Int, _ h: Int) -> CGImage {
        let cs = CGColorSpace(name: CGColorSpace.displayP3)!
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.8, green: 0.2, blue: 0.3, alpha: 1)); ctx.fill(CGRect(x:0,y:0,width:w,height:h))
        return ctx.makeImage()!
    }
    private func hasChunk(_ data: Data, _ fourcc: String) -> Bool {
        data.range(of: fourcc.data(using: .ascii)!) != nil
    }

    func testICCEmbeddedWhenMetadata() throws {
        let img = p3Image(64, 64)
        let data = try WebPEncoder().encode(img, quality: 0.8, metadata: [:])
        XCTAssertTrue(hasChunk(data, "ICCP"), "expected ICCP chunk")
        let src = CGImageSourceCreateWithData(data as CFData, nil)!
        let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as! [CFString: Any]
        XCTAssertEqual(props[kCGImagePropertyPixelWidth] as? Int, 64)
    }

    func testNoICCWhenNil() throws {
        let img = p3Image(64, 64)
        let data = try WebPEncoder().encode(img, quality: 0.8, metadata: nil)
        XCTAssertFalse(hasChunk(data, "ICCP"))
    }
}
