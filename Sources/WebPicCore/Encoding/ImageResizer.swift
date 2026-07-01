import CoreGraphics
import Foundation

public enum ImageResizer {
    /// Downscale to `toWidth` preserving aspect ratio. Never upscales.
    public static func resize(_ image: CGImage, toWidth: Int) -> CGImage {
        let w = image.width, h = image.height
        guard toWidth > 0, toWidth < w else { return image }
        let newW = toWidth
        let newH = max(1, Int((Double(h) * Double(newW) / Double(w)).rounded()))
        let cs = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: nil, width: newW, height: newH, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return image }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: newW, height: newH))
        return ctx.makeImage() ?? image
    }

    public static func convert(_ image: CGImage, to colorSpace: ColorSpace) -> CGImage {
        let cs: CGColorSpace = colorSpace == .displayP3
            ? (CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB())
            : (CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB())
        let w = image.width, h = image.height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: cs,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return image }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage() ?? image
    }
}
