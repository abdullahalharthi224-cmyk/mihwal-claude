import SwiftUI

/// The watermark text and style controls, shared by the image and PDF watermark tools.
/// Put `text` sections before a preview and `style` sections after it.
struct WatermarkTextSection: View {
    @Binding var style: WatermarkStyle

    var body: some View {
            Section {
                TextField("Watermark text", text: $style.text, prompt: Text("© Your name"))
                    .submitLabel(.done)
                    .accessibilityIdentifier("watermark.text")
            } header: {
                Text("Text")
            } footer: {
                Text("Arabic and English can be mixed.")
            }

    }
}

struct WatermarkStyleSection: View {
    @Binding var style: WatermarkStyle

    var body: some View {
            Section {
                Picker("Size", selection: $style.size) {
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
                        Text(style.opacity, format: .percent.precision(.fractionLength(0)))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $style.opacity, in: 0.1...1, step: 0.05) {
                        Text("Opacity")
                    }
                }

                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    HStack {
                        Text("Angle")
                        Spacer()
                        Text(verbatim: "\(Int(style.angle))°")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $style.angle, in: -60...60, step: 15) {
                        Text("Angle")
                    }
                }

                Picker("Position", selection: $style.position) {
                    ForEach(WatermarkPosition.allCases, id: \.self) { position in
                        Label(position.title, systemImage: position.symbol).tag(position)
                    }
                }
            } header: {
                Text("Style")
            }

    }

    private var colorRow: some View {
        HStack(spacing: DS.Spacing.s) {
            Text("Color")
            Spacer()
            ForEach(WatermarkColor.allCases, id: \.self) { color in
                let isSelected = style.color == color
                Button {
                    style.color = color
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
