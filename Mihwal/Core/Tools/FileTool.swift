import Foundation
import UniformTypeIdentifiers

/// What a tool receives: the imported files and any PDF passwords the user typed.
struct ToolInput: Sendable {
    var files: [ImportedFile]
    var passwords: [UUID: String] = [:]

    func password(for file: ImportedFile) -> String? {
        passwords[file.id]
    }
}

/// What a tool produces: files in its own output folder.
struct ToolOutput: Identifiable, Sendable {
    let id = UUID()
    let directory: URL
    let files: [URL]
    /// Set by compression tools so the result screen can show before → after.
    var inputBytes: Int64? = nil
    /// Short notes for the user, e.g. "Links were flattened".
    var notes: [String] = []
    /// The input was a protected PDF and this result isn't: warn before it is saved.
    var removedProtection = false

    var outputBytes: Int64 {
        files.reduce(0) { $0 + FileStore.byteCount(of: $1) }
    }

    var isAllImages: Bool {
        !files.isEmpty && files.allSatisfy { FileStore.contentType(of: $0).conforms(to: .image) }
    }
}

/// One engine per tool. Engines are pure logic (no SwiftUI) and run off the main thread.
/// They must call `try Task.checkCancellation()` between pages/images and report
/// progress from 0 to 1.
protocol FileTool: Sendable {
    associatedtype Options: Sendable
    func run(input: ToolInput, options: Options,
             progress: @escaping @Sendable (Double) -> Void) async throws -> ToolOutput
}

/// A navigation destination: a tool, optionally with files already chosen
/// (for example a PDF shared into the app from another app).
struct ToolRoute: Hashable {
    let tool: ToolID
    var files: [ImportedFile] = []
}
