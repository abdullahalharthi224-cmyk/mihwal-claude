import SwiftUI

struct StripMetadataView: View {
    @State private var model: StripMetadataViewModel

    init(initialFiles: [ImportedFile]) {
        _model = State(initialValue: StripMetadataViewModel(initialFiles: initialFiles))
    }

    var body: some View {
        ToolScreen(tool: ToolRegistry.tool(.stripMetadata), files: model.files, runner: model.runner,
                   actionTitle: "Remove Metadata", isReady: model.isReady, onRun: { model.run() }) {
            if let report = model.report {
                Section {
                    if report.fields.isEmpty && !report.hasXMP {
                        Label("No metadata found in this PDF.", systemImage: "checkmark.seal")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(report.fields, id: \.field) { item in
                        LabeledContent {
                            Text(verbatim: item.value)
                                .lineLimit(2)
                                .multilineTextAlignment(.trailing)
                        } label: {
                            Text(item.field.title)
                        }
                    }
                    if report.hasXMP {
                        LabeledContent {
                            Image(systemName: "checkmark")
                        } label: {
                            Text("Extra hidden metadata (XMP)")
                        }
                    }
                } header: {
                    Text("Found in this PDF")
                } footer: {
                    Text("All of this is removed. The pages themselves don't change.")
                }
            } else if model.file?.isLocked == true {
                Section {
                    Label("Enter the password to see the metadata.", systemImage: "lock.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
