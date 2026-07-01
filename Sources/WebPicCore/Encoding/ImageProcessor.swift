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
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }
    public func loadCGImage(data: Data) -> CGImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
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
        let targetBytes = Int(EstimationService.targetBytes(settings))
        let primary = EstimationService.primaryFormat(settings.formats)
        let solution = try TargetSizeSolver.solve(image: converted, encoder: encoder(for: primary),
                                                  targetBytes: max(1, targetBytes))
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
