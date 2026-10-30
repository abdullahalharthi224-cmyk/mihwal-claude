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
            Section {
                TextField("Watermark text", text: $model.options.style.text, prompt: Text("© Your name"))
                    .submitLabel(.done)
            } header: {
                Text("Text")
            } footer: {
                Text("Arabic and English can be mixed.")
            }

            Section {
                previewView
            } header: {
                Text("Preview")
            }

            Section {
                Picker("Size", selection: $model.options.style.size) {
                    Text("Small").tag(WatermarkSize.small)
                    Text("Medium").tag(WatermarkSize.medium)
                    Text("Large").tag(WatermarkSize.large)
                }
                .pickerStyle(.segmented)

                colorRow

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack {
                        Text("Opacity")
                        Spacer()
                        Text(model.options.style.opacity, format: .percent.precision(.fractionLength(0)))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $model.options.style.opacity, in: 0.1...1, step: 0.05) {
                        Text("Opacity")
                    }
                }

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack {
                        Text("Angle")
                        Spacer()
                        Text(verbatim: "\(Int(model.options.style.angle))°")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $model.options.style.angle, in: -60...60, step: 15) {
                        Text("Angle")
                    }
                }

                Picker("Position", selection: $model.options.style.position) {
                    ForEach(WatermarkPosition.allCases, id: \.self) { position in
                        Label(position.title, systemImage: position.symbol).tag(position)
                    }
                }
            } header: {
                Text("Style")
            }

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

    private var colorRow: some View {
        HStack(spacing: DS.Spacing.s) {
            Text("Color")
            Spacer()
            ForEach(WatermarkColor.allCases, id: \.self) { color in
                let isSelected = model.options.style.color == color
                Button {
                    model.options.style.color = color
                } label: {
                    Circle()
                        .fill(color.swatch)
                        .frame(width: 28, height: 28)
                        .overlay(Circle().strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1))
                        .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: isSelected ? 3 : 0).padding(-4))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text(color.title))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

private extension WatermarkColor {
    var swatch: Color {
        let c = components
        return Color(red: Double(c.red), green: Double(c.green), blue: Double(c.blue))
    }

    var title: LocalizedStringKey {
        switch self {
        case .white: return "White"
        case .black: return "Black"
        case .red: return "Red"
        case .yellow: return "Yellow"
        case .blue: return "Blue"
        }
    }
}

private extension WatermarkPosition {
    var title: LocalizedStringKey {
        switch self {
        case .center: return "Center"
        case .topLeft: return "Top left"
        case .topRight: return "Top right"
        case .bottomLeft: return "Bottom left"
        case .bottomRight: return "Bottom right"
        case .tiled: return "Repeat across"
        }
    }

    var symbol: String {
        switch self {
        case .center: return "square.dashed.inset.filled"
        case .topLeft: return "arrow.up.left"
        case .topRight: return "arrow.up.right"
        case .bottomLeft: return "arrow.down.left"
        case .bottomRight: return "arrow.down.right"
        case .tiled: return "square.grid.3x3"
        }
    }
}
