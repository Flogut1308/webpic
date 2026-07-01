import Foundation

public struct ReleaseInfo: Equatable, Sendable {
    public let version: String
    public let notes: [String]
    public let downloadURL: URL
    public let sizeBytes: Int?
    public init(version: String, notes: [String], downloadURL: URL, sizeBytes: Int?) {
        self.version = version; self.notes = notes; self.downloadURL = downloadURL; self.sizeBytes = sizeBytes
    }
}
