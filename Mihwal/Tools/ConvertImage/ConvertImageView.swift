import SwiftUI

struct ConvertImageView: View {
    @State private var model: ConvertImageViewModel

    init(initialFiles: [ImportedFile]) {
        _model = State(initialValue: ConvertImageViewModel(initialFiles: initialFiles))
    }

    var body: some View {
        ToolScreen(tool: ToolRegistry.tool(.convertImage), files: model.files, runner: model.runner,
                   actionTitle: "Convert Images", isReady: model.isReady, onRun: { model.run() }) {
            Section {
                Picker("Format", selection: $model.options.format) {
                    ForEach(ImageFormat.exportable) { format in
                        Text(verbatim: format.displayName).tag(format)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Convert to")
            } footer: {
                if !ImageFormat.heic.canEncode {
                    Text("HEIC can't be created on this device.")
                } else if model.options.format == .heic {
                    Text("HEIC is about half the size of JPG. Some Windows apps can't open it.")
                }
            }

            if model.options.format.isLossy {
                Section {
                    QualitySlider(quality: $model.options.quality)
                }
            }

            LocationSection(removeLocation: $model.options.removeLocation)
        }
    }
}
