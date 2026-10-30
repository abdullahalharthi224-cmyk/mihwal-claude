import PhotosUI
import SwiftUI

/// The shared layout of every tool:
/// empty state with import buttons → file list + options → big action button →
/// progress overlay with Cancel → result sheet, or a clear error / password prompt.
struct ToolScreen<Options: View>: View {
    let tool: ToolDescriptor
    let files: FileListModel
    let runner: ToolRunner
    let actionTitle: LocalizedStringResource
    var isReady = true
    var footnote: LocalizedStringResource? = nil
    let onRun: () -> Void
    @ViewBuilder let options: () -> Options

    @State private var showFileImporter = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var passwordRequest: PasswordRequest?
    @State private var passwordText = ""

    var body: some View {
        content
            .fileImporter(isPresented: $showFileImporter,
                          allowedContentTypes: files.accepts,
                          allowsMultipleSelection: files.allowsMultiple) { result in
                files.importFromFiles(result)
            }
            .onChange(of: photoItems) { _, items in
                guard !items.isEmpty else { return }
                files.importPhotos(items)
                photoItems = []
            }
            .overlay {
                if runner.isProcessing {
                    ProcessingOverlay(progress: runner.progress, onCancel: { runner.cancel() })
                        .transition(.opacity)
                } else if files.isImporting {
                    ProgressView()
                        .controlSize(.large)
                        .padding(DS.Spacing.l)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DS.Radius.m, style: .continuous))
                }
            }
            .animation(DS.Motion.standard, value: runner.isProcessing)
            .sheet(item: resultBinding) { output in
                ResultView(output: output) { runner.reset() }
            }
            .alert(Text(visibleError?.title ?? ""), isPresented: errorBinding, presenting: visibleError) { _ in
                Button("OK", role: .cancel) {}
            } message: { error in
                Text(error.message)
            }
            .alert(Text("Password needed"), isPresented: passwordBinding, presenting: activePasswordRequest) { request in
                SecureField("Password", text: $passwordText)
                Button("Unlock") { submitPassword(for: request) }
                Button("Cancel", role: .cancel) {}
            } message: { request in
                Text(request.message)
            }
            .sensoryFeedback(.success, trigger: runner.successCount)
            .sensoryFeedback(.error, trigger: runner.failureCount)
    }

    @ViewBuilder
    private var content: some View {
        if files.files.isEmpty {
            ContentUnavailableView {
                Label {
                    Text(tool.title)
                } icon: {
                    ToolIcon(symbol: tool.symbol, tint: tool.category.tint, baseSize: 64)
                }
            } description: {
                Text(tool.subtitle)
            } actions: {
                ImportSourceButtons(files: files, photoItems: $photoItems,
                                    onChooseFiles: { showFileImporter = true }, isProminent: true)
            }
            .background(DS.Palette.background)
        } else {
            List {
                fileSection
                options()
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actionBar
            }
        }
    }

    private var fileSection: some View {
        Section {
            ForEach(files.files) { file in
                FileRow(file: file, password: files.input.password(for: file)) {
                    passwordRequest = PasswordRequest(fileID: file.id, fileName: file.name, wasWrong: false)
                }
            }
            .onDelete { files.remove(atOffsets: $0) }
            .onMove(perform: moveAction)

            if files.allowsMultiple {
                ImportSourceButtons(files: files, photoItems: $photoItems,
                                    onChooseFiles: { showFileImporter = true })
            } else {
                Button {
                    showFileImporter = true
                } label: {
                    Label("Choose another file", systemImage: "arrow.triangle.2.circlepath")
                }
            }
        } header: {
            Text(files.allowsMultiple ? LocalizedStringKey("Files") : LocalizedStringKey("File"))
        } footer: {
            if files.files.count > 1 {
                Text("\(files.files.count) files · \(files.totalBytes.formatted(.byteCount(style: .file)))")
            }
        }
    }

    /// Reordering only makes sense when the tool takes several files.
    private var moveAction: ((IndexSet, Int) -> Void)? {
        guard files.allowsMultiple else { return nil }
        let model = files
        return { source, destination in
            model.move(fromOffsets: source, toOffset: destination)
        }
    }

    private var actionBar: some View {
        VStack(spacing: DS.Spacing.xs) {
            if let footnote {
                Text(footnote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button(action: onRun) {
                Text(actionTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.xxs)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!isReady || runner.isProcessing || files.isImporting)
        }
        .padding(.horizontal, DS.Spacing.m)
        .padding(.vertical, DS.Spacing.s)
        .background(.bar)
    }

    // MARK: Errors & passwords

    /// Import errors and tool failures, except password problems (they get their own prompt).
    private var visibleError: ToolError? {
        if let error = runner.error, !error.isPasswordProblem {
            return error
        }
        return files.importError
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { visibleError != nil },
            set: { isShown in
                guard !isShown else { return }
                if runner.error != nil { runner.reset() }
                files.importError = nil
            }
        )
    }

    private var activePasswordRequest: PasswordRequest? {
        if let passwordRequest {
            return passwordRequest
        }
        if let error = runner.error {
            return PasswordRequest(error)
        }
        return nil
    }

    private var passwordBinding: Binding<Bool> {
        Binding(
            get: { activePasswordRequest != nil },
            set: { isShown in
                guard !isShown else { return }
                passwordRequest = nil
                if runner.error?.isPasswordProblem == true { runner.reset() }
            }
        )
    }

    private var resultBinding: Binding<ToolOutput?> {
        Binding(
            get: { runner.output },
            set: { if $0 == nil { runner.reset() } }
        )
    }

    private func submitPassword(for request: PasswordRequest) {
        let password = passwordText
        passwordText = ""
        let shouldRetryRun = runner.error?.isPasswordProblem == true
        if files.unlock(request.fileID, password: password) {
            if shouldRetryRun {
                runner.reset()
                onRun()
            }
        } else {
            // Ask again once this alert has finished closing.
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                passwordRequest = PasswordRequest(fileID: request.fileID, fileName: request.fileName, wasWrong: true)
            }
        }
    }
}

struct PasswordRequest: Identifiable, Equatable {
    let fileID: UUID
    let fileName: String
    let wasWrong: Bool

    var id: UUID { fileID }

    init(fileID: UUID, fileName: String, wasWrong: Bool) {
        self.fileID = fileID
        self.fileName = fileName
        self.wasWrong = wasWrong
    }

    init?(_ error: ToolError) {
        switch error {
        case let .passwordRequired(fileID, fileName):
            self.init(fileID: fileID, fileName: fileName, wasWrong: false)
        case let .wrongPassword(fileID, fileName):
            self.init(fileID: fileID, fileName: fileName, wasWrong: true)
        default:
            return nil
        }
    }

    var message: String {
        let error: ToolError = wasWrong
            ? .wrongPassword(fileID: fileID, fileName: fileName)
            : .passwordRequired(fileID: fileID, fileName: fileName)
        return error.message
    }
}
