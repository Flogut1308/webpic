import Foundation

public enum ExportService {
    @discardableResult
    public static func write(results: [EncodeResult], to directory: URL,
                             originalName: String, scheme: String) throws -> [URL] {
        var urls: [URL] = []
        for r in results {
            let filename = FilenameFormatter.expand(scheme, name: originalName, width: r.width, height: r.height, format: r.format)
            let url = directory.appendingPathComponent(filename)
            try r.data.write(to: url)
            urls.append(url)
        }
        return urls
    }
}
