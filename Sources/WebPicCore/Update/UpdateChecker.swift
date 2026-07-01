import Foundation

public enum UpdateChecker {
    public static func parseLatestRelease(_ data: Data) -> ReleaseInfo? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = obj["tag_name"] as? String else { return nil }
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let body = (obj["body"] as? String) ?? ""
        let notes = body.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .map { $0.hasPrefix("- ") ? String($0.dropFirst(2)) : $0 }
            .filter { !$0.isEmpty }
        let assets = (obj["assets"] as? [[String: Any]]) ?? []
        let dmg = assets.first { ($0["browser_download_url"] as? String)?.hasSuffix(".dmg") == true }
        let urlString = (dmg?["browser_download_url"] as? String) ?? (obj["html_url"] as? String)
        guard let urlString, let url = URL(string: urlString) else { return nil }
        let size = dmg?["size"] as? Int
        return ReleaseInfo(version: version, notes: notes, downloadURL: url, sizeBytes: size)
    }
}
