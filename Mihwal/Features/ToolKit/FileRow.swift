import SwiftUI

struct FileRow: View {
    let file: ImportedFile
    let password: String?
    let onUnlock: () -> Void

    private var isLocked: Bool { file.isLocked && password == nil }

    var body: some View {
        HStack(spacing: DS.Spacing.s) {
            ThumbnailView(source: file.isPDF ? .pdfPage(file.url, index: 0) : .image(file.url),
                          password: password, maxPixelSize: 160)
                .frame(width: DS.Size.rowThumbnail, height: DS.Size.rowThumbnail * 1.3)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: DS.Spacing.xxs) {
                    Text(file.byteCount.formatted(.byteCount(style: .file)))
                    if let pages = file.pageCount {
                        Text(verbatim: "·")
                        Text("\(pages) pages")
                    }
                    if file.isImage, let size = ImageReader.pixelSize(at: file.url) {
                        Text(verbatim: "·")
                        Text(verbatim: "\(size.width) × \(size.height)")
                            .monospacedDigit()
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if isLocked {
                Button(action: onUnlock) {
                    Label("Enter password", systemImage: "lock.fill")
                        .labelStyle(.iconOnly)
                        .font(.body.weight(.semibold))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.borderless)
            } else if file.isLocked {
                Image(systemName: "lock.open.fill")
                    .foregroundStyle(.green)
                    .accessibilityLabel(Text("Unlocked"))
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
