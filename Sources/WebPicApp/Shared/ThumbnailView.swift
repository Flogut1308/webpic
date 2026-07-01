import SwiftUI
import AppKit
import WebPicCore

struct ThumbnailView: View {
    let image: WebPicImage
    var cornerRadius: CGFloat = 7

    var body: some View {
        Group {
            if let data = image.thumbnailData, let ns = NSImage(data: data) {
                Image(nsImage: ns)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                GradientSwatch(hexes: image.gradient, cornerRadius: cornerRadius)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.black.opacity(0.12), lineWidth: 0.5)
        }
    }
}
