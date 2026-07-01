import CoreGraphics
import Foundation
import libwebp

public struct WebPEncoder: ImageEncoder {
    public let format: ImageFormat = .webp
    public init() {}

    public func encode(_ image: CGImage, quality: Double, metadata: [CFString: Any]? = nil) throws -> Data {
        let width = image.width, height = image.height
        let bytesPerRow = width * 4
        var rgba = [UInt8](repeating: 0, count: bytesPerRow * height)
        // When embedding ICC (keepMetadata), draw into the image's OWN colorspace so the
        // pixels match the profile we attach; otherwise flatten to deviceRGB (assumed sRGB).
        let embedICC = metadata != nil
        let space = (embedICC ? image.colorSpace : nil) ?? CGColorSpaceCreateDeviceRGB()
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

        guard embedICC, let icc = space.copyICCData() as Data? else { return webp }
        return Self.embedICC(webp, icc: icc) ?? webp
    }

    /// Attach an ICCP chunk to an existing WebP via WebPMux.
    private static func embedICC(_ webp: Data, icc: Data) -> Data? {
        var input = WebPData()
        var assembled = WebPData()
        return webp.withUnsafeBytes { (wp: UnsafeRawBufferPointer) -> Data? in
            input.bytes = wp.bindMemory(to: UInt8.self).baseAddress
            input.size = webp.count
            guard let mux = WebPMuxCreate(&input, 1) else { return nil }
            defer { WebPMuxDelete(mux) }
            return icc.withUnsafeBytes { (ib: UnsafeRawBufferPointer) -> Data? in
                var iccChunk = WebPData()
                iccChunk.bytes = ib.bindMemory(to: UInt8.self).baseAddress
                iccChunk.size = icc.count
                guard WebPMuxSetChunk(mux, "ICCP", &iccChunk, 1) == WEBP_MUX_OK,
                      WebPMuxAssemble(mux, &assembled) == WEBP_MUX_OK else { return nil }
                defer { WebPDataClear(&assembled) }
                return Data(bytes: assembled.bytes, count: assembled.size)
            }
        }
    }
}
