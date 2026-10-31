import SwiftUI

struct UnlockPDFView: View {
    @State private var model: UnlockPDFViewModel

    init(initialFiles: [ImportedFile]) {
        _model = State(initialValue: UnlockPDFViewModel(initialFiles: initialFiles))
    }

    var body: some View {
        ToolScreen(tool: ToolRegistry.tool(.removeRestrictions), files: model.files, runner: model.runner,
                   actionTitle: "Remove Protection", isReady: model.isReady,
                   footnote: model.file != nil && !model.isReady ? "This PDF isn't protected." : nil,
                   onRun: { model.run() }) {
            if let protection = model.protection {
                Section {
                    if protection.needsPasswordToOpen {
                        Label("Needs a password to open", systemImage: "lock.fill")
                    }
                    ForEach(Array(protection.blocked.enumerated()), id: \.offset) { _, item in
                        Label {
                            Text(item)
                        } icon: {
                            Image(systemName: "nosign")
                                .foregroundStyle(.red)
                        }
                    }
                } header: {
                    Text("Protection")
                }
            }
            Section {
                Label {
                    Text("Mihwal only removes protection with the correct password. You'll be asked for it when you continue. Passwords are never guessed or bypassed.")
                } icon: {
                    Image(systemName: "key.fill")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }
}
