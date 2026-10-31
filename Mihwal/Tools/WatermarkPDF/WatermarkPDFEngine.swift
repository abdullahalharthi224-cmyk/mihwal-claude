import CoreGraphics
import Foundation
import PDFKit

/// Stamps a text watermark on every page with Core Text (Arabic shaped, RTL).
struct WatermarkPDFEngine: FileTool {
    struct Options: Sendable, Hashable {
        var style = WatermarkStyle(text: "", size: .large, color: .red, opacity: 0.25, angle: 45, position: .center)
    }

    func run(input: ToolInput, options: Options,
             progress: @escaping @Sendable (Double) -> Void) async throws -> ToolOutput {
        guard !options.style.trimmedText.isEmpty else {
            throw ToolError.nothingToDo(reason: String(localized: "Type the watermark text first."))
        }
        guard let file = input.files.first else { throw ToolError.noInput }
        let document = try PDFLoader.open(file, password: input.password(for: file))
        let count = document.pageCount
        let flattens = PDFLoader.hasInteractiveContent(document)
        try StorageGuard.ensureSpace(for: file.byteCount * 2)

        return try FileStore.withOutputDirectory { folder -> ToolOutput in
            let url = FileStore.outputURL(in: folder, baseName: file.baseName,
                                          suffix: String(localized: "watermarked"), pathExtension: "pdf")
            try PDFRedraw.write(document, to: url, fileName: file.name, progress: { done in
                progress(Double(done) / Double(max(1, count)))
            }) { context, size, _ in
                WatermarkRenderer.draw(options.style, in: context, size: size)
            }
            var output = ToolOutput(directory: folder, files: [url])
            if flattens {
                output.notes.append(String(localized: "Links, form fields and comments are now part of the pages (flattened)."))
            }
            return output
        }
    }

    static func previewImage(file: ImportedFile, password: String?, options: Options) -> CGImage? {
        guard let document = try? PDFLoader.open(file, password: password), document.pageCount > 0 else { return nil }
        return PDFRedraw.previewImage(of: document, pageIndex: 0, maxPixelSize: 900) { context, size, _ in
            WatermarkRenderer.draw(options.style, in: context, size: size)
        }
    }
}
