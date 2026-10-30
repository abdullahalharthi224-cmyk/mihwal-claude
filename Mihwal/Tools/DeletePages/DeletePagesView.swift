import SwiftUI

struct DeletePagesView: View {
    @State private var model: DeletePagesViewModel

    init(initialFiles: [ImportedFile]) {
        _model = State(initialValue: DeletePagesViewModel(initialFiles: initialFiles))
    }

    var body: some View {
        ToolScreen(tool: ToolRegistry.tool(.deletePages), files: model.files, runner: model.runner,
                   actionTitle: "Delete Selected Pages", isReady: model.isReady,
                   footnote: footnote, layout: .scroll, onRun: { model.run() }) {
            if let file = model.file {
                if model.pageCount > 0 {
                    OptionCard {
                        Text("Tap the pages you want to remove.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        PageSelectionBar(selectedCount: model.selection.count, pageCount: model.pageCount,
                                         onSelectAll: { model.selection.selectAll(pageCount: model.pageCount) },
                                         onClear: { model.selection.clear() })
                    }
                    PageGrid(file: file, password: model.password, pageCount: model.pageCount,
                             isSelected: { model.selection.contains($0) },
                             mark: .delete,
                             onTap: { model.selection.toggle($0) })
                } else if file.isLocked {
                    LockedPagesView()
                }
            }
        }
        .sensoryFeedback(.selection, trigger: model.selection)
        .onChange(of: model.file?.id) { _, _ in model.selection.clear() }
    }

    private var footnote: LocalizedStringResource? {
        if model.deletesEverything {
            return "Keep at least one page."
        }
        return nil
    }
}
