import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation

public struct ImageIOEncoder: ImageEncoder {
    public let format: ImageFormat
    public init(format: ImageFormat) { self.format = format }

    private var uti: CFString {
        switch format {
        case .jpeg: return UTType.jpeg.identifier as CFString
        case .png:  return UTType.png.identifier as CFString
        case .avif: return "public.avif" as CFString
        case .webp: return "org.webmproject.webp" as CFString
        }
    }

    public func encode(_ image: CGImage, quality: Double, metadata: [CFString: Any]? = nil) throws -> Data {
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out as CFMutableData, uti, 1, nil) else {
            throw EncodeError.destinationFailed
        }
        var props: [CFString: Any] = metadata ?? [:]
        if format != .png {
            props[kCGImageDestinationLossyCompressionQuality] = max(0, min(1, quality))
        }
        CGImageDestinationAddImage(dest, image, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw EncodeError.finalizeFailed }
        return out as Data
    }
}
