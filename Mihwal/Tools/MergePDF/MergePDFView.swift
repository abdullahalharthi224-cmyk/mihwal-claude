import SwiftUI

struct MergePDFView: View {
    @State private var model: MergePDFViewModel
    @State private var dropTarget: UUID?

    init(initialFiles: [ImportedFile]) {
        _model = State(initialValue: MergePDFViewModel(initialFiles: initialFiles))
    }

    var body: some View {
        ToolScreen(tool: ToolRegistry.tool(.merge), files: model.files, runner: model.runner,
                   actionTitle: "Merge PDFs", isReady: model.isReady,
                   footnote: model.isReady ? nil : "Add at least two PDFs to merge.",
                   layout: .scroll, onRun: { model.run() }) {
            OptionCard {
                Label("Drag the files to change their order.", systemImage: "hand.draw")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack(spacing: DS.Spacing.xxs) {
                    Text("\(model.files.files.count) files")
                    if let pages = model.totalPages {
                        Text(verbatim: "·")
                        Text("\(pages) pages")
                    }
                }
                .font(.subheadline.weight(.semibold))
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: DS.Spacing.s)],
                      spacing: DS.Spacing.s) {
                ForEach(Array(model.files.files.enumerated()), id: \.element.id) { index, file in
                    MergeFileCell(file: file, position: index + 1,
                                  password: model.files.input.password(for: file),
                                  isDropTarget: dropTarget == file.id)
                        .draggable(file.id.uuidString)
                        .dropDestination(for: String.self) { items, _ in
                            guard let raw = items.first, let id = UUID(uuidString: raw), id != file.id else {
                                return false
                            }
                            withAnimation(DS.Motion.standard) {
                                model.files.move(id, toIndex: index)
                            }
                            return true
                        } isTargeted: { targeted in
                            if targeted {
                                dropTarget = file.id
                            } else if dropTarget == file.id {
                                dropTarget = nil
                            }
                        }
                        .contextMenu {
                            Button {
                                withAnimation(DS.Motion.standard) { model.files.move(file.id, toIndex: 0) }
                            } label: {
                                Label("Move to Start", systemImage: "arrow.up.to.line")
                            }
                            Button {
                                withAnimation(DS.Motion.standard) {
                                    model.files.move(file.id, toIndex: model.files.files.count - 1)
                                }
                            } label: {
                                Label("Move to End", systemImage: "arrow.down.to.line")
                            }
                            Button(role: .destructive) {
                                withAnimation(DS.Motion.standard) { model.files.remove(file) }
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                        .accessibilityAction(named: Text("Move Earlier")) { model.moveEarlier(file) }
                        .accessibilityAction(named: Text("Move Later")) { model.moveLater(file) }
                        .accessibilityAction(named: Text("Remove")) { model.files.remove(file) }
                }
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: model.files.files.map(\.id))
    }
}

private struct MergeFileCell: View {
    let file: ImportedFile
    let position: Int
    let password: String?
    let isDropTarget: Bool

    @ScaledMetric(relativeTo: .body) private var thumbnailHeight: CGFloat = 150
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous) }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            ThumbnailView(source: .pdfPage(file.url, index: 0), password: password, maxPixelSize: 360)
                .frame(maxWidth: .infinity)
                .frame(height: thumbnailHeight)
                .overlay(alignment: .topLeading) {
                    Text(position, format: .number)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 24, minHeight: 24)
                        .background(Circle().fill(Color.accentColor))
                }
            Text(file.name)
                .font(.caption.weight(.medium))
                .lineLimit(2)
                .truncationMode(.middle)
            Group {
                if let pages = file.pageCount {
                    Text("\(pages) pages")
                } else if file.isLocked {
                    Label("Locked", systemImage: "lock.fill")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(DS.Spacing.s)
        .background(DS.Palette.card, in: shape)
        .overlay(shape.strokeBorder(isDropTarget ? Color.accentColor : Color.clear, lineWidth: 2.5))
        .scaleEffect(isDropTarget ? 1.03 : 1)
        .animation(DS.Motion.press, value: isDropTarget)
        .contentShape(shape)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("File \(position): \(file.name)"))
    }
}
