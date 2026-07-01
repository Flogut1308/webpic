import SwiftUI
import WebPicCore

struct WPSectionLabel: View {
    @Environment(\.wpPalette) private var p
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold)).kerning(0.3)
            .foregroundStyle(p.t3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4).padding(.bottom, 8)
    }
}

extension View {
    func wpCard(_ p: WPPalette) -> some View {
        self.background(p.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(p.sep, lineWidth: 0.5))
            .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
    }
}
