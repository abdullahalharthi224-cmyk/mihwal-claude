import SwiftUI

struct CompressImageView: View {
    @State private var model: CompressImageViewModel

    init(initialFiles: [ImportedFile]) {
        _model = State(initialValue: CompressImageViewModel(initialFiles: initialFiles))
    }

    var body: some View {
        ToolScreen(tool: ToolRegistry.tool(.compressImage), files: model.files, runner: model.runner,
                   actionTitle: "Compress Images", isReady: model.isReady, onRun: { model.run() }) {
            Section {
                Picker("Quality", selection: $model.options.quality) {
                    Text("High").tag(0.85)
                    Text("Balanced").tag(0.7)
                    Text("Small").tag(0.5)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Quality")
            } footer: {
                Text("Balanced is hard to tell apart from the original on a phone screen.")
            }

            Section {
                Picker("Format", selection: $model.options.format) {
                    ForEach(model.formats, id: \.self) { format in
                        switch format {
                        case .jpeg: Text(verbatim: "JPG").tag(format)
                        case .heic: Text(verbatim: "HEIC").tag(format)
                        case .original: Text("Keep").tag(format)
                        }
                    }
                }
                .pickerStyle(.segmented)

                Picker("Maximum size", selection: $model.options.maxPixelSize) {
                    Text("Original size").tag(Int?.none)
                    ForEach([4096, 2048, 1280], id: \.self) { side in
                        Text(verbatim: "\(side) px").tag(Int?.some(side))
                    }
                }
            } header: {
                Text("Format and size")
            } footer: {
                Text("PNG files only get smaller when they are converted or made smaller.")
            }

            LocationSection(removeLocation: $model.options.removeLocation)
        }
    }
}
