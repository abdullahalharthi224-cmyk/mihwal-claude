import SwiftUI

/// Lazily loads a page or image preview. Loading starts when the view appears and is
/// cancelled when it scrolls away, so long lists stay light on memory.
struct ThumbnailView: View {
    enum Source: Hashable {
        case pdfPage(URL, index: Int)
        case image(URL)
    }

    let source: Source
    var password: String? = nil
    var maxPixelSize: CGFloat = 240

    @State private var image: UIImage?
    @State private var didFail = false

    private struct LoadKey: Hashable {
        let source: Source
        let password: String?
    }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                    .transition(.opacity)
            } else {
                RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous)
                    .fill(.quaternary)
                    .overlay {
                        if didFail {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
            }
        }
        .task(id: LoadKey(source: source, password: password)) {
            await load()
        }
        .accessibilityHidden(true)
    }

    private func load() async {
        let loaded: UIImage?
        switch source {
        case let .pdfPage(url, index):
            loaded = await ThumbnailProvider.shared.pdfPage(url, index: index, maxPixelSize: maxPixelSize, password: password)
        case let .image(url):
            loaded = await ThumbnailProvider.shared.image(url, maxPixelSize: maxPixelSize)
        }
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            image = loaded
            didFail = loaded == nil
        }
    }
}
