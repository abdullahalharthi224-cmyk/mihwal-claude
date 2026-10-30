import SwiftUI

struct RotateImageView: View {
    @State private var model: RotateImageViewModel
    @ScaledMetric(relativeTo: .body) private var previewHeight: CGFloat = 220

    init(initialFiles: [ImportedFile]) {
        _model = State(initialValue: RotateImageViewModel(initialFiles: initialFiles))
    }

    var body: some View {
        ToolScreen(tool: ToolRegistry.tool(.rotateImage), files: model.files, runner: model.runner,
                   actionTitle: "Save Images", isReady: model.isReady,
                   footnote: model.options.hasChanges ? nil : "Rotate or flip to continue.",
                   onRun: { model.run() }) {
            if !model.files.files.isEmpty {
                Section {
                    previewView
                } header: {
                    Text("Preview")
                } footer: {
                    if model.files.files.count > 1 {
                        Text("The same change is applied to every photo.")
                    }
                }
            }

            Section {
                // Turning directions are physical, so this row keeps the same order in Arabic.
                HStack(spacing: DS.Spacing.s) {
                    transformButton("Rotate Counterclockwise", symbol: "rotate.left") { model.rotateCounterclockwise() }
                    transformButton("Rotate Clockwise", symbol: "rotate.right") { model.rotateClockwise() }
                }
                .environment(\.layoutDirection, .leftToRight)
                HStack(spacing: DS.Spacing.s) {
                    transformButton("Mirror", symbol: "arrow.left.and.right.righttriangle.left.righttriangle.right") {
                        model.flipHorizontal.toggle()
                    }
                    transformButton("Flip Upside Down", symbol: "arrow.up.and.down.righttriangle.up.righttriangle.down") {
                        model.flipVertical.toggle()
                    }
                }
                if model.options.hasChanges {
                    Button("Reset", role: .destructive) {
                        withAnimation(DS.Motion.standard) { model.reset() }
                    }
                }
            }

            LocationSection(removeLocation: $model.removeLocation)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: model.options)
        .task(id: model.previewKey) {
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
                .frame(height: previewHeight)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.s, style: .continuous))
                .id(model.previewKey)
                .transition(.opacity)
                .animation(DS.Motion.standard, value: model.previewKey)
                .padding(.vertical, DS.Spacing.xs)
                .accessibilityLabel(Text("Preview of the first photo as it will be saved"))
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: previewHeight)
        }
    }

    private func transformButton(_ title: LocalizedStringKey, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.subheadline)
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.bordered)
    }
}
