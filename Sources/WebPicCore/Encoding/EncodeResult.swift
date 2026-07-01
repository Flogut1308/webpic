import Foundation

public struct EncodeResult: Sendable, Equatable {
    public let format: ImageFormat
    public let width: Int
    public let height: Int
    public let byteSize: Int
    public let data: Data
    public let quality: Int          // 0...100 (100 for lossless PNG)

    public init(format: ImageFormat, width: Int, height: Int, byteSize: Int, data: Data, quality: Int) {
        self.format = format; self.width = width; self.height = height
        self.byteSize = byteSize; self.data = data; self.quality = quality
    }
}
