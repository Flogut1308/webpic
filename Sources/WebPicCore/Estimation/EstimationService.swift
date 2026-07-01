import Foundation

public enum EstimationService {
    public static func formatFactor(_ f: ImageFormat) -> Double {
        switch f {
        case .avif: return 0.30
        case .webp: return 0.44
        case .jpeg: return 0.64
        case .png:  return 0.90
        }
    }

    public static func primaryFormat(_ formats: Set<ImageFormat>) -> ImageFormat {
        if formats.contains(.avif) { return .avif }
        if formats.contains(.webp) { return .webp }
        if formats.contains(.jpeg) { return .jpeg }
        if formats.contains(.png)  { return .png }
        return .webp
    }

    public static func presetWidth(_ settings: Settings) -> Int {
        settings.targetWidth
    }

    static func targetWidth(image: WebPicImage, settings: Settings) -> Int {
        min(presetWidth(settings), image.pixelWidth)
    }

    static func areaFactor(image: WebPicImage, settings: Settings) -> Double {
        let tw = Double(targetWidth(image: image, settings: settings))
        let w = Double(image.pixelWidth)
        guard w > 0 else { return 1 }
        return pow(tw / w, 2)
    }

    public static func targetBytes(_ settings: Settings) -> Double {
        let normalized = settings.targetValue.replacingOccurrences(of: ",", with: ".")
        guard let v = Double(normalized) else { return .nan }
        return settings.targetUnit == .mb ? v * 1_048_576 : v * 1024
    }

    public static func feasibleMin(image: WebPicImage, settings: Settings) -> Double {
        let base = Double(image.byteSize)
            * areaFactor(image: image, settings: settings)
            * formatFactor(primaryFormat(settings.formats))
        return max(8000, base * 0.10)
    }

    public static func targetError(image: WebPicImage, settings: Settings) -> Bool {
        guard settings.compressionMode == .target else { return false }
        let tb = targetBytes(settings)
        if tb.isNaN || tb <= 0 { return true }
        return tb < feasibleMin(image: image, settings: settings)
    }

    public static func autoQuality(image: WebPicImage, settings: Settings) -> Int {
        let base = Double(image.byteSize)
            * areaFactor(image: image, settings: settings)
            * formatFactor(primaryFormat(settings.formats))
        guard base > 0 else { return 5 }
        let q = (targetBytes(settings) / base - 0.14) / 0.86 * 100
        return max(5, min(100, Int(q.rounded())))
    }

    public static func estimatedBytes(image: WebPicImage, settings: Settings) -> Int {
        if settings.compressionMode == .target {
            let tb = targetBytes(settings)
            return tb > 0 ? Int(tb) : 12000
        }
        let q = 0.14 + Double(settings.quality) / 100 * 0.86
        let b = Double(image.byteSize)
            * areaFactor(image: image, settings: settings)
            * formatFactor(primaryFormat(settings.formats))
            * q
        return max(8000, Int(b.rounded()))
    }

    /// Estimated output size for a specific format (for the multi-format preview breakdown).
    /// In target mode every format is estimated at the auto-solved quality, so only the primary
    /// lands near the requested target — the others show their honest relative size.
    public static func estimatedBytes(image: WebPicImage, settings: Settings, format: ImageFormat) -> Int {
        let qPercent = settings.compressionMode == .target
            ? Double(autoQuality(image: image, settings: settings))
            : Double(settings.quality)
        let q = 0.14 + qPercent / 100 * 0.86
        let b = Double(image.byteSize)
            * areaFactor(image: image, settings: settings)
            * formatFactor(format)
            * q
        return max(8000, Int(b.rounded()))
    }

    public static func savingsPercent(image: WebPicImage, settings: Settings) -> Int {
        guard image.byteSize > 0 else { return 0 }
        let ratio = 1 - Double(estimatedBytes(image: image, settings: settings)) / Double(image.byteSize)
        return max(0, Int((ratio * 100).rounded()))
    }

    public static func newDimensions(image: WebPicImage, settings: Settings) -> (width: Int, height: Int) {
        let tw = targetWidth(image: image, settings: settings)
        guard image.pixelWidth > 0 else { return (tw, 0) }
        let h = Double(tw) * Double(image.pixelHeight) / Double(image.pixelWidth)
        return (tw, Int(h.rounded()))
    }
}
