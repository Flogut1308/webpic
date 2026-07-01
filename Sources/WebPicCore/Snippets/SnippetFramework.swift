public enum SnippetFramework: String, CaseIterable, Sendable {
    case html, react, next, vue
    public var label: String {
        switch self {
        case .html: return "HTML <picture>"
        case .react: return "React"
        case .next: return "Next.js"
        case .vue: return "Vue"
        }
    }
}
