import CoreGraphics
import Foundation
import libwebp

public struct WebPEncoder: ImageEncoder {
    public let format: ImageFormat = .webp
    public init() {}

    public func encode(_ image: CGImage, quality: Double) throws -> Data {
        let width = image.width, height = image.height
        let bytesPerRow = width * 4
        var rgba = [UInt8](repeating: 0, count: bytesPerRow * height)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &rgba, width: width, height: height, bitsPerComponent: 8,
                                  bytesPerRow: bytesPerRow, space: cs,
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
        return Data(bytes: out, count: size)
    }
}
