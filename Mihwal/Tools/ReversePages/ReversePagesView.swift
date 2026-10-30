import SwiftUI

struct ReversePagesView: View {
    @State private var model: ReversePagesViewModel

    init(initialFiles: [ImportedFile]) {
        _model = State(initialValue: ReversePagesViewModel(initialFiles: initialFiles))
    }

    var body: some View {
        ToolScreen(tool: descriptor, files: model.files, runner: model.runner,
                   actionTitle: "Reverse Pages", isReady: model.isReady,
                   footnote: model.pageCount == 1 ? "This PDF has only one page." : nil,
                   onRun: { model.run() }) {
            if let count = model.pageCount, count > 1 {
                Section {
                    Label {
                        Text("Page \(count) will become page 1.")
                    } icon: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
        }
    }

    private var descriptor: ToolDescriptor {
        ToolRegistry.descriptor(for: .reversePages) ?? ToolRegistry.all[0]
    }
}
