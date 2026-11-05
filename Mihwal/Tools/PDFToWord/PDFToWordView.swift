import SwiftUI

struct PDFToWordView: View {
    @State private var model: PDFToWordViewModel

    init(initialFiles: [ImportedFile]) {
        _model = State(initialValue: PDFToWordViewModel(initialFiles: initialFiles))
    }

    var body: some View {
        ToolScreen(tool: ToolRegistry.tool(.pdfToWord), files: model.files, runner: model.runner,
                   actionTitle: "Convert to Word", isReady: model.isReady, onRun: { model.run() }) {
            Section {
                Label {
                    Text("You get an editable Word document (.docx) with the text. Arabic paragraphs are right-to-left. Layout, pictures and tables are not copied.")
                } icon: {
                    Image(systemName: "doc.richtext")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }
}
