import Foundation

public enum Tab: String, Codable, Sendable { case batch, settings, compare, export }
public enum OutputMode: String, Codable, CaseIterable, Sendable { case single, responsive, convert }
public enum ImageFormat: String, Codable, CaseIterable, Sendable { case webp, avif, jpeg, png }
public enum SizeUnit: String, Codable, Sendable { case kb, mb }
public enum ColorSpace: String, Codable, Sendable { case sRGB, displayP3 }

public enum CompressionMode: String, Codable, CaseIterable, Sendable { case quality, target }

public extension ImageFormat {
    var displayName: String {
        switch self {
        case .webp: return "WebP"
        case .avif: return "AVIF"
        case .jpeg: return "JPEG"
        case .png:  return "PNG"
        }
    }
}
