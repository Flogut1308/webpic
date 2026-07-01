import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation
import libwebp

public struct WebPEncoder: ImageEncoder {
    public let format: ImageFormat = .webp
    public init() {}

    /// Private metadata-dict key under which `ImageProcessor.sourceMetadata` stashes the raw XMP
    /// packet (CGImageSource gives XMP as a serialized packet, not as a `[CFString: Any]` entry).
    /// Namespaced so ImageIO destinations ignore it as an unknown key.
    public static let xmpDataKey = "wp.rawXMPData" as CFString

    public func encode(_ image: CGImage, quality: Double, metadata: [CFString: Any]? = nil) throws -> Data {
        let width = image.width, height = image.height
        let bytesPerRow = width * 4
        var rgba = [UInt8](repeating: 0, count: bytesPerRow * height)
        // When embedding metadata, draw into the image's OWN colorspace so the pixels match the
        // ICC profile we attach; otherwise flatten to deviceRGB (assumed sRGB).
        let embedMetadata = metadata != nil
        let space = (embedMetadata ? image.colorSpace : nil) ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &rgba, width: width, height: height, bitsPerComponent: 8,
                                  bytesPerRow: bytesPerRow, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw EncodeError.encodeFailed
        }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var output: UnsafeMutablePointer<UInt8>? = nil
        let q = Float(max(0, min(1, quality)) * 100)
        let size = rgba.withUnsafeBufferPointer { buf in
            WebPEncodeRGBA(buf.baseAddress, Int32(width), Int32(height), Int32(bytesPerRow), q, &output)
        }
        guard size > 0, let out = output else { throw EncodeError.encodeFailed }
        defer { WebPFree(out) }
        let webp = Data(bytes: out, count: size)

        guard let meta = metadata else { return webp }

        // Assemble whatever metadata chunks we have (ICC / EXIF / XMP) via WebPMux.
        var chunks: [(fourcc: String, data: Data)] = []
        if let icc = space.copyICCData() as Data? { chunks.append(("ICCP", icc)) }
        if let exif = Self.exifBlob(from: meta) { chunks.append(("EXIF", exif)) }
        if let xmp = meta[Self.xmpDataKey] as? Data, !xmp.isEmpty { chunks.append(("XMP ", xmp)) }
        guard !chunks.isEmpty else { return webp }
        return Self.mux(webp, chunks: chunks) ?? webp
    }

    /// Build a raw EXIF blob (TIFF stream) from the source's EXIF/GPS/TIFF property dictionaries by
    /// writing a 1×1 JPEG carrying them and extracting its APP1/Exif payload. Only public ImageIO
    /// API is used; the dummy 1×1 image keeps the intermediate tiny and the extracted blob is
    /// image-free (the standalone EXIF/TIFF structure WebP's EXIF chunk expects).
    static func exifBlob(from meta: [CFString: Any]) -> Data? {
        var props: [CFString: Any] = [:]
        for key in [kCGImagePropertyExifDictionary, kCGImagePropertyGPSDictionary,
                    kCGImagePropertyTIFFDictionary, kCGImagePropertyExifAuxDictionary] {
            if let dict = meta[key] { props[key] = dict }
        }
        guard !props.isEmpty else { return nil }

        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                  space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let dummy = ctx.makeImage() else { return nil }
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(dest, dummy, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return Self.extractEXIF(fromJPEG: out as Data)
    }

    /// Pull the TIFF/EXIF stream out of a JPEG's APP1 segment (drops the "Exif\0\0" identifier).
    private static func extractEXIF(fromJPEG jpeg: Data) -> Data? {
        let b = [UInt8](jpeg)
        guard b.count > 4, b[0] == 0xFF, b[1] == 0xD8 else { return nil }   // SOI
        var i = 2
        let exifID: [UInt8] = [0x45, 0x78, 0x69, 0x66, 0x00, 0x00]          // "Exif\0\0"
        while i + 4 <= b.count {
            guard b[i] == 0xFF else { return nil }
            let marker = b[i + 1]
            if marker == 0xDA || marker == 0xD9 { return nil }             // SOS / EOI: no APP1
            let len = Int(b[i + 2]) << 8 | Int(b[i + 3])                   // includes the 2 length bytes
            let payloadStart = i + 4
            let payloadEnd = i + 2 + len
            guard payloadEnd <= b.count else { return nil }
            if marker == 0xE1, payloadStart + exifID.count <= payloadEnd,
               Array(b[payloadStart..<payloadStart + exifID.count]) == exifID {
                return Data(b[(payloadStart + exifID.count)..<payloadEnd])
            }
            i = payloadEnd
        }
        return nil
    }

    /// Attach metadata chunks to an existing WebP via WebPMux, returning the reassembled container.
    private static func mux(_ webp: Data, chunks: [(fourcc: String, data: Data)]) -> Data? {
        var input = WebPData()
        var assembled = WebPData()
        return webp.withUnsafeBytes { (wp: UnsafeRawBufferPointer) -> Data? in
            input.bytes = wp.bindMemory(to: UInt8.self).baseAddress
            input.size = webp.count
            guard let mux = WebPMuxCreate(&input, 1) else { return nil }
            defer { WebPMuxDelete(mux) }
            for (fourcc, data) in chunks {
                let ok = data.withUnsafeBytes { (db: UnsafeRawBufferPointer) -> Bool in
                    var chunk = WebPData()
                    chunk.bytes = db.bindMemory(to: UInt8.self).baseAddress
                    chunk.size = data.count
                    return WebPMuxSetChunk(mux, fourcc, &chunk, 1) == WEBP_MUX_OK
                }
                guard ok else { return nil }
            }
            guard WebPMuxAssemble(mux, &assembled) == WEBP_MUX_OK else { return nil }
            defer { WebPDataClear(&assembled) }
            return Data(bytes: assembled.bytes, count: assembled.size)
        }
    }
}
