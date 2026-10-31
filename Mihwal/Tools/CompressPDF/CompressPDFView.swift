import SwiftUI

struct CompressPDFView: View {
    @State private var model: CompressPDFViewModel

    init(initialFiles: [ImportedFile]) {
        _model = State(initialValue: CompressPDFViewModel(initialFiles: initialFiles))
    }

    var body: some View {
        ToolScreen(tool: ToolRegistry.tool(.compressPDF), files: model.files, runner: model.runner,
                   actionTitle: "Compress PDF", isReady: model.isReady, onRun: { model.run() }) {
            Section {
                levelRow(.balanced, title: "Balanced",
                         detail: "Shrinks the pictures inside. Text stays sharp, selectable and searchable.",
                         symbol: "text.viewfinder")
                levelRow(.strong, title: "Strong",
                         detail: "Turns every page into a picture. Much smaller for scans, but text can no longer be selected or searched.",
                         symbol: "photo")
            } header: {
                Text("Level")
            } footer: {
                Text("You'll see the size before and after. If the PDF can't get smaller, your original is kept.")
            }
        }
    }

    private func levelRow(_ level: CompressPDFEngine.Level, title: LocalizedStringKey,
                          detail: LocalizedStringKey, symbol: String) -> some View {
        let isSelected = model.options.level == level
        return Button {
            model.options.level = level
        } label: {
            HStack(alignment: .top, spacing: DS.Spacing.s) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
