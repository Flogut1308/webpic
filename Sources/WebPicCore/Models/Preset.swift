import Foundation

public struct Preset: Equatable, Sendable, Identifiable {
    public enum Key: String, Codable, CaseIterable, Sendable {
        case hero, content, thumb, icon, custom
    }
    public let key: Key
    public let label: String
    public let sub: String
    public let width: Int
    public let defaultQuality: Int
    public var id: Key { key }

    public static let all: [Preset] = [
        Preset(key: .hero,    label: "Hero-Image",    sub: "1920w", width: 1920, defaultQuality: 80),
        Preset(key: .content, label: "Content-Bild",  sub: "1200w", width: 1200, defaultQuality: 72),
        Preset(key: .thumb,   label: "Thumbnail",     sub: "400w",  width: 400,  defaultQuality: 65),
        Preset(key: .icon,    label: "Icon / Avatar", sub: "256w",  width: 256,  defaultQuality: 90),
        Preset(key: .custom,  label: "Custom",        sub: "frei",  width: 1600, defaultQuality: 78),
    ]

    public static func width(for key: Key) -> Int { all.first { $0.key == key }!.width }
    public static func defaultQuality(for key: Key) -> Int { all.first { $0.key == key }!.defaultQuality }
}
