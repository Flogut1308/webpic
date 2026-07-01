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
