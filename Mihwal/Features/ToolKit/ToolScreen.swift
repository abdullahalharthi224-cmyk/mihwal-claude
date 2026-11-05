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
    /// `.list` for simple tools; `.scroll` for tools with big lazy grids (pages, merge),
    /// because a lazy grid inside a List row would load every thumbnail at once.
    var layout: Layout = .list
    /// Show the options before any file is chosen (Text to PDF can be typed instead).
    var showsOptionsWithoutFiles = false
    var emptyImportHint: LocalizedStringResource? = nil
    let onRun: () -> Void
    @ViewBuilder let options: () -> Options

    @State private var activeSheet: ToolSheet?
    @State private var photoItems: [PhotosPickerItem] = []
    /// A run that stopped for a password restarts once the password sheet has closed.
    @State private var runAfterSheetCloses = false

    enum Layout {
        case list
        case scroll
    }

    /// One sheet slot for everything this screen presents. Separate `.fileImporter` and
    /// `.sheet` modifiers on the same view compete for the same presentation, and the
    /// file importer's result could be lost.
    enum ToolSheet: Identifiable {
        case filePicker
        case result(ToolOutput)
        /// `retryRun`: the tool stopped for this password and runs again once unlocked.
        case password(PasswordRequest, retryRun: Bool)

        var id: String {
            switch self {
            case .filePicker: return "filePicker"
            case .result(let output): return output.id.uuidString
            case .password(let request, _): return "password-\(request.fileID)"
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
            .onChange(of: runner.failureCount) { _, _ in
                // A password problem opens the password sheet instead of an alert.
                if let error = runner.error, let request = PasswordRequest(error) {
                    runner.reset()
                    activeSheet = .password(request, retryRun: true)
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
                if runAfterSheetCloses {
                    runAfterSheetCloses = false
                    onRun()
                }
            }, content: { sheetContent($0) })
            .alert(Text(visibleFailure?.title ?? ""), isPresented: failureBinding, presenting: visibleFailure) { _ in
                Button("OK", role: .cancel) {}
            } message: { error in
                Text(error.message)
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
        case let .password(request, retryRun):
            PasswordSheet(request: request) { password in
                let outcome = files.unlock(request.fileID, password: password)
                if outcome == .unlocked {
                    runAfterSheetCloses = retryRun
                    activeSheet = nil
                }
                return outcome
            } cancel: {
                activeSheet = nil
            }
        }
    }

    private func chooseFiles() {
        files.importError = nil
        activeSheet = .filePicker
    }

    @ViewBuilder
    private var content: some View {
        if files.files.isEmpty && !showsOptionsWithoutFiles {
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
        } else if layout == .scroll {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.l) {
                    if let error = files.importError {
                        ImportErrorBanner(error: error) { files.importError = nil }
                    }
                    if !files.allowsMultiple, let file = files.files.first {
                        singleFileCard(file)
                    }
                    options()
                    if files.allowsMultiple {
                        ImportSourceButtons(files: files, photoItems: $photoItems,
                                            onChooseFiles: { chooseFiles() })
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, DS.Spacing.m)
                .padding(.vertical, DS.Spacing.s)
            }
            .background(DS.Palette.background)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actionBar
            }
        } else {
            List {
                if let error = files.importError {
                    Section {
                        ImportErrorBanner(error: error) { files.importError = nil }
                    }
                }
                if files.files.isEmpty {
                    Section {
                        ImportSourceButtons(files: files, photoItems: $photoItems,
                                            onChooseFiles: { chooseFiles() })
                    } footer: {
                        if let emptyImportHint {
                            Text(emptyImportHint)
                        }
                    }
                } else {
                    fileSection
                }
                options()
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actionBar
            }
        }
    }

    private func singleFileCard(_ file: ImportedFile) -> some View {
        OptionCard {
            FileRow(file: file, password: files.input.password(for: file)) {
                activeSheet = .password(PasswordRequest(fileID: file.id, fileName: file.name, wasWrong: false), retryRun: false)
            }
            Divider()
            Button {
                chooseFiles()
            } label: {
                Label("Choose another file", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline)
            }
        }
    }

    private var fileSection: some View {
        Section {
            ForEach(files.files) { file in
                FileRow(file: file, password: files.input.password(for: file)) {
                    activeSheet = .password(PasswordRequest(fileID: file.id, fileName: file.name, wasWrong: false), retryRun: false)
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
                // Plural strings take only the count. Mixing the count with another
                // argument breaks Arabic forms that omit the number (e.g. «ملفان»).
                HStack(spacing: DS.Spacing.xxs) {
                    Text("\(files.files.count) files")
                    Text(verbatim: "·")
                    Text(files.totalBytes.formatted(.byteCount(style: .file)))
                }
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
            .accessibilityIdentifier("tool.run")
        }
        .padding(.horizontal, DS.Spacing.m)
        .padding(.vertical, DS.Spacing.s)
        .background(.bar)
    }

    // MARK: Errors

    /// Failed runs, except password problems (those open the password sheet).
    /// Import problems are shown inline instead (see ImportErrorBanner), because an alert
    /// raised while the Files picker is still closing is dropped by iOS.
    private var visibleFailure: ToolError? {
        guard let error = runner.error, !error.isPasswordProblem else { return nil }
        return error
    }

    private var failureBinding: Binding<Bool> {
        Binding(
            get: { visibleFailure != nil },
            set: { isShown in
                if !isShown && runner.error != nil { runner.reset() }
            }
        )
    }
}

struct PasswordRequest: Identifiable, Equatable {
    let fileID: UUID
    let fileName: String
    let wasWrong: Bool
    /// The owner (permissions) password is needed, not the one that opens the file.
    var needsOwnerPassword = false

    var id: UUID { fileID }

    init(fileID: UUID, fileName: String, wasWrong: Bool, needsOwnerPassword: Bool = false) {
        self.fileID = fileID
        self.fileName = fileName
        self.wasWrong = wasWrong
        self.needsOwnerPassword = needsOwnerPassword
    }

    init?(_ error: ToolError) {
        switch error {
        case let .passwordRequired(fileID, fileName):
            self.init(fileID: fileID, fileName: fileName, wasWrong: false)
        case let .wrongPassword(fileID, fileName):
            self.init(fileID: fileID, fileName: fileName, wasWrong: true)
        case let .ownerPasswordRequired(fileID, fileName, afterAttempt):
            self.init(fileID: fileID, fileName: fileName, wasWrong: afterAttempt, needsOwnerPassword: true)
        default:
            return nil
        }
    }

    var message: String {
        let error: ToolError
        if needsOwnerPassword {
            error = .ownerPasswordRequired(fileID: fileID, fileName: fileName, afterAttempt: wasWrong)
        } else if wasWrong {
            error = .wrongPassword(fileID: fileID, fileName: fileName)
        } else {
            error = .passwordRequired(fileID: fileID, fileName: fileName)
        }
        return error.message
    }
}
