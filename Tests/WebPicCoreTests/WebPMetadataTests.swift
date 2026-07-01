import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import WebPicCore

/// Covers EXIF + XMP embedding in WebP output (parity with the other formats' metadata handling).
final class WebPMetadataTests: XCTestCase {

    // MARK: - Fixtures

    private static func solidImage(_ w: Int, _ h: Int) -> CGImage {
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.4, green: 0.5, blue: 0.6, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()!
    }

    /// A small JPEG carrying the given ImageIO property sub-dictionaries (EXIF/GPS/TIFF).
    private static func makeJPEG(props: [CFString: Any]) -> Data {
        let out = NSMutableData()
        let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, solidImage(8, 8), props as CFDictionary)
        CGImageDestinationFinalize(dest)
        return out as Data
    }

    /// A small JPEG carrying an XMP packet with a recognizable marker in dc:description.
    private static func makeJPEGWithXMP(_ marker: String) -> Data {
        let md = CGImageMetadataCreateMutable()
        let tag = CGImageMetadataTagCreate("http://purl.org/dc/elements/1.1/" as CFString,
                                           "dc" as CFString, "description" as CFString,
                                           .string, marker as CFString)!
        CGImageMetadataSetTagWithPath(md, nil, "dc:description" as CFString, tag)
        let out = NSMutableData()
        let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil)!
        CGImageDestinationAddImageAndMetadata(dest, solidImage(8, 8), md, nil)
        CGImageDestinationFinalize(dest)
        return out as Data
    }

    /// Parse a WebP RIFF container into fourcc -> payload. Handles the extended (VP8X) layout.
    private static func riffChunks(_ data: Data) -> [String: Data] {
        var result: [String: Data] = [:]
        let bytes = [UInt8](data)
        guard bytes.count > 12,
              Array(bytes[0..<4]) == Array("RIFF".utf8),
              Array(bytes[8..<12]) == Array("WEBP".utf8) else { return result }
        var i = 12
        while i + 8 <= bytes.count {
            let fourcc = String(bytes: bytes[i..<i + 4], encoding: .ascii) ?? ""
            let size = Int(bytes[i + 4]) | Int(bytes[i + 5]) << 8 | Int(bytes[i + 6]) << 16 | Int(bytes[i + 7]) << 24
            let start = i + 8
            let end = min(start + size, bytes.count)
            result[fourcc] = Data(bytes[start..<end])
            i = start + size + (size & 1)   // chunk payloads are padded to an even length
        }
        return result
    }

    // MARK: - EXIF

    func testWebPEmbedsEXIFChunkFromSourceMetadata() throws {
        let tiff: [CFString: Any] = [kCGImagePropertyTIFFMake: "TestCam",
                                     kCGImagePropertyTIFFModel: "ModelX"]
        let gps: [CFString: Any] = [kCGImagePropertyGPSLatitude: 37.33,
                                    kCGImagePropertyGPSLatitudeRef: "N"]
        let src = Self.makeJPEG(props: [kCGImagePropertyTIFFDictionary: tiff,
                                        kCGImagePropertyGPSDictionary: gps])
        let proc = ImageProcessor()
        let cg = try XCTUnwrap(proc.loadCGImage(data: src))
        let meta = proc.sourceMetadata(.data(src))
        let webp = try WebPEncoder().encode(cg, quality: 0.8, metadata: meta)

        let exif = try XCTUnwrap(Self.riffChunks(webp)["EXIF"], "WebP should contain an EXIF chunk")
        XCTAssertNotNil(exif.range(of: Data("TestCam".utf8)),
                        "EXIF blob should carry the camera Make")
    }

    // MARK: - XMP

    func testWebPEmbedsXMPChunkWhenRawXMPPresent() throws {
        let cg = Self.solidImage(16, 16)
        let packet = Data("<x:xmpmeta>WebPicMarker</x:xmpmeta>".utf8)
        let meta: [CFString: Any] = [WebPEncoder.xmpDataKey: packet]
        let webp = try WebPEncoder().encode(cg, quality: 0.8, metadata: meta)

        let xmp = try XCTUnwrap(Self.riffChunks(webp)["XMP "], "WebP should contain an XMP chunk")
        XCTAssertEqual(xmp, packet, "XMP chunk payload should be the raw packet, verbatim")
    }

    func testSourceMetadataExtractsRawXMP() throws {
        let src = Self.makeJPEGWithXMP("WebPicMarker")
        let meta = try XCTUnwrap(ImageProcessor().sourceMetadata(.data(src)))
        let xmp = try XCTUnwrap(meta[WebPEncoder.xmpDataKey] as? Data,
                                "sourceMetadata should surface the raw XMP packet")
        XCTAssertNotNil(xmp.range(of: Data("WebPicMarker".utf8)))
    }

    // MARK: - Full pipeline wiring

    func testProcessEmbedsEXIFInWebPWhenKeepMetadata() throws {
        let src = Self.makeJPEG(props: [kCGImagePropertyTIFFDictionary:
                                            [kCGImagePropertyTIFFMake: "PipelineCam"] as [CFString: Any]])
        let proc = ImageProcessor()
        let cg = try XCTUnwrap(proc.loadCGImage(data: src))
        let meta = proc.sourceMetadata(.data(src))
        var settings = Settings.default
        settings.formats = [.webp]
        settings.keepMetadata = true

        let webp = try XCTUnwrap(proc.process(source: cg, settings: settings, sourceMetadata: meta)
            .first { $0.format == .webp }?.data)
        let exif = try XCTUnwrap(Self.riffChunks(webp)["EXIF"])
        XCTAssertNotNil(exif.range(of: Data("PipelineCam".utf8)))
    }

    func testProcessOmitsEXIFWhenKeepMetadataOff() throws {
        let src = Self.makeJPEG(props: [kCGImagePropertyTIFFDictionary:
                                            [kCGImagePropertyTIFFMake: "PipelineCam"] as [CFString: Any]])
        let proc = ImageProcessor()
        let cg = try XCTUnwrap(proc.loadCGImage(data: src))
        let meta = proc.sourceMetadata(.data(src))
        var settings = Settings.default
        settings.formats = [.webp]
        settings.keepMetadata = false

        let webp = try XCTUnwrap(proc.process(source: cg, settings: settings, sourceMetadata: meta)
            .first { $0.format == .webp }?.data)
        XCTAssertNil(Self.riffChunks(webp)["EXIF"])
    }

    // MARK: - Off path

    func testNoMetadataChunksWhenNil() throws {
        let cg = Self.solidImage(16, 16)
        let webp = try WebPEncoder().encode(cg, quality: 0.8, metadata: nil)
        let chunks = Self.riffChunks(webp)
        XCTAssertNil(chunks["EXIF"])
        XCTAssertNil(chunks["XMP "])
        XCTAssertNil(chunks["ICCP"])
    }
}
