import CoreGraphics
import Foundation

public enum EncodeError: Error, Sendable { case destinationFailed, finalizeFailed, encodeFailed }

public protocol ImageEncoder: Sendable {
    var format: ImageFormat { get }
    /// Encode a CGImage. `quality` is 0.0...1.0 (ignored by lossless PNG).
    func encode(_ image: CGImage, quality: Double) throws -> Data
}
