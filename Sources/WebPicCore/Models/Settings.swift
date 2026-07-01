import Foundation

public struct Settings: Codable, Equatable, Sendable {
    public var outputMode: OutputMode
    public var preset: Preset.Key
    public var formats: Set<ImageFormat>
    public var compressionMode: CompressionMode
    public var quality: Int
    public var targetValue: String
    public var targetUnit: SizeUnit
    public var breakpoints: Set<Int>
    public var customBreakpoint: Int?
    public var colorSpace: ColorSpace
    public var keepMetadata: Bool
    public var filenameScheme: String
    /// Target output width in px for the `.custom` preset; nil → the preset's default width.
    /// Optional so settings persisted by older versions still decode.
    public var customWidth: Int? = nil

    public static let `default` = Settings(
        outputMode: .single,
        preset: .hero,
        formats: [.webp, .jpeg],
        compressionMode: .quality,
        quality: 78,
        targetValue: "200",
        targetUnit: .kb,
        breakpoints: [400, 800, 1200],
        customBreakpoint: nil,
        colorSpace: .sRGB,
        keepMetadata: false,
        filenameScheme: "{name}-{w}.{format}"
    )
}

public extension Settings {
    /// Cheap identity string to retrigger processing when settings change.
    var hashValueString: String {
        "\(outputMode.rawValue)-\(preset.rawValue)-\(formats.map(\.rawValue).sorted().joined())-\(compressionMode.rawValue)-\(quality)-\(targetValue)-\(targetUnit.rawValue)-\(colorSpace.rawValue)-\(targetWidth)"
    }

    /// Target output width in px: the custom override for the `.custom` preset, else the preset width.
    var targetWidth: Int {
        if preset == .custom, let w = customWidth, w > 0 { return w }
        return Preset.width(for: preset)
    }
}
