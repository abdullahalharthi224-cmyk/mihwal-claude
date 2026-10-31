import Foundation
import PDFKit

/// Removes the open password and the owner restrictions — only after the correct password
/// was entered (PDFLoader asks for it; nothing is ever guessed or bypassed).
struct UnlockPDFEngine: FileTool {
    struct Options: Sendable, Hashable {}

    func run(input: ToolInput, options: Options,
             progress: @escaping @Sendable (Double) -> Void) async throws -> ToolOutput {
        guard let file = input.files.first else { throw ToolError.noInput }
        guard let probe = PDFDocument(url: file.url) else { throw ToolError.corruptedFile(fileName: file.name) }
        guard probe.isEncrypted else {
            throw ToolError.nothingToDo(reason: String(localized: "This PDF has no password or restrictions."))
        }
        let source = try PDFLoader.open(file, password: input.password(for: file))
        // Copies go into a brand-new document, which has no encryption.
        let count = source.pageCount
        let result = try PDFLoader.copyPages(Array(0..<count), from: source, fileName: file.name) { done in
            progress(Double(done) / Double(max(1, count)) * 0.85)
        }
        result.documentAttributes = source.documentAttributes

        try Task.checkCancellation()
        return try FileStore.withOutputDirectory { folder -> ToolOutput in
            let url = FileStore.outputURL(in: folder, baseName: file.baseName,
                                          suffix: String(localized: "unlocked"), pathExtension: "pdf")
            try PDFLoader.write(result, to: url, estimatedBytes: file.byteCount)
            progress(1)
            return ToolOutput(directory: folder, files: [url], removedProtection: true)
        }
    }
}
