import SwiftUI

struct PDFToTextView: View {
    @State private var model: PDFToTextViewModel

    init(initialFiles: [ImportedFile]) {
        _model = State(initialValue: PDFToTextViewModel(initialFiles: initialFiles))
    }

    var body: some View {
        ToolScreen(tool: ToolRegistry.tool(.pdfToText), files: model.files, runner: model.runner,
                   actionTitle: "Get Text", isReady: model.isReady, onRun: { model.run() }) {
            Section {
                Toggle("Page separators", isOn: $model.options.pageSeparators)
                Toggle("Read every page with OCR", isOn: $model.options.forceOCR)
            } footer: {
                Text("Text is copied from the PDF itself. Pages without text (scans, photos) are read from the page image (OCR, Arabic and English); the result tells you which pages.")
            }
        }
    }
}
