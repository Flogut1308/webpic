import SwiftUI

struct BeforeAfterSlider: View {
    let before: NSImage
    let after: NSImage
    @State private var fraction: CGFloat = 0.5
    @Environment(\.wpPalette) private var p

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Image(nsImage: after).resizable().aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height).clipped()
                Image(nsImage: before).resizable().aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height).clipped()
                    .mask(alignment: .leading) { Rectangle().frame(width: geo.size.width * fraction) }
                Text("Original").font(.system(size: 11, weight: .semibold)).padding(.horizontal, 10).padding(.vertical, 4)
                    .background(.black.opacity(0.5), in: Capsule()).foregroundStyle(.white).padding(14)
                Text("Optimiert").font(.system(size: 11, weight: .semibold)).padding(.horizontal, 10).padding(.vertical, 4)
                    .background(p.accent.opacity(0.85), in: Capsule()).foregroundStyle(.white).padding(14)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Rectangle().fill(.white).frame(width: 2).frame(maxHeight: .infinity)
                    .position(x: geo.size.width * fraction, y: geo.size.height / 2).shadow(radius: 1)
                Circle().fill(.white).frame(width: 36, height: 36).shadow(radius: 3)
                    .overlay { Image(systemName: "chevron.left.chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(p.accent) }
                    .position(x: geo.size.width * fraction, y: geo.size.height / 2)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                fraction = max(0, min(1, v.location.x / geo.size.width))
            })
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
