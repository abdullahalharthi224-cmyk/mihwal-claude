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

    func importFromFiles(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            importURLs(urls)
        case .failure(let error):
            importError = ToolError(error)
        }
    }

    func importURLs(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        isImporting = true
        Task {
            let result = await Self.copy(urls)
            add(result.files)
            if let error = result.error {
                importError = error
            }
            isImporting = false
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
    nonisolated private static func copy(_ urls: [URL]) async -> (files: [ImportedFile], error: ToolError?) {
        var files: [ImportedFile] = []
        var firstError: ToolError?
        for url in urls {
            do {
                files.append(try FileStore.importCopy(of: url))
            } catch {
                firstError = firstError ?? ToolError(error)
            }
        }
        return (files, firstError)
    }

    private func add(_ newFiles: [ImportedFile]) {
        let accepted = newFiles.filter { $0.accepted(by: accepts) }
        if let rejected = newFiles.first(where: { !$0.accepted(by: accepts) }) {
            importError = .unsupportedFormat(fileName: rejected.name)
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

    /// Checks the password against the PDF. On success it is remembered for this session only.
    func unlock(_ fileID: UUID, password: String) -> Bool {
        guard let index = files.firstIndex(where: { $0.id == fileID }) else { return false }
        let file = files[index]
        guard let document = PDFDocument(url: file.url), document.unlock(withPassword: password) else {
            return false
        }
        passwords[fileID] = password
        files[index] = ImportedFile(id: file.id, url: file.url, contentType: file.contentType,
                                    byteCount: file.byteCount, pageCount: document.pageCount,
                                    isLocked: file.isLocked)
        return true
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
