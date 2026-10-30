import SwiftUI

struct ExtractPagesView: View {
    @State private var model: ExtractPagesViewModel

    init(initialFiles: [ImportedFile]) {
        _model = State(initialValue: ExtractPagesViewModel(initialFiles: initialFiles))
    }

    var body: some View {
        ToolScreen(tool: ToolRegistry.tool(.extractPages), files: model.files, runner: model.runner,
                   actionTitle: "Extract Selected Pages", isReady: model.isReady,
                   layout: .scroll, onRun: { model.run() }) {
            if let file = model.file {
                if model.pageCount > 0 {
                    OptionCard {
                        Text("Tap the pages to copy into a new PDF.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        PageSelectionBar(selectedCount: model.selection.count, pageCount: model.pageCount,
                                         onSelectAll: { model.selection.selectAll(pageCount: model.pageCount) },
                                         onClear: { model.selection.clear() })
                    }
                    PageGrid(file: file, password: model.password, pageCount: model.pageCount,
                             isSelected: { model.selection.contains($0) },
                             onTap: { model.selection.toggle($0) })
                } else if file.isLocked {
                    LockedPagesView()
                }
            }
        }
        .sensoryFeedback(.selection, trigger: model.selection)
        .onChange(of: model.file?.id) { _, _ in model.selection.clear() }
    }
}
