import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public struct ImportedImage: Sendable {
    public let name: String
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let byteSize: Int
    public let thumbnailPNG: Data?
    public let url: URL?
}

public enum ImageImportError: Error, Sendable {
    case unreadable
    case notAnImage
}

public enum ImageImportService {
    public static let supportedTypes: [UTType] =
        [.jpeg, .png, .heic, .heif, .webP, .tiff, .gif]

    public static func load(url: URL, thumbnailMaxPixel: Int = 160) throws -> ImportedImage {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw ImageImportError.unreadable
        }
        let byteSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return try build(from: src, name: url.lastPathComponent, url: url,
                         byteSize: byteSize, thumbnailMaxPixel: thumbnailMaxPixel)
    }

    public static func load(data: Data, name: String, thumbnailMaxPixel: Int = 160) throws -> ImportedImage {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw ImageImportError.unreadable
        }
        return try build(from: src, name: name, url: nil,
                         byteSize: data.count, thumbnailMaxPixel: thumbnailMaxPixel)
    }

    private static func build(from src: CGImageSource, name: String, url: URL?,
                              byteSize: Int, thumbnailMaxPixel: Int) throws -> ImportedImage {
        guard let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int,
              w > 0, h > 0 else {
            throw ImageImportError.notAnImage
        }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: thumbnailMaxPixel,
        ]
        var thumb: Data? = nil
        if let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) {
            thumb = pngData(from: cg)
        }
        return ImportedImage(name: name, pixelWidth: w, pixelHeight: h,
                             byteSize: byteSize, thumbnailPNG: thumb, url: url)
    }

    static func pngData(from image: CGImage) -> Data? {
        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            out as CFMutableData, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return out as Data
    }
}
