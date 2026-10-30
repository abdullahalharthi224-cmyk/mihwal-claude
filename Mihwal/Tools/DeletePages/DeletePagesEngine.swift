import Foundation
import PDFKit

/// Removes the chosen pages. At least one page must stay.
struct DeletePagesEngine: FileTool {
    struct Options: Sendable {
        var pages: Set<Int>
    }

    func run(input: ToolInput, options: Options,
             progress: @escaping @Sendable (Double) -> Void) async throws -> ToolOutput {
        guard let file = input.files.first else { throw ToolError.noInput }
        let source = try PDFLoader.open(file, password: input.password(for: file))
        let count = source.pageCount
        let toDelete = options.pages.filter { (0..<count).contains($0) }
        guard !toDelete.isEmpty else {
            throw ToolError.nothingToDo(reason: String(localized: "Select the pages you want to delete."))
        }
        guard toDelete.count < count else {
            throw ToolError.nothingToDo(reason: String(localized: "A PDF needs at least one page. Leave at least one page unselected."))
        }

        let kept = (0..<count).filter { !toDelete.contains($0) }
        let result = try PDFLoader.copyPages(kept, from: source, fileName: file.name) { done in
            progress(Double(done) / Double(kept.count) * 0.8)
        }

        try Task.checkCancellation()
        return try FileStore.withOutputDirectory { folder -> ToolOutput in
            let url = FileStore.outputURL(in: folder, baseName: file.baseName,
                                          suffix: String(localized: "edited"), pathExtension: "pdf")
            try PDFLoader.write(result, to: url, estimatedBytes: file.byteCount)
            progress(1)
            return ToolOutput(directory: folder, files: [url])
        }
    }
}
