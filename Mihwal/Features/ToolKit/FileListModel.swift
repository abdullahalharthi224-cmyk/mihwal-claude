import PDFKit
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// The files chosen for one tool: importing (Files, Photos, "Open in"), order, removal
/// and PDF passwords. Every tool screen owns one.
@MainActor
@Observable
final class FileListModel {
    let accepts: [UTType]
    let allowsMultiple: Bool

    private(set) var files: [ImportedFile] = []
    private(set) var passwords: [UUID: String] = [:]
    private(set) var isImporting = false
    var importError: ToolError?

    init(accepts: [UTType], allowsMultiple: Bool, initial: [ImportedFile] = []) {
        self.accepts = accepts
        self.allowsMultiple = allowsMultiple
        add(initial)
    }

    var input: ToolInput {
        ToolInput(files: files, passwords: passwords)
    }

    var totalBytes: Int64 {
        files.reduce(0) { $0 + $1.byteCount }
    }

    var acceptsImages: Bool {
        accepts.contains { UTType.image.conforms(to: $0) || $0.conforms(to: .image) }
    }

    // MARK: Importing

    /// Imports files. `deleteSources` removes the originals afterwards (used for the copies
    /// the Files picker makes for us). Every failure ends up in `importError`.
    func importURLs(_ urls: [URL], deleteSources: Bool = false) {
        guard !urls.isEmpty else { return }
        Log.importing.info("Importing \(urls.count) file(s)")
        isImporting = true
        Task {
            let result = await Self.copy(urls, deleteSources: deleteSources)
            add(result.files)
            if let error = result.error {
                importError = error
            }
            isImporting = false
            Log.importing.info("Import finished: \(result.files.count) copied, failed: \(result.error != nil)")
        }
    }

    func importPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        isImporting = true
        Task {
            var imported: [ImportedFile] = []
            var failure: ToolError?
            for item in items {
                do {
                    if let picked = try await item.loadTransferable(type: PickedImageFile.self) {
                        imported.append(picked.file)
                    }
                } catch {
                    failure = failure ?? ToolError(error)
                }
            }
            add(imported)
            if let failure {
                importError = failure
            }
            isImporting = false
        }
    }

    /// Copies files off the main thread (large or iCloud files can take a moment).
    nonisolated private static func copy(_ urls: [URL], deleteSources: Bool) async -> (files: [ImportedFile], error: ToolError?) {
        var files: [ImportedFile] = []
        var firstError: ToolError?
        for url in urls {
            do {
                files.append(try FileStore.importCopy(of: url))
            } catch {
                Log.importing.error("Copy failed: \(error.localizedDescription, privacy: .public)")
                firstError = firstError ?? ToolError(error)
            }
            if deleteSources {
                FileStore.remove(url)
            }
        }
        return (files, firstError)
    }

    private func add(_ newFiles: [ImportedFile]) {
        let accepted = newFiles.filter { $0.accepted(by: accepts) }
        if let rejected = newFiles.first(where: { !$0.accepted(by: accepts) }) {
            Log.importing.error("Rejected unsupported type: \(rejected.contentType.identifier, privacy: .public)")
            importError = .unsupportedFormat(fileName: rejected.name)
            newFiles.filter { !$0.accepted(by: accepts) }.forEach { FileStore.remove($0.url) }
        }
        guard !accepted.isEmpty else { return }
        withAnimation(DS.Motion.standard) {
            if allowsMultiple {
                files.append(contentsOf: accepted)
            } else {
                files.forEach(forget)
                files = Array(accepted.prefix(1))
            }
        }
    }

    // MARK: Editing

    func remove(atOffsets offsets: IndexSet) {
        offsets.map { files[$0] }.forEach(forget)
        files.remove(atOffsets: offsets)
    }

    func remove(_ file: ImportedFile) {
        guard let index = files.firstIndex(of: file) else { return }
        remove(atOffsets: IndexSet(integer: index))
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        files.move(fromOffsets: source, toOffset: destination)
    }

    /// Moves a file to a new position (used by drag and drop in Merge).
    func move(_ id: UUID, toIndex target: Int) {
        guard let from = files.firstIndex(where: { $0.id == id }), !files.isEmpty else { return }
        let destination = max(0, min(target, files.count - 1))
        guard from != destination else { return }
        let file = files.remove(at: from)
        files.insert(file, at: destination)
    }

    enum UnlockOutcome: Equatable {
        /// The file opens and may be changed.
        case unlocked
        case wrongPassword
        /// The file opens with this password, but its owner blocked changes:
        /// the owner (permissions) password is still needed.
        case needsOwnerPassword
    }

    /// Checks a password against the PDF. A password that works is remembered for this
    /// session only (never stored on disk).
    func unlock(_ fileID: UUID, password: String) -> UnlockOutcome {
        guard let index = files.firstIndex(where: { $0.id == fileID }),
              let document = PDFDocument(url: files[index].url) else { return .wrongPassword }
        let file = files[index]
        if document.isLocked {
            guard document.unlock(withPassword: password) else { return .wrongPassword }
        } else if document.isEncrypted {
            // Already open; the owner password raises access to "owner".
            _ = document.unlock(withPassword: password)
        }
        if document.isLocked || file.pageCount == nil {
            files[index] = ImportedFile(id: file.id, url: file.url, contentType: file.contentType,
                                        byteCount: file.byteCount, pageCount: document.pageCount,
                                        isLocked: file.isLocked, isEncrypted: file.isEncrypted)
        }
        if PDFLoader.hasRestrictions(document) {
            // Keep a password that opens the file (for thumbnails), but ask for the owner's.
            if file.isLocked {
                passwords[fileID] = password
            }
            return .needsOwnerPassword
        }
        passwords[fileID] = password
        return .unlocked
    }

    func isUnlocked(_ file: ImportedFile) -> Bool {
        !file.isLocked || passwords[file.id] != nil
    }

    private func forget(_ file: ImportedFile) {
        passwords[file.id] = nil
        let url = file.url
        Task { await ThumbnailProvider.shared.forget(url) }
    }
}

/// Receives a photo from PhotosPicker as a file, keeping its original format (HEIC stays HEIC).
struct PickedImageFile: Transferable {
    let file: ImportedFile

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            PickedImageFile(file: try FileStore.importCopy(of: received.file, coordinated: false))
        }
    }
}
