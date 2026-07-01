import Foundation

public enum ImageStatus: Equatable, Sendable {
    case waiting
    case processing(Double)   // 0...1
    case done
    case error(String)
}

public struct WebPicImage: Identifiable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var byteSize: Int
    public var status: ImageStatus
    public var url: URL?
    /// Persistent gradient fallback (hex list) rendered when `thumbnailData` is nil,
    /// e.g. for mock/seed images.
    public var gradient: [UInt32]
    /// PNG thumbnail bytes for real imports; nil → render the gradient placeholder.
    public var thumbnailData: Data?
    /// Original image bytes for data/Photos imports (no `url` to re-read); nil for file imports.
    public var sourceData: Data?
    /// Optimized outputs (populated by batch processing); empty until processed.
    public var results: [EncodeResult] = []

    public init(id: String, name: String, pixelWidth: Int, pixelHeight: Int,
                byteSize: Int, status: ImageStatus, url: URL? = nil,
                gradient: [UInt32] = [0x5AC8FA, 0x0A84FF], thumbnailData: Data? = nil,
                sourceData: Data? = nil) {
        self.id = id; self.name = name
        self.pixelWidth = pixelWidth; self.pixelHeight = pixelHeight
        self.byteSize = byteSize; self.status = status
        self.url = url; self.gradient = gradient
        self.thumbnailData = thumbnailData
        self.sourceData = sourceData
    }
}
