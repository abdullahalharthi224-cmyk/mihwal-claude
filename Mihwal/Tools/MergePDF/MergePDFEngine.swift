import Foundation
import PDFKit

/// Joins several PDFs, in the given order, into one. Pages are copied, not re-drawn.
struct MergePDFEngine: FileTool {
    struct Options: Sendable {}

    func run(input: ToolInput, options: Options,
             progress: @escaping @Sendable (Double) -> Void) async throws -> ToolOutput {
        guard input.files.count >= 2 else {
            throw ToolError.nothingToDo(reason: String(localized: "Add at least two PDFs to merge."))
        }
        // Open everything first, so a missing password is reported before any work is done.
        let sources = try input.files.map { file in
            (file: file, document: try PDFLoader.open(file, password: input.password(for: file)))
        }
        let totalPages = max(1, sources.reduce(0) { $0 + $1.document.pageCount })

        let result = PDFDocument()
        var inserted = 0
        for source in sources {
            for index in 0..<source.document.pageCount {
                try Task.checkCancellation()
                guard let page = source.document.page(at: index)?.copy() as? PDFPage else {
                    throw ToolError.corruptedFile(fileName: source.file.name)
                }
                result.insert(page, at: inserted)
                inserted += 1
                progress(Double(inserted) / Double(totalPages) * 0.85)
            }
        }

        try Task.checkCancellation()
        let totalBytes = input.files.reduce(0) { $0 + $1.byteCount }
        let first = input.files[0]
        return try FileStore.withOutputDirectory { folder -> ToolOutput in
            let url = FileStore.outputURL(in: folder, baseName: first.baseName,
                                          suffix: String(localized: "merged"), pathExtension: "pdf")
            try PDFLoader.write(result, to: url, estimatedBytes: totalBytes)
            progress(1)
            return ToolOutput(directory: folder, files: [url])
        }
    }
}
