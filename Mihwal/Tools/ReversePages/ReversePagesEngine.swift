import Foundation
import PDFKit

/// Puts the last page first. Pages are copied (not re-drawn), so text, links and
/// annotations are kept.
struct ReversePagesEngine: FileTool {
    struct Options: Sendable {}

    func run(input: ToolInput, options: Options,
             progress: @escaping @Sendable (Double) -> Void) async throws -> ToolOutput {
        guard let file = input.files.first else { throw ToolError.noInput }
        let source = try PDFLoader.open(file, password: input.password(for: file))
        let count = source.pageCount
        guard count > 1 else {
            throw ToolError.nothingToDo(reason: String(localized: "This PDF has only one page, so there is nothing to reverse."))
        }

        let result = PDFDocument()
        for (position, index) in (0..<count).reversed().enumerated() {
            try Task.checkCancellation()
            guard let page = source.page(at: index)?.copy() as? PDFPage else {
                throw ToolError.corruptedFile(fileName: file.name)
            }
            result.insert(page, at: position)
            progress(Double(position + 1) / Double(count) * 0.9)
        }

        try Task.checkCancellation()
        return try FileStore.withOutputDirectory { folder -> ToolOutput in
            let url = FileStore.outputURL(in: folder, baseName: file.baseName,
                                          suffix: String(localized: "reversed"), pathExtension: "pdf")
            try PDFLoader.write(result, to: url, estimatedBytes: file.byteCount)
            progress(1)
            return ToolOutput(directory: folder, files: [url])
        }
    }
}
