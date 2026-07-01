import SwiftUI
import Observation

@Observable
public final class ThemeManager {
    public enum Appearance: String, CaseIterable, Sendable {
        case system, light, dark
    }

    public static let storageKey = "wp.appearance"

    @ObservationIgnored private let defaults: UserDefaults

    public var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Self.storageKey) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.string(forKey: Self.storageKey) ?? ""
        self.appearance = Appearance(rawValue: raw) ?? .system
    }

    public var preferredColorScheme: ColorScheme? {
        switch appearance {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}
