import AppKit

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
}
