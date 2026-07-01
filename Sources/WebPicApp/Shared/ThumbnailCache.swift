import AppKit
import ImageIO

/// Process-wide cache of decoded thumbnail images, keyed by image id, so `ThumbnailView`
/// doesn't re-decode the PNG bytes on every SwiftUI redraw (avoids scroll jank in lists/grids).
enum ThumbnailCache {
    private static let cache = NSCache<NSString, NSImage>()

    static func image(id: String, data: Data) -> NSImage? {
        if let hit = cache.object(forKey: id as NSString) { return hit }
        guard let img = NSImage(data: data) else { return nil }
        cache.setObject(img, forKey: id as NSString)
        return img
    }

    /// A downsampled, orientation-corrected preview (max `maxPixel`) from a URL or raw data,
    /// cached — used for the Compare "before" image so the full-res original isn't decoded
    /// on the main thread on every redraw.
    static func downsampled(id: String, url: URL?, data: Data?, maxPixel: Int = 1600) -> NSImage? {
        let key = "cmp-\(id)-\(maxPixel)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        let src: CGImageSource?
        if let url { src = CGImageSourceCreateWithURL(url as CFURL, nil) }
        else if let data { src = CGImageSourceCreateWithData(data as CFData, nil) }
        else { return nil }
        guard let s = src else { return nil }
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,   // apply EXIF orientation
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(s, 0, opts as CFDictionary) else { return nil }
        let img = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        cache.setObject(img, forKey: key)
        return img
    }
}
