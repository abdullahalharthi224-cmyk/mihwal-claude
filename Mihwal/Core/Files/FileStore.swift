import Foundation
import PDFKit
import UniformTypeIdentifiers

/// Owns the app's temporary folders. Inputs are copied in, results are written out,
/// and everything is wiped on the next launch.
enum FileStore {
    static var inputsDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Inputs", isDirectory: true)
    }

    static var outputsDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Outputs", isDirectory: true)
    }

    /// Copies a file into tmp/Inputs/<UUID>/ and inspects it.
    /// `coordinated` uses NSFileCoordinator so iCloud files are downloaded first.
    static func importCopy(of source: URL, coordinated: Bool = true) throws -> ImportedFile {
        // Access stays open until this function returns, i.e. until the copy below is finished.
        let isScoped = source.startAccessingSecurityScopedResource()
        defer {
            if isScoped { source.stopAccessingSecurityScopedResource() }
        }
        Log.importing.debug("Copying file, security-scoped access: \(isScoped)")

        let folder = inputsDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = folder.appendingPathComponent(sanitizedName(source.lastPathComponent))

        if coordinated {
            try coordinatedCopy(from: source, to: destination)
        } else {
            try FileManager.default.copyItem(at: source, to: destination)
        }
        return inspect(destination)
    }

    static func inspect(_ url: URL) -> ImportedFile {
        let type = contentType(of: url)
        var pageCount: Int?
        var isLocked = false
        var isEncrypted = false
        if type.conforms(to: .pdf), let document = PDFDocument(url: url) {
            isLocked = document.isLocked
            isEncrypted = document.isEncrypted
            pageCount = isLocked ? nil : document.pageCount
        }
        return ImportedFile(id: UUID(), url: url, contentType: type, byteCount: byteCount(of: url),
                            pageCount: pageCount, isLocked: isLocked, isEncrypted: isEncrypted)
    }

    static func contentType(of url: URL) -> UTType {
        let values = try? url.resourceValues(forKeys: [.contentTypeKey])
        if let type = values?.contentType {
            return type
        }
        return UTType(filenameExtension: url.pathExtension) ?? .data
    }

    static func byteCount(of url: URL) -> Int64 {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values?.fileSize ?? 0)
    }

    static func makeOutputDirectory() throws -> URL {
        let folder = outputsDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Runs `body` with a fresh output folder and deletes the folder if `body` throws,
    /// so a failed or cancelled tool never leaves half-written files behind.
    static func withOutputDirectory<T>(_ body: (URL) throws -> T) throws -> T {
        let folder = try makeOutputDirectory()
        do {
            return try body(folder)
        } catch {
            remove(folder)
            throw error
        }
    }

    /// "report (reversed).pdf", then "report (reversed) 2.pdf" if that name is taken.
    static func outputURL(in directory: URL, baseName: String, suffix: String?, pathExtension: String) -> URL {
        let stem = suffix.map { "\(baseName) (\($0))" } ?? baseName
        var candidate = directory.appendingPathComponent(stem).appendingPathExtension(pathExtension)
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(stem) \(counter)").appendingPathExtension(pathExtension)
            counter += 1
        }
        return candidate
    }

    static func remove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Called on launch: nothing from a previous session is kept.
    static func removeTemporaryFiles() {
        remove(inputsDirectory)
        remove(outputsDirectory)
    }

    /// Files shared into the app ("Open in") land in Documents/Inbox; we delete them after copying.
    static func isInboxFile(_ url: URL) -> Bool {
        url.deletingLastPathComponent().lastPathComponent == "Inbox"
    }

    private static func sanitizedName(_ name: String) -> String {
        let cleaned = name.replacingOccurrences(of: "/", with: "-").trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty ? "file" : cleaned
    }

    private static func coordinatedCopy(from source: URL, to destination: URL) throws {
        var coordinatorError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: source, options: .withoutChanges, error: &coordinatorError) { readableURL in
            do {
                try FileManager.default.copyItem(at: readableURL, to: destination)
            } catch {
                copyError = error
            }
        }
        if let coordinatorError {
            throw coordinatorError
        }
        if let copyError {
            throw copyError
        }
    }
}
