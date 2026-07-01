import CoreGraphics
import Foundation

public enum EncodeError: Error, Sendable { case destinationFailed, finalizeFailed, encodeFailed }

public protocol ImageEncoder: Sendable {
    var format: ImageFormat { get }
    /// Encode a CGImage. `quality` is 0.0...1.0 (ignored by lossless PNG).
    /// `metadata` (ImageIO property dict) is embedded when non-nil; ignored by encoders that don't support it.
    func encode(_ image: CGImage, quality: Double, metadata: [CFString: Any]?) throws -> Data
}

public extension ImageEncoder {
    func encode(_ image: CGImage, quality: Double) throws -> Data {
        try encode(image, quality: quality, metadata: nil)
    }
}
