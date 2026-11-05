import SwiftUI

struct PDFToImagesView: View {
    @State private var model: PDFToImagesViewModel

    init(initialFiles: [ImportedFile]) {
        _model = State(initialValue: PDFToImagesViewModel(initialFiles: initialFiles))
    }

    var body: some View {
        ToolScreen(tool: ToolRegistry.tool(.pdfToImages), files: model.files, runner: model.runner,
                   actionTitle: "Save as Pictures", isReady: model.isReady,
                   layout: .scroll, onRun: { model.run() }) {
            if let file = model.file {
                OptionCard {
                    Picker("Format", selection: $model.options.format) {
                        Text(verbatim: "JPG").tag(ImageFormat.jpeg)
                        Text(verbatim: "PNG").tag(ImageFormat.png)
                    }
                    .pickerStyle(.segmented)
                    Picker("Resolution", selection: $model.options.resolution) {
                        Text("Screen").tag(PDFToImagesEngine.Resolution.screen)
                        Text("Standard").tag(PDFToImagesEngine.Resolution.standard)
                        Text("Print").tag(PDFToImagesEngine.Resolution.print)
                    }
                    .pickerStyle(.segmented)
                    if model.options.format == .jpeg {
                        QualitySlider(quality: $model.options.quality)
                    }
                    Text("Screen 72 dpi · Standard 150 dpi · Print 300 dpi. Tap pages to save only some of them.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Label {
                        Text("\(model.pictureCount) pictures")
                            .contentTransition(.numericText())
                    } icon: {
                        Image(systemName: "photo.on.rectangle")
                    }
                    .font(.subheadline.weight(.semibold))
                }

                if model.pageCount > 0 {
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
