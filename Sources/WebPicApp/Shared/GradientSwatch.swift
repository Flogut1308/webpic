import SwiftUI
import WebPicCore

struct GradientSwatch: View {
    let hexes: [UInt32]
    var cornerRadius: CGFloat = 7
    var body: some View {
        LinearGradient(
            colors: hexes.map { Color(hex: $0) },
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
