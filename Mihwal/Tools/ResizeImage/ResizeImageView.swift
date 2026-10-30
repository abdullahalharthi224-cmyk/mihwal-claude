import SwiftUI

struct ResizeImageView: View {
    @State private var model: ResizeImageViewModel

    init(initialFiles: [ImportedFile]) {
        _model = State(initialValue: ResizeImageViewModel(initialFiles: initialFiles))
    }

    var body: some View {
        ToolScreen(tool: ToolRegistry.tool(.resizeImage), files: model.files, runner: model.runner,
                   actionTitle: "Resize Images", isReady: model.isReady, onRun: { model.run() }) {
            Section {
                Picker("Resize by", selection: $model.modeKind) {
                    Text("Percentage").tag(ResizeImageViewModel.ModeKind.percent)
                    Text("Longest side").tag(ResizeImageViewModel.ModeKind.longestSide)
                }
                .pickerStyle(.segmented)

                switch model.modeKind {
                case .percent:
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        HStack {
                            Text("New size")
                            Spacer()
                            Text(Double(model.percent) / 100, format: .percent)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: percentBinding, in: 10...100, step: 5) {
                            Text("New size")
                        }
                    }
                case .longestSide:
                    Picker("Longest side", selection: $model.longestSide) {
                        ForEach(ResizeImageViewModel.sidePresets, id: \.self) { side in
                            Text(verbatim: "\(side) px").tag(side)
                        }
                    }
                }
            } footer: {
                Text("The shape of the photo is always kept, and photos are never enlarged.")
            }

            if let preview = model.firstImagePreview {
                Section {
                    HStack {
                        Text(verbatim: preview.before)
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.forward")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text(verbatim: preview.after)
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline.monospacedDigit())
                } header: {
                    Text("First photo")
                }
            }

            LocationSection(removeLocation: $model.removeLocation)
        }
    }

    private var percentBinding: Binding<Double> {
        Binding(get: { Double(model.percent) }, set: { model.percent = Int($0.rounded()) })
    }
}
