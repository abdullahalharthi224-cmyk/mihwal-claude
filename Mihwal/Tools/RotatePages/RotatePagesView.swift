import SwiftUI

struct RotatePagesView: View {
    @State private var model: RotatePagesViewModel

    init(initialFiles: [ImportedFile]) {
        _model = State(initialValue: RotatePagesViewModel(initialFiles: initialFiles))
    }

    var body: some View {
        ToolScreen(tool: ToolRegistry.tool(.rotatePDF), files: model.files, runner: model.runner,
                   actionTitle: "Save Rotated PDF", isReady: model.isReady,
                   footnote: model.isReady ? nil : "Turn at least one page to save.",
                   layout: .scroll, onRun: { model.run() }) {
            if let file = model.file {
                if model.pageCount > 0 {
                    OptionCard {
                        Text(model.selection.isEmpty
                             ? LocalizedStringKey("Tap pages to choose them, or rotate all at once.")
                             : LocalizedStringKey("The buttons rotate the selected pages."))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        HStack(spacing: DS.Spacing.s) {
                            Button {
                                model.rotate(by: -90)
                            } label: {
                                Label("Rotate Left", systemImage: "rotate.left")
                                    .frame(maxWidth: .infinity)
                            }
                            Button {
                                model.rotate(by: 90)
                            } label: {
                                Label("Rotate Right", systemImage: "rotate.right")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        PageSelectionBar(selectedCount: model.selection.count, pageCount: model.pageCount,
                                         onSelectAll: { model.selection.selectAll(pageCount: model.pageCount) },
                                         onClear: { model.selection.clear() })
                    }
                    PageGrid(file: file, password: model.password, pageCount: model.pageCount,
                             isSelected: { model.selection.contains($0) },
                             rotation: { model.rotation(of: $0) },
                             onTap: { model.selection.toggle($0) })
                } else if file.isLocked {
                    LockedPagesView()
                }
            }
        }
        .sensoryFeedback(.selection, trigger: model.selection)
        .sensoryFeedback(.impact(weight: .light), trigger: model.rotations)
        .onChange(of: model.file?.id) { _, _ in model.resetForNewFile() }
    }
}
