import Foundation
import PDFKit

/// PDF to a real Word document with the text (no layout). Pages without text use OCR.
struct PDFToWordEngine: FileTool {
    struct Options: Sendable, Hashable {}

    func run(input: ToolInput, options: Options,
             progress: @escaping @Sendable (Double) -> Void) async throws -> ToolOutput {
        guard let file = input.files.first else { throw ToolError.noInput }
        let document = try PDFLoader.open(file, password: input.password(for: file))
        let count = max(1, document.pageCount)
        let pages = try PDFTextExtractor.extract(from: document) { done in
            progress(Double(done) / Double(count) * 0.9)
        }
        guard pages.contains(where: { !$0.text.isEmpty }) else {
            throw ToolError.nothingToDo(reason: String(localized: "No text was found in this PDF, not even with OCR."))
        }
        let paragraphs = pages.map { DocxWriter.paragraphs(from: $0.text) }

        try Task.checkCancellation()
        return try FileStore.withOutputDirectory { folder -> ToolOutput in
            let url = FileStore.outputURL(in: folder, baseName: file.baseName, suffix: nil, pathExtension: "docx")
            try DocxWriter.write(pages: paragraphs, to: url)
            progress(1)
            var output = ToolOutput(directory: folder, files: [url])
            output.notes.append(String(localized: "Only the text is converted. Layout, pictures and tables are not kept."))
            output.notes += PDFTextExtractor.notes(for: pages)
            return output
        }
    }
}
