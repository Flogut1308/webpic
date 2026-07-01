import SwiftUI
import WebPicCore

struct SidebarView: View {
    @Environment(AppStore.self) private var store
    @Environment(ThemeManager.self) private var theme
    @Environment(\.wpPalette) private var p

    var body: some View {
        VStack(spacing: 0) {
            header
            addButton
            batchRow
            imageListSection
            Divider()
            footer
        }
        .background(.regularMaterial)
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(LinearGradient(colors: [p.accent, Color(hex: 0x5AC8FA)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 26, height: 26)
                .overlay { Image(systemName: "photo").foregroundStyle(.white).font(.system(size: 12, weight: .semibold)) }
            Text("WebPic").font(.system(size: 15, weight: .semibold))
            Spacer()
            Text(WebPicCore.version).font(.system(size: 11).monospacedDigit()).foregroundStyle(p.t3)
        }
        .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 12)
    }

    @ViewBuilder
    private var addButton: some View {
        Button { store.seedMockImages() } label: {
            Label("Bilder hinzufügen", systemImage: "plus")
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity).frame(height: 32)
        }
        .buttonStyle(.borderedProminent).tint(p.accent)
        .padding(.horizontal, 14).padding(.bottom, 12)
    }

    @ViewBuilder
    private var batchRow: some View {
        Button { store.tab = .batch } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.grid.2x2")
                Text("Alle Bilder").frame(maxWidth: .infinity, alignment: .leading)
                Text("\(store.images.count)")
                    .font(.system(size: 11).monospacedDigit())
                    .padding(.horizontal, 7).padding(.vertical, 1)
                    .background(p.seg, in: Capsule()).foregroundStyle(p.t2)
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(store.tab == .batch ? p.accent : p.t1)
            .padding(.vertical, 7).padding(.horizontal, 12)
            .background(store.tab == .batch ? p.accentTint : .clear,
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).padding(.horizontal, 10)
    }

    @ViewBuilder
    private var imageListSection: some View {
        Text("BILDER")
            .font(.system(size: 11, weight: .semibold)).foregroundStyle(p.t3)
            .kerning(0.4).frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 6)

        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(store.images) { img in
                    ImageRow(image: img,
                             isSelected: img.id == store.selectedID && store.tab != .batch,
                             onSelect: { store.select(id: img.id) },
                             onRemove: { store.remove(id: img.id) })
                }
            }
            .padding(.horizontal, 10).padding(.bottom, 10)
        }
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 9) {
            if store.showUpdate {
                Button { store.sheet = .update } label: {
                    HStack(spacing: 8) {
                        Circle().fill(p.accent).frame(width: 7, height: 7)
                        Text("Update 2.1 verfügbar")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(p.accent)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundStyle(p.accent)
                    }
                    .padding(.vertical, 7).padding(.horizontal, 9)
                    .background(p.accentTint, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 8) {
                Image(systemName: "sun.max").font(.system(size: 13)).foregroundStyle(p.t2)
                Picker("", selection: Binding(
                    get: { theme.appearance == .dark ? 1 : 0 },
                    set: { theme.appearance = $0 == 1 ? .dark : .light })) {
                    Text("Hell").tag(0)
                    Text("Dunkel").tag(1)
                }
                .pickerStyle(.segmented).labelsHidden()
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }
}
