import SwiftUI

struct TextToPDFView: View {
    @State private var model: TextToPDFViewModel
    @ScaledMetric(relativeTo: .body) private var editorHeight: CGFloat = 220

    init(initialFiles: [ImportedFile]) {
        _model = State(initialValue: TextToPDFViewModel(initialFiles: initialFiles))
    }

    var body: some View {
        ToolScreen(tool: ToolRegistry.tool(.textToPDF), files: model.files, runner: model.runner,
                   actionTitle: "Create PDF", isReady: model.isReady,
                   footnote: model.isReady ? nil : "Type or import some text first.",
                   showsOptionsWithoutFiles: true,
                   emptyImportHint: "Import a .txt file, or type or paste below.",
                   onRun: { model.run() }) {
            Section {
                TextEditor(text: $model.options.text)
                    .frame(minHeight: editorHeight)
                    .font(.system(size: CGFloat(model.options.fontSize)))
                    .accessibilityIdentifier("text.editor")
                    .accessibilityLabel(Text("Text"))
            } header: {
                Text("Text")
            } footer: {
                Text("\(model.options.text.count) characters")
            }

            Section {
                Picker("Page size", selection: $model.options.pageSize) {
                    Text(verbatim: "A4").tag(TextToPDFEngine.PageSize.a4)
                    Text(verbatim: "Letter").tag(TextToPDFEngine.PageSize.letter)
                }
                .pickerStyle(.segmented)
                Stepper(value: $model.options.fontSize, in: 9...32, step: 1) {
                    HStack {
                        Text("Text size")
                        Spacer()
                        Text(verbatim: "\(Int(model.options.fontSize)) pt")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                Picker("Margins", selection: $model.options.margin) {
                    Text("Narrow").tag(TextToPDFEngine.Margin.narrow)
                    Text("Normal").tag(TextToPDFEngine.Margin.normal)
                    Text("Wide").tag(TextToPDFEngine.Margin.wide)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Page")
            } footer: {
                Text("Each paragraph follows its first letter: Arabic paragraphs run right to left, English ones left to right. Text continues onto new pages automatically.")
            }
        }
        .onChange(of: model.files.files.first?.id) { _, _ in
            model.loadImportedText()
        }
    }
}
