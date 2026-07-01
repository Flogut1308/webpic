import Foundation

public enum TokenKind: Sendable, Hashable { case text, tag, string, attribute, keyword, comment }

public struct CodeToken: Sendable, Equatable {
    public let text: String
    public let kind: TokenKind
    public init(_ text: String, _ kind: TokenKind) { self.text = text; self.kind = kind }
}

public enum SyntaxHighlighter {
    /// Tokenize for coloring. Round-trippable: tokens.map(\.text).joined() == input.
    public static func tokenize(_ code: String) -> [CodeToken] {
        // Group order: 1=string, 2=tag delimiter, 3=keyword, 4=attribute-name (followed by '=').
        let pattern = #"("(?:[^"\\]|\\.)*")|(</?[A-Za-z][\w.-]*|/?>)|\b(import|export|default|function|return|from)\b|([A-Za-z-]+)(?=\s*=)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [CodeToken(code, .text)] }
        let ns = code as NSString
        var out: [CodeToken] = []
        var last = 0
        for m in regex.matches(in: code, range: NSRange(location: 0, length: ns.length)) {
            if m.range.location > last {
                out.append(CodeToken(ns.substring(with: NSRange(location: last, length: m.range.location - last)), .text))
            }
            let txt = ns.substring(with: m.range)
            let kind: TokenKind
            if m.range(at: 1).location != NSNotFound { kind = .string }
            else if m.range(at: 2).location != NSNotFound { kind = .tag }
            else if m.range(at: 3).location != NSNotFound { kind = .keyword }
            else { kind = .attribute }
            out.append(CodeToken(txt, kind))
            last = m.range.location + m.range.length
        }
        if last < ns.length { out.append(CodeToken(ns.substring(from: last), .text)) }
        return out
    }
}
