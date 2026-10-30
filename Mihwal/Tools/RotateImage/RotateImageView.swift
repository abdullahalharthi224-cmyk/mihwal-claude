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
            if let first = model.files.files.first {
                Section {
                    // Same order as the engine: flip first, then rotate.
                    ThumbnailView(source: .image(first.url), maxPixelSize: 600)
                        .scaleEffect(x: model.flipHorizontal ? -1 : 1, y: model.flipVertical ? -1 : 1)
                        .rotationEffect(.degrees(Double(model.rotationSteps) * 90))
                        .animation(DS.Motion.standard, value: model.rotationSteps)
                        .animation(DS.Motion.standard, value: model.flipHorizontal)
                        .animation(DS.Motion.standard, value: model.flipVertical)
                        .frame(maxWidth: .infinity)
                        .frame(height: previewHeight)
                        .padding(.vertical, DS.Spacing.s)
                } header: {
                    Text("Preview")
                } footer: {
                    if model.files.files.count > 1 {
                        Text("The same change is applied to every photo.")
                    }
                }
            }

            Section {
                HStack(spacing: DS.Spacing.s) {
                    transformButton("Rotate Left", symbol: "rotate.left") { model.rotateLeft() }
                    transformButton("Rotate Right", symbol: "rotate.right") { model.rotateRight() }
                }
                HStack(spacing: DS.Spacing.s) {
                    transformButton("Flip Horizontal", symbol: "arrow.left.and.right.righttriangle.left.righttriangle.right") {
                        model.flipHorizontal.toggle()
                    }
                    transformButton("Flip Vertical", symbol: "arrow.up.and.down.righttriangle.up.righttriangle.down") {
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
