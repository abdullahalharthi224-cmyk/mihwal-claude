import SwiftUI

struct WatermarkPDFView: View {
    @State private var model: WatermarkPDFViewModel

    init(initialFiles: [ImportedFile]) {
        _model = State(initialValue: WatermarkPDFViewModel(initialFiles: initialFiles))
    }

    var body: some View {
        ToolScreen(tool: ToolRegistry.tool(.watermarkPDF), files: model.files, runner: model.runner,
                   actionTitle: "Add Watermark", isReady: model.isReady,
                   footnote: model.options.style.trimmedText.isEmpty ? "Type the watermark text first." : nil,
                   onRun: { model.run() }) {
            WatermarkTextSection(style: $model.options.style)
            PDFPreviewSection(preview: model.preview, isLocked: model.isLocked,
                              hasInteractiveContent: model.hasInteractiveContent)
            WatermarkStyleSection(style: $model.options.style)
            Section {
                Text("A watermark is a visual mark, not a security feature: PDF editors can remove it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: model.previewKey) {
            // Wait for typing to pause so the preview isn't redrawn on every letter.
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            await model.refreshPreview()
        }
    }
}
