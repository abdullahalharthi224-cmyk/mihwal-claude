import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers

/// iOS has no "reduce file size" filter, so there are two honest levels:
/// - balanced: PDFKit re-encodes embedded images as JPEG for screen; text stays text.
/// - strong: every page becomes a JPEG picture (much smaller for scans; text no longer selectable).
/// A result that isn't smaller than the original is never returned.
struct CompressPDFEngine: FileTool {
    enum Level: String, Hashable, Sendable, CaseIterable {
        case balanced
        case strong
    }

    struct Options: Sendable, Hashable {
        var level: Level = .balanced
    }

    static let strongDPI: CGFloat = 110
    static let strongQuality: Double = 0.55

    func run(input: ToolInput, options: Options,
             progress: @escaping @Sendable (Double) -> Void) async throws -> ToolOutput {
        guard let file = input.files.first else { throw ToolError.noInput }
        let source = try PDFLoader.open(file, password: input.password(for: file))
        let count = source.pageCount
        try StorageGuard.ensureSpace(for: file.byteCount * 2)

        return try FileStore.withOutputDirectory { folder -> ToolOutput in
            let url = FileStore.outputURL(in: folder, baseName: file.baseName,
                                          suffix: String(localized: "compressed"), pathExtension: "pdf")
            switch options.level {
            case .balanced:
                // A fresh copy, so the result is never encrypted.
                let copy = try PDFLoader.copyPages(Array(0..<count), from: source, fileName: file.name) { done in
                    progress(Double(done) / Double(max(1, count)) * 0.5)
                }
                guard copy.write(to: url, withOptions: [.saveImagesAsJPEGOption: true,
                                                        .optimizeImagesForScreenOption: true]) else {
                    throw ToolError.writeFailed
                }
            case .strong:
                try Self.writeRasterized(source, to: url, fileName: file.name) { done in
                    progress(Double(done) / Double(max(1, count)) * 0.95)
                }
            }

            let newSize = FileStore.byteCount(of: url)
            guard newSize < file.byteCount else {
                let size = file.byteCount.formatted(.byteCount(style: .file))
                throw ToolError.nothingToDo(reason: String(localized: "This level can't make the PDF smaller than it already is (\(size)). Your original is unchanged."))
            }
            progress(1)
            var output = ToolOutput(directory: folder, files: [url], inputBytes: file.byteCount)
            if options.level == .strong {
                output.notes.append(String(localized: "Pages are now pictures: text can't be selected or searched in this copy."))
            }
            return output
        }
    }

    /// Each page → JPEG → a PDF page that only holds that JPEG. An image created from JPEG
    /// data is embedded as JPEG (not re-encoded), which is what makes the file small.
    static func writeRasterized(_ document: PDFDocument, to url: URL, fileName: String,
                                progress: (Int) -> Void) throws {
        var defaultBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let consumer = CGDataConsumer(url: url as CFURL),
              let context = CGContext(consumer: consumer, mediaBox: &defaultBox, nil) else {
            throw ToolError.writeFailed
        }
        for index in 0..<document.pageCount {
            try Task.checkCancellation()
            try autoreleasepool {
                guard let page = document.page(at: index),
                      let bitmap = PDFRasterizer.image(of: page, scale: strongDPI / 72),
                      let image = ImageEncoding.jpegImage(bitmap, quality: strongQuality) else {
                    throw ToolError.corruptedFile(fileName: fileName)
                }
                var mediaBox = CGRect(origin: .zero, size: PDFRedraw.displaySize(of: page))
                let boxData = withUnsafeBytes(of: &mediaBox) { Data($0) } as CFData
                context.beginPDFPage([kCGPDFContextMediaBox: boxData] as CFDictionary)
                context.draw(image, in: mediaBox)
                context.endPDFPage()
            }
            progress(index + 1)
        }
        context.closePDF()
    }
}
