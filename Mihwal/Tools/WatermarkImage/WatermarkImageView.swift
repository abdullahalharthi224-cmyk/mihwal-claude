import SwiftUI

struct WatermarkImageView: View {
    @State private var model: WatermarkImageViewModel
    @ScaledMetric(relativeTo: .body) private var previewHeight: CGFloat = 240

    init(initialFiles: [ImportedFile]) {
        _model = State(initialValue: WatermarkImageViewModel(initialFiles: initialFiles))
    }

    var body: some View {
        ToolScreen(tool: ToolRegistry.tool(.watermarkImage), files: model.files, runner: model.runner,
                   actionTitle: "Add Watermark", isReady: model.isReady,
                   footnote: model.options.style.trimmedText.isEmpty ? "Type the watermark text first." : nil,
                   onRun: { model.run() }) {
            WatermarkTextSection(style: $model.options.style)

            Section {
                previewView
            } header: {
                Text("Preview")
            }

            WatermarkStyleSection(style: $model.options.style)

            LocationSection(removeLocation: $model.options.removeLocation)
        }
        .task(id: model.previewKey) {
            // Wait for typing to pause so the preview isn't redrawn on every letter.
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            await model.refreshPreview()
        }
    }

    @ViewBuilder
    private var previewView: some View {
        if let preview = model.preview {
            Image(decorative: preview, scale: 1)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(maxHeight: previewHeight)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous))
                .accessibilityLabel(Text("Preview of the first photo with the watermark"))
        } else {
            Text("Add a photo and type your text to see a preview.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 80)
        }
    }
}
