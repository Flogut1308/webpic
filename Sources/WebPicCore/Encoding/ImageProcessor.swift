import CoreGraphics
import ImageIO
import Foundation

public struct ImageProcessor: Sendable {
    public init() {}

    /// Priority order for output listing.
    static let order: [ImageFormat] = [.avif, .webp, .jpeg, .png]

    func encoder(for format: ImageFormat) -> ImageEncoder {
        format == .webp ? WebPEncoder() : ImageIOEncoder(format: format)
    }

    public func loadCGImage(url: URL) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return orientedImage(from: src)
    }
    public func loadCGImage(data: Data) -> CGImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return orientedImage(from: src)
    }

    public enum EncodeSource: Sendable { case url(URL); case data(Data) }

    public func loadCGImage(_ source: EncodeSource) -> CGImage? {
        switch source {
        case .url(let u):  return loadCGImage(url: u)
        case .data(let d): return loadCGImage(data: d)
        }
    }

    /// Read the source's ImageIO property dict (EXIF/ICC/etc.) for re-embedding on encode.
    /// Orientation is reset to 1 — it's already baked into the decoded/oriented pixels.
    public func sourceMetadata(_ source: EncodeSource) -> [CFString: Any]? {
        let cfSrc: CGImageSource?
        switch source {
        case .url(let u):  cfSrc = CGImageSourceCreateWithURL(u as CFURL, nil)
        case .data(let d): cfSrc = CGImageSourceCreateWithData(d as CFData, nil)
        }
        guard let s = cfSrc,
              var props = CGImageSourceCopyPropertiesAtIndex(s, 0, nil) as? [CFString: Any] else { return nil }
        props[kCGImagePropertyOrientation] = 1        // orientation is baked into the pixels
        // Pixels are color-converted (sRGB/P3) before encode, so the SOURCE color profile no
        // longer describes them — drop it and let the destination write the converted profile.
        props[kCGImagePropertyProfileName] = nil
        // XMP isn't part of the property dict — grab the raw packet so encoders that need it
        // (WebP, via WebPMux) can re-embed it. Namespaced key; ImageIO destinations ignore it.
        if let md = CGImageSourceCopyMetadataAtIndex(s, 0, nil),
           let xmp = CGImageMetadataCreateXMPData(md, nil) as Data?, !xmp.isEmpty {
            props[WebPEncoder.xmpDataKey] = xmp
        }
        return props
    }
    private func orientedImage(from src: CGImageSource) -> CGImage? {
        guard let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]
        let orientation = (props?[kCGImagePropertyOrientation] as? UInt32) ?? 1
        return ImageResizer.applyOrientation(cg, orientation: orientation)
    }

    /// Resize + color-convert once, then encode each selected format at `settings.quality`.
    /// `sourceMetadata` (from `sourceMetadata(_:)`) is embedded only when `settings.keepMetadata` is true.
    public func process(source: CGImage, settings: Settings, sourceMetadata: [CFString: Any]? = nil) throws -> [EncodeResult] {
        let targetW = min(Preset.width(for: settings.preset), source.width)
        let resized = ImageResizer.resize(source, toWidth: targetW)
        let converted = ImageResizer.convert(resized, to: settings.colorSpace)
        let q = Double(settings.quality) / 100.0
        let selected = Self.order.filter { settings.formats.contains($0) }
        let meta = settings.keepMetadata ? sourceMetadata : nil
        return try selected.map { fmt in
            let data = try encoder(for: fmt).encode(converted, quality: fmt == .png ? 1 : q, metadata: meta)
            return EncodeResult(format: fmt, width: converted.width, height: converted.height,
                                byteSize: data.count, data: data,
                                quality: fmt == .png ? 100 : settings.quality)
        }
    }

    public struct TargetOutput: Sendable { public let results: [EncodeResult]; public let chosenQuality: Int }

    /// Target-file-size mode: solve quality on the primary format, encode all selected formats at it.
    /// `sourceMetadata` is embedded on ALL formats when `settings.keepMetadata`; the solver's
    /// already-encoded primary bytes are reused only when there's no metadata to embed.
    public func processForTarget(source: CGImage, settings: Settings, sourceMetadata: [CFString: Any]? = nil) throws -> TargetOutput {
        let targetW = min(Preset.width(for: settings.preset), source.width)
        let resized = ImageResizer.resize(source, toWidth: targetW)
        let converted = ImageResizer.convert(resized, to: settings.colorSpace)
        // Guard the Double first: Int(Double.nan) / Int(±inf) trap. Non-numeric or
        // out-of-range target (e.g. cleared field) falls back to a 1-byte floor,
        // so the solver returns the smallest feasible result instead of crashing.
        let tb = EstimationService.targetBytes(settings)
        let targetBytes = (tb.isFinite && tb >= 1) ? Int(tb) : 1
        let primary = EstimationService.primaryFormat(settings.formats)
        let solution = try TargetSizeSolver.solve(image: converted, encoder: encoder(for: primary),
                                                  targetBytes: targetBytes)
        let q = Double(solution.quality) / 100.0
        let selected = Self.order.filter { settings.formats.contains($0) }
        let meta = settings.keepMetadata ? sourceMetadata : nil
        let results = try selected.map { fmt -> EncodeResult in
            // Reuse the solver's primary bytes only when there's no metadata to embed;
            // otherwise re-encode the primary (at the solved quality) WITH metadata too.
            let data = (fmt == primary && meta == nil)
                ? solution.data
                : try encoder(for: fmt).encode(converted, quality: fmt == .png ? 1 : q, metadata: meta)
            return EncodeResult(format: fmt, width: converted.width, height: converted.height,
                                byteSize: data.count, data: data,
                                quality: fmt == .png ? 100 : solution.quality)
        }
        return TargetOutput(results: results, chosenQuality: solution.quality)
    }
}
