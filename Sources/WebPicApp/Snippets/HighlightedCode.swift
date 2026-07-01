import SwiftUI
import WebPicCore

struct HighlightedCode: View {
    let code: String
    @Environment(\.wpPalette) private var p

    private func color(_ kind: TokenKind) -> Color {
        switch kind {
        case .text: return p.t1
        case .tag: return Color(hex: 0xE5709F)
        case .string: return Color(hex: 0xE0913A)
        case .attribute: return Color(hex: 0x9C7BFF)
        case .keyword: return Color(hex: 0x5AB0FF)
        case .comment: return p.t3
        }
    }

    var body: some View {
        var str = AttributedString()
        for t in SyntaxHighlighter.tokenize(code) {
            var seg = AttributedString(t.text)
            seg.foregroundColor = color(t.kind)
            str += seg
        }
        return Text(str)
            .font(.system(size: 12.5, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}
