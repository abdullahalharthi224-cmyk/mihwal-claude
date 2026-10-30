import Foundation
import PDFKit

/// Saves the chosen pages, in page order, as a new PDF. The original is untouched.
struct ExtractPagesEngine: FileTool {
    struct Options: Sendable {
        var pages: Set<Int>
    }

    func run(input: ToolInput, options: Options,
             progress: @escaping @Sendable (Double) -> Void) async throws -> ToolOutput {
        guard let file = input.files.first else { throw ToolError.noInput }
        let source = try PDFLoader.open(file, password: input.password(for: file))
        let pages = options.pages.filter { (0..<source.pageCount).contains($0) }.sorted()
        guard !pages.isEmpty else {
            throw ToolError.nothingToDo(reason: String(localized: "Select the pages you want to extract."))
        }

        let result = try PDFLoader.copyPages(pages, from: source, fileName: file.name) { done in
            progress(Double(done) / Double(pages.count) * 0.8)
        }

        try Task.checkCancellation()
        return try FileStore.withOutputDirectory { folder -> ToolOutput in
            let url = FileStore.outputURL(in: folder, baseName: file.baseName,
                                          suffix: String(localized: "extracted"), pathExtension: "pdf")
            try PDFLoader.write(result, to: url, estimatedBytes: file.byteCount)
            progress(1)
            return ToolOutput(directory: folder, files: [url])
        }
    }
}
