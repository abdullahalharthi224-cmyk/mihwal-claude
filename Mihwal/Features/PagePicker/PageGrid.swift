import SwiftUI

enum PageMark {
    /// Selected pages get a checkmark (extract, rotate).
    case check
    /// Selected pages are dimmed with a red trash mark (delete).
    case delete
}

/// A lazily loaded grid of a PDF's pages. Only visible thumbnails are rendered,
/// so a 500-page PDF scrolls without loading 500 images.
struct PageGrid<Overlay: View>: View {
    let file: ImportedFile
    let password: String?
    let pageCount: Int
    let isSelected: (Int) -> Bool
    let rotation: (Int) -> Int
    let mark: PageMark
    let onTap: (Int) -> Void
    let overlay: (Int) -> Overlay

    @ScaledMetric(relativeTo: .body) private var cellWidth: CGFloat = 96

    init(file: ImportedFile, password: String?, pageCount: Int,
         isSelected: @escaping (Int) -> Bool,
         rotation: @escaping (Int) -> Int = { _ in 0 },
         mark: PageMark = .check,
         onTap: @escaping (Int) -> Void,
         @ViewBuilder overlay: @escaping (Int) -> Overlay) {
        self.file = file
        self.password = password
        self.pageCount = pageCount
        self.isSelected = isSelected
        self.rotation = rotation
        self.mark = mark
        self.onTap = onTap
        self.overlay = overlay
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: cellWidth), spacing: DS.Spacing.s)],
                  spacing: DS.Spacing.m) {
            ForEach(0..<pageCount, id: \.self) { index in
                let selected = isSelected(index)
                PageCell(url: file.url, index: index, password: password,
                         rotation: rotation(index), isSelected: selected, mark: mark)
                    .overlay(alignment: .topLeading) { overlay(index) }
                    .contentShape(Rectangle())
                    .onTapGesture { onTap(index) }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("Page \(index + 1)"))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}

extension PageGrid where Overlay == EmptyView {
    init(file: ImportedFile, password: String?, pageCount: Int,
         isSelected: @escaping (Int) -> Bool,
         rotation: @escaping (Int) -> Int = { _ in 0 },
         mark: PageMark = .check,
         onTap: @escaping (Int) -> Void) {
        self.init(file: file, password: password, pageCount: pageCount, isSelected: isSelected,
                  rotation: rotation, mark: mark, onTap: onTap) { _ in EmptyView() }
    }
}

private struct PageCell: View {
    let url: URL
    let index: Int
    let password: String?
    let rotation: Int
    let isSelected: Bool
    let mark: PageMark

    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 124

    private var tint: Color { mark == .delete ? .red : .accentColor }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous) }

    var body: some View {
        VStack(spacing: DS.Spacing.xxs) {
            ThumbnailView(source: .pdfPage(url, index: index), password: password, maxPixelSize: 320)
                .rotationEffect(.degrees(Double(rotation)))
                // A sideways page must still fit inside the cell.
                .scaleEffect(rotation % 180 == 0 ? 1 : 0.72)
                .animation(DS.Motion.standard, value: rotation)
                .opacity(mark == .delete && isSelected ? 0.45 : 1)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .padding(DS.Spacing.xs)
                .background(shape.fill(isSelected ? tint.opacity(0.12) : Color.clear))
                .overlay(shape.strokeBorder(isSelected ? tint : Color.clear, lineWidth: 2.5))
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: mark == .delete ? "trash.circle.fill" : "checkmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, tint)
                            .padding(DS.Spacing.xxs)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(DS.Motion.press, value: isSelected)

            Text(index + 1, format: .number)
                .font(.caption.monospacedDigit().weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(.secondary))
        }
    }
}

/// "3 selected · Select All" bar above a page grid.
struct PageSelectionBar: View {
    let selectedCount: Int
    let pageCount: Int
    let onSelectAll: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack {
            Text("\(selectedCount) selected")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
            Spacer()
            if selectedCount == pageCount && pageCount > 0 {
                Button("Deselect All", action: onClear)
            } else {
                Button("Select All", action: onSelectAll)
            }
        }
        .font(.subheadline)
    }
}

/// Shown instead of the page grid while a protected PDF is still locked.
struct LockedPagesView: View {
    var body: some View {
        OptionCard {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("This PDF is protected")
                        .font(.headline)
                    Text("Tap the lock above and enter its password to see the pages.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
