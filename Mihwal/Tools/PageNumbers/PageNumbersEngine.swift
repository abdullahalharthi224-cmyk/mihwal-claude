import CoreGraphics
import CoreText
import Foundation
import PDFKit

/// Stamps page numbers on every page (re-drawn, see PDFRedraw).
struct PageNumbersEngine: FileTool {
    enum Format: String, Hashable, Sendable, CaseIterable {
        case number
        case numberOfTotal
        case pageOfTotalEnglish
        case pageOfTotalArabic
    }

    enum Position: String, Hashable, Sendable, CaseIterable {
        case bottomCenter, bottomLeft, bottomRight, topCenter, topLeft, topRight
    }

    enum Size: String, Hashable, Sendable, CaseIterable {
        case small, medium, large

        /// Points on a Letter/A4-sized page; scaled with the page.
        var points: CGFloat {
            switch self {
            case .small: return 9
            case .medium: return 11
            case .large: return 15
            }
        }
    }

    struct Options: Sendable, Hashable {
        var format: Format = .numberOfTotal
        /// ٠١٢٣ instead of 0123 (the Arabic phrase always uses them).
        var arabicDigits = false
        var position: Position = .bottomCenter
        var size: Size = .medium
        var startNumber = 1
        /// Leave the cover without a number; numbering starts on page 2.
        var skipFirstPage = false
    }

    // MARK: Text

    static func digits(_ number: Int, arabic: Bool) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: arabic ? "ar@numbers=arab" : "en_US_POSIX")
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: number)) ?? String(number)
    }

    /// The text for a page, or nil when that page gets no number.
    static func label(forPage index: Int, pageCount: Int, options: Options) -> String? {
        if options.skipFirstPage && index == 0 { return nil }
        let skipped = options.skipFirstPage ? 1 : 0
        let number = options.startNumber + index - skipped
        let total = options.startNumber + pageCount - skipped - 1
        switch options.format {
        case .number:
            return digits(number, arabic: options.arabicDigits)
        case .numberOfTotal:
            return "\(digits(number, arabic: options.arabicDigits)) / \(digits(total, arabic: options.arabicDigits))"
        case .pageOfTotalEnglish:
            return "Page \(digits(number, arabic: false)) of \(digits(total, arabic: false))"
        case .pageOfTotalArabic:
            return "صفحة \(digits(number, arabic: true)) من \(digits(total, arabic: true))"
        }
    }

    static func draw(_ text: String, in context: CGContext, pageSize: CGSize, options: Options) {
        let scale = min(pageSize.width, pageSize.height) / 612
        let line = WatermarkRenderer.makeLine(text: text, fontSize: options.size.points * scale,
                                              color: CGColor(gray: 0.15, alpha: 1))
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
        let margin = 28 * scale

        let x: CGFloat
        switch options.position {
        case .bottomLeft, .topLeft: x = margin
        case .bottomRight, .topRight: x = pageSize.width - margin - width
        case .bottomCenter, .topCenter: x = (pageSize.width - width) / 2
        }
        let y: CGFloat
        switch options.position {
        case .bottomCenter, .bottomLeft, .bottomRight: y = margin
        case .topCenter, .topLeft, .topRight: y = pageSize.height - margin - ascent
        }
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, context)
    }

    // MARK: Run

    func run(input: ToolInput, options: Options,
             progress: @escaping @Sendable (Double) -> Void) async throws -> ToolOutput {
        guard let file = input.files.first else { throw ToolError.noInput }
        let document = try PDFLoader.open(file, password: input.password(for: file))
        let count = document.pageCount
        let flattens = PDFLoader.hasInteractiveContent(document)
        try StorageGuard.ensureSpace(for: file.byteCount * 2)

        return try FileStore.withOutputDirectory { folder -> ToolOutput in
            let url = FileStore.outputURL(in: folder, baseName: file.baseName,
                                          suffix: String(localized: "numbered"), pathExtension: "pdf")
            try PDFRedraw.write(document, to: url, fileName: file.name, progress: { done in
                progress(Double(done) / Double(max(1, count)))
            }) { context, size, index in
                if let text = Self.label(forPage: index, pageCount: count, options: options) {
                    Self.draw(text, in: context, pageSize: size, options: options)
                }
            }
            var output = ToolOutput(directory: folder, files: [url])
            if flattens {
                output.notes.append(String(localized: "Links, form fields and comments are now part of the pages (flattened)."))
            }
            return output
        }
    }

    /// The first numbered page, drawn by the same pipeline as the output.
    static func previewImage(file: ImportedFile, password: String?, options: Options) -> CGImage? {
        guard let document = try? PDFLoader.open(file, password: password), document.pageCount > 0 else { return nil }
        let count = document.pageCount
        let index = options.skipFirstPage && count > 1 ? 1 : 0
        return PDFRedraw.previewImage(of: document, pageIndex: index, maxPixelSize: 900) { context, size, page in
            if let text = label(forPage: page, pageCount: count, options: options) {
                draw(text, in: context, pageSize: size, options: options)
            }
        }
    }
}
