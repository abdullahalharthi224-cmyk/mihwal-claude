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

    @State private var activeSheet: ToolSheet?
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var passwordRequest: PasswordRequest?
    @State private var passwordText = ""
    /// Set when a run stopped for a password, so it restarts once the right one is entered.
    @State private var retryRunAfterUnlock = false

    /// One sheet slot for everything this screen presents. Separate `.fileImporter` and
    /// `.sheet` modifiers on the same view compete for the same presentation, and the
    /// file importer's result could be lost.
    enum ToolSheet: Identifiable {
        case filePicker
        case result(ToolOutput)

        var id: String {
            switch self {
            case .filePicker: return "filePicker"
            case .result(let output): return output.id.uuidString
            }
        }
    }

    var body: some View {
        content
            .onChange(of: photoItems) { _, items in
                guard !items.isEmpty else { return }
                files.importPhotos(items)
                photoItems = []
            }
            .onChange(of: runner.successCount) { _, _ in
                if let output = runner.output {
                    activeSheet = .result(output)
                }
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
            .sheet(item: $activeSheet, onDismiss: {
                // Closing the result (swipe or Done) clears it; closing the picker changes nothing.
                if runner.output != nil { runner.reset() }
            }, content: { sheetContent($0) })
            .alert(Text(activeAlert?.title ?? ""), isPresented: alertBinding, presenting: activeAlert) { alert in
                switch alert {
                case .password(let request):
                    SecureField("Password", text: $passwordText)
                    Button("Unlock") { submitPassword(for: request) }
                    Button("Cancel", role: .cancel) {}
                case .failure:
                    Button("OK", role: .cancel) {}
                }
            } message: { alert in
                Text(alert.message)
            }
            .sensoryFeedback(.success, trigger: runner.successCount)
            .sensoryFeedback(.error, trigger: runner.failureCount)
            .sensoryFeedback(.error, trigger: files.importError) { _, newValue in newValue != nil }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: ToolSheet) -> some View {
        switch sheet {
        case .filePicker:
            DocumentPicker(contentTypes: files.accepts, allowsMultipleSelection: files.allowsMultiple) { urls in
                activeSheet = nil
                files.importURLs(urls, deleteSources: true)
            }
            .ignoresSafeArea()
        case .result(let output):
            ResultView(output: output) {
                activeSheet = nil
                runner.reset()
            }
        }
    }

    private func chooseFiles() {
        files.importError = nil
        activeSheet = .filePicker
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
                VStack(spacing: DS.Spacing.m) {
                    ImportSourceButtons(files: files, photoItems: $photoItems,
                                        onChooseFiles: { chooseFiles() }, isProminent: true)
                    if let error = files.importError {
                        ImportErrorBanner(error: error) { files.importError = nil }
                    }
                }
            }
            .background(DS.Palette.background)
        } else {
            List {
                if let error = files.importError {
                    Section {
                        ImportErrorBanner(error: error) { files.importError = nil }
                    }
                }
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
                                    onChooseFiles: { chooseFiles() })
            } else {
                Button {
                    chooseFiles()
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

    /// The single alert of this screen: a failed run, or a PDF password prompt.
    /// Import problems are shown inline instead (see ImportErrorBanner), because an alert
    /// raised while the Files picker is still closing is dropped by iOS.
    enum ToolAlert {
        case failure(ToolError)
        case password(PasswordRequest)

        var title: String {
            switch self {
            case .failure(let error): return error.title
            case .password: return String(localized: "Password needed")
            }
        }

        var message: String {
            switch self {
            case .failure(let error): return error.message
            case .password(let request): return request.message
            }
        }
    }

    private var activeAlert: ToolAlert? {
        if let passwordRequest {
            return .password(passwordRequest)
        }
        if let error = runner.error {
            if let request = PasswordRequest(error) {
                return .password(request)
            }
            return .failure(error)
        }
        return nil
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { activeAlert != nil },
            set: { isShown in
                guard !isShown else { return }
                passwordRequest = nil
                if runner.error != nil { runner.reset() }
            }
        )
    }

    private func submitPassword(for request: PasswordRequest) {
        let password = passwordText
        passwordText = ""
        let shouldRetryRun = retryRunAfterUnlock || runner.error?.isPasswordProblem == true
        retryRunAfterUnlock = false
        if files.unlock(request.fileID, password: password) {
            if shouldRetryRun {
                runner.reset()
                onRun()
            }
        } else {
            retryRunAfterUnlock = shouldRetryRun
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
