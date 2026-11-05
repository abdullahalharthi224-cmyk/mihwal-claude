import SwiftUI

struct ImagesToPDFView: View {
    @State private var model: ImagesToPDFViewModel
    @State private var dropTarget: UUID?

    init(initialFiles: [ImportedFile]) {
        _model = State(initialValue: ImagesToPDFViewModel(initialFiles: initialFiles))
    }

    var body: some View {
        ToolScreen(tool: ToolRegistry.tool(.imagesToPDF), files: model.files, runner: model.runner,
                   actionTitle: "Create PDF", isReady: model.isReady,
                   layout: .scroll, onRun: { model.run() }) {
            OptionCard {
                Picker("Page size", selection: $model.options.pageSize) {
                    Text("Fit photo").tag(ImagesToPDFEngine.PageSize.fitImage)
                    Text(verbatim: "A4").tag(ImagesToPDFEngine.PageSize.a4)
                    Text(verbatim: "Letter").tag(ImagesToPDFEngine.PageSize.letter)
                }
                .pickerStyle(.segmented)
                Picker("Margins", selection: $model.options.margin) {
                    Text("None").tag(ImagesToPDFEngine.Margin.none)
                    Text("Small").tag(ImagesToPDFEngine.Margin.small)
                    Text("Large").tag(ImagesToPDFEngine.Margin.large)
                }
                .pickerStyle(.segmented)
                Label("One photo per page. Drag photos to change the order.", systemImage: "hand.draw")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: DS.Spacing.s)], spacing: DS.Spacing.s) {
                ForEach(Array(model.files.files.enumerated()), id: \.element.id) { index, file in
                    ImagePageCell(file: file, position: index + 1, isDropTarget: dropTarget == file.id)
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
                        .accessibilityAction(named: Text("Move Earlier")) { model.move(file, by: -1) }
                        .accessibilityAction(named: Text("Move Later")) { model.move(file, by: 1) }
                        .accessibilityAction(named: Text("Remove")) { model.files.remove(file) }
                }
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: model.files.files.map(\.id))
    }
}

private struct ImagePageCell: View {
    let file: ImportedFile
    let position: Int
    let isDropTarget: Bool

    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 130
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous) }

    var body: some View {
        ThumbnailView(source: .image(file.url), maxPixelSize: 320)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .padding(DS.Spacing.xs)
            .overlay(alignment: .topLeading) {
                Text(position, format: .number)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 24, minHeight: 24)
                    .background(Circle().fill(Color.accentColor))
                    .padding(DS.Spacing.xxs)
            }
            .background(DS.Palette.card, in: shape)
            .overlay(shape.strokeBorder(isDropTarget ? Color.accentColor : Color.clear, lineWidth: 2.5))
            .scaleEffect(isDropTarget ? 1.04 : 1)
            .animation(DS.Motion.press, value: isDropTarget)
            .contentShape(shape)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Page \(position): \(file.name)"))
    }
}
