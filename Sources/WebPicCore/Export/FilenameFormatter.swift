import Foundation

public enum FilenameFormatter {
    public static func fileExtension(_ format: ImageFormat) -> String {
        switch format {
        case .jpeg: return "jpg"
        case .png:  return "png"
        case .avif: return "avif"
        case .webp: return "webp"
        }
    }

    public static func expand(_ scheme: String, name: String, width: Int, height: Int = 0,
                              format: ImageFormat) -> String {
        let base = (name as NSString).deletingPathExtension
        return scheme
            .replacingOccurrences(of: "{name}", with: base)
            .replacingOccurrences(of: "{w}", with: "\(width)")
            .replacingOccurrences(of: "{h}", with: "\(height)")
            .replacingOccurrences(of: "{format}", with: fileExtension(format))
    }
}
