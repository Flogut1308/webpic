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
    /// Mock gradient key used until real thumbnails exist (M2). Hex list.
    public var gradient: [UInt32]

    public init(id: String, name: String, pixelWidth: Int, pixelHeight: Int,
                byteSize: Int, status: ImageStatus, url: URL? = nil,
                gradient: [UInt32] = [0x5AC8FA, 0x0A84FF]) {
        self.id = id; self.name = name
        self.pixelWidth = pixelWidth; self.pixelHeight = pixelHeight
        self.byteSize = byteSize; self.status = status
        self.url = url; self.gradient = gradient
    }
}
