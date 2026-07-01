import Foundation

public enum UpdateChecker {
    public static func parseLatestRelease(_ data: Data) -> ReleaseInfo? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = obj["tag_name"] as? String else { return nil }
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let body = (obj["body"] as? String) ?? ""
        // GitHub bodies use CRLF; `.isNewline` splits LF, CR, and the `\r\n` grapheme alike.
        let notes = body.split(whereSeparator: \.isNewline)
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

    /// Returns the latest release ONLY if newer than `currentVersion`.
    /// `loader` is injectable for testing; defaults to a real GitHub API call.
    public static func fetchLatest(
        owner: String, repo: String, currentVersion: String,
        loader: @Sendable (URL) async -> Data? = { url in
            var req = URLRequest(url: url)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            return try? await URLSession.shared.data(for: req).0
        }
    ) async -> ReleaseInfo? {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
        guard let data = await loader(url), let info = parseLatestRelease(data) else { return nil }
        guard AppVersion(info.version) > AppVersion(currentVersion) else { return nil }
        return info
    }
}
