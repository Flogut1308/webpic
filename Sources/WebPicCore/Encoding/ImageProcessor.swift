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
    private func orientedImage(from src: CGImageSource) -> CGImage? {
        guard let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any]
        let orientation = (props?[kCGImagePropertyOrientation] as? UInt32) ?? 1
        return ImageResizer.applyOrientation(cg, orientation: orientation)
    }

    /// Resize + color-convert once, then encode each selected format at `settings.quality`.
    public func process(source: CGImage, settings: Settings) throws -> [EncodeResult] {
        let targetW = min(Preset.width(for: settings.preset), source.width)
        let resized = ImageResizer.resize(source, toWidth: targetW)
        let converted = ImageResizer.convert(resized, to: settings.colorSpace)
        let q = Double(settings.quality) / 100.0
        let selected = Self.order.filter { settings.formats.contains($0) }
        return try selected.map { fmt in
            let data = try encoder(for: fmt).encode(converted, quality: fmt == .png ? 1 : q)
            return EncodeResult(format: fmt, width: converted.width, height: converted.height,
                                byteSize: data.count, data: data,
                                quality: fmt == .png ? 100 : settings.quality)
        }
    }

    public struct TargetOutput: Sendable { public let results: [EncodeResult]; public let chosenQuality: Int }

    /// Target-file-size mode: solve quality on the primary format, encode all selected formats at it.
    public func processForTarget(source: CGImage, settings: Settings) throws -> TargetOutput {
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
        let results = try selected.map { fmt -> EncodeResult in
            let data = fmt == primary
                ? solution.data
                : try encoder(for: fmt).encode(converted, quality: fmt == .png ? 1 : q)
            return EncodeResult(format: fmt, width: converted.width, height: converted.height,
                                byteSize: data.count, data: data,
                                quality: fmt == .png ? 100 : solution.quality)
        }
        return TargetOutput(results: results, chosenQuality: solution.quality)
    }
}
