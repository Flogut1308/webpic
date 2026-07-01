import Foundation

public struct Settings: Codable, Equatable, Sendable {
    public var outputMode: OutputMode
    public var preset: Preset.Key
    public var formats: Set<ImageFormat>
    public var compression: Compression
    public var breakpoints: Set<Int>
    public var customBreakpoint: Int?
    public var colorSpace: ColorSpace
    public var keepMetadata: Bool
    public var filenameScheme: String

    public static let `default` = Settings(
        outputMode: .single,
        preset: .hero,
        formats: [.webp, .jpeg],
        compression: .quality(78),
        breakpoints: [400, 800, 1200],
        customBreakpoint: nil,
        colorSpace: .sRGB,
        keepMetadata: false,
        filenameScheme: "{name}-{w}.{format}"
    )
}
