import SwiftUI

struct PageNumbersView: View {
    @State private var model: PageNumbersViewModel

    init(initialFiles: [ImportedFile]) {
        _model = State(initialValue: PageNumbersViewModel(initialFiles: initialFiles))
    }

    var body: some View {
        ToolScreen(tool: ToolRegistry.tool(.pageNumbers), files: model.files, runner: model.runner,
                   actionTitle: "Add Page Numbers", isReady: model.isReady, onRun: { model.run() }) {
            PDFPreviewSection(preview: model.preview, isLocked: model.isLocked,
                              hasInteractiveContent: model.hasInteractiveContent)

            Section {
                Picker("Style", selection: $model.options.format) {
                    ForEach(PageNumbersEngine.Format.allCases, id: \.self) { format in
                        Text(verbatim: example(format)).tag(format)
                    }
                }
                Toggle("Arabic-Indic digits (١٢٣)", isOn: $model.options.arabicDigits)
                    .disabled(model.options.format == .pageOfTotalEnglish || model.options.format == .pageOfTotalArabic)
            } header: {
                Text("Format")
            }

            Section {
                Picker("Position", selection: $model.options.position) {
                    ForEach(PageNumbersEngine.Position.allCases, id: \.self) { position in
                        Text(title(position)).tag(position)
                    }
                }
                Picker("Size", selection: $model.options.size) {
                    Text("Small").tag(PageNumbersEngine.Size.small)
                    Text("Medium").tag(PageNumbersEngine.Size.medium)
                    Text("Large").tag(PageNumbersEngine.Size.large)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Placement")
            }

            Section {
                Stepper(value: $model.options.startNumber, in: 1...9999) {
                    HStack {
                        Text("Start at")
                        Spacer()
                        Text(model.options.startNumber, format: .number)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                Toggle("Skip the first page (cover)", isOn: $model.options.skipFirstPage)
            } header: {
                Text("Numbering")
            }
        }
        .task(id: model.previewKey) {
            await model.refreshPreview()
        }
    }

    private func example(_ format: PageNumbersEngine.Format) -> String {
        var sample = model.options
        sample.format = format
        sample.skipFirstPage = false
        sample.startNumber = 1
        return PageNumbersEngine.label(forPage: 0, pageCount: 10, options: sample) ?? ""
    }

    private func title(_ position: PageNumbersEngine.Position) -> LocalizedStringKey {
        switch position {
        case .bottomCenter: return "Bottom center"
        case .bottomLeft: return "Bottom left"
        case .bottomRight: return "Bottom right"
        case .topCenter: return "Top center"
        case .topLeft: return "Top left"
        case .topRight: return "Top right"
        }
    }
}
