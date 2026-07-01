import Foundation

public struct AppVersion: Comparable, Equatable, Sendable {
    public let components: [Int]
    public init(_ string: String) {
        let cleaned = string.hasPrefix("v") ? String(string.dropFirst()) : string
        components = cleaned.split(separator: ".").map { Int($0) ?? 0 }
    }
    public static func < (l: AppVersion, r: AppVersion) -> Bool {
        let n = max(l.components.count, r.components.count)
        for i in 0..<n {
            let a = i < l.components.count ? l.components[i] : 0
            let b = i < r.components.count ? r.components[i] : 0
            if a != b { return a < b }
        }
        return false
    }
}
