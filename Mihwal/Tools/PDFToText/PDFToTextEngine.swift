import Foundation
import PDFKit

/// Saves the text of a PDF as a .txt file. Pages without a text layer are read with OCR,
/// and the result says which ones.
struct PDFToTextEngine: FileTool {
    struct Options: Sendable, Hashable {
        /// Read every page with OCR, even pages that have text.
        var forceOCR = false
        /// "— Page 3 —" lines between pages.
        var pageSeparators = true
    }

    static func joined(_ pages: [PageText], separators: Bool) -> String {
        pages.map { page in
            separators ? "— \(String(localized: "Page \(page.index + 1)")) —\n\(page.text)" : page.text
        }
        .joined(separator: "\n\n")
    }

    func run(input: ToolInput, options: Options,
             progress: @escaping @Sendable (Double) -> Void) async throws -> ToolOutput {
        guard let file = input.files.first else { throw ToolError.noInput }
        let document = try PDFLoader.open(file, password: input.password(for: file))
        let count = max(1, document.pageCount)
        let pages = try PDFTextExtractor.extract(from: document, forceOCR: options.forceOCR) { done in
            progress(Double(done) / Double(count) * 0.95)
        }
        guard pages.contains(where: { !$0.text.isEmpty }) else {
            throw ToolError.nothingToDo(reason: String(localized: "No text was found in this PDF, not even with OCR."))
        }
        let text = Self.joined(pages, separators: options.pageSeparators)

        return try FileStore.withOutputDirectory { folder -> ToolOutput in
            let url = FileStore.outputURL(in: folder, baseName: file.baseName,
                                          suffix: String(localized: "text"), pathExtension: "txt")
            try StorageGuard.ensureSpace(for: Int64(text.utf8.count))
            try text.write(to: url, atomically: true, encoding: .utf8)
            progress(1)
            var output = ToolOutput(directory: folder, files: [url])
            output.notes = PDFTextExtractor.notes(for: pages)
            output.copyableText = text
            return output
        }
    }
}
