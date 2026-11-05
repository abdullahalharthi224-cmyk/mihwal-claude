import CoreGraphics
import CoreText
import Foundation
import UIKit

/// Typed or imported text to a PDF. Core Text lays it out: Arabic letters are shaped,
/// each paragraph takes its direction from its first letter (Arabic → right to left),
/// mixed Arabic/English lines follow the Unicode bidi rules, and text flows across pages.
struct TextToPDFEngine: FileTool {
    enum PageSize: String, Hashable, Sendable, CaseIterable {
        case a4, letter

        var size: CGSize {
            switch self {
            case .a4: return CGSize(width: 595.28, height: 841.89)
            case .letter: return CGSize(width: 612, height: 792)
            }
        }
    }

    enum Margin: String, Hashable, Sendable, CaseIterable {
        case narrow, normal, wide

        var points: CGFloat {
            switch self {
            case .narrow: return 36
            case .normal: return 56
            case .wide: return 80
            }
        }
    }

    struct Options: Sendable, Hashable {
        var text = ""
        var pageSize: PageSize = .a4
        var fontSize: Double = 14
        var margin: Margin = .normal
    }

    static func attributedText(_ text: String, fontSize: CGFloat) -> NSAttributedString {
        let font = CTFontCreateUIFontForLanguage(.system, fontSize, nil)
            ?? CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .natural
        paragraph.baseWritingDirection = .natural
        paragraph.lineHeightMultiple = 1.25
        paragraph.paragraphSpacing = fontSize * 0.6
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        return NSAttributedString(string: normalized, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1),
            .paragraphStyle: paragraph,
        ])
    }

    /// Lays the text out page by page until all of it is placed. Returns the page count.
    @discardableResult
    static func write(_ text: NSAttributedString, options: Options, to consumer: CGDataConsumer,
                      progress: (Double) -> Void = { _ in }) throws -> Int {
        var mediaBox = CGRect(origin: .zero, size: options.pageSize.size)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw ToolError.writeFailed
        }
        let framesetter = CTFramesetterCreateWithAttributedString(text as CFAttributedString)
        let path = CGPath(rect: mediaBox.insetBy(dx: options.margin.points, dy: options.margin.points), transform: nil)
        let length = text.length
        var location = 0
        var pages = 0
        repeat {
            try Task.checkCancellation()
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: location, length: 0), path, nil)
            context.beginPDFPage(nil)
            context.textMatrix = .identity
            CTFrameDraw(frame, context)
            context.endPDFPage()
            pages += 1
            let visible = CTFrameGetVisibleStringRange(frame)
            // Nothing fits on a page (impossibly large text): stop instead of looping forever.
            guard visible.length > 0 else { break }
            location += visible.length
            progress(Double(location) / Double(max(1, length)))
        } while location < length
        context.closePDF()
        return pages
    }

    func run(input: ToolInput, options: Options,
             progress: @escaping @Sendable (Double) -> Void) async throws -> ToolOutput {
        let text = options.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            throw ToolError.nothingToDo(reason: String(localized: "Type or import some text first."))
        }
        let attributed = Self.attributedText(text, fontSize: CGFloat(options.fontSize))
        let baseName = input.files.first?.baseName ?? String(localized: "Text document")

        return try FileStore.withOutputDirectory { folder -> ToolOutput in
            let url = FileStore.outputURL(in: folder, baseName: baseName, suffix: nil, pathExtension: "pdf")
            guard let consumer = CGDataConsumer(url: url as CFURL) else { throw ToolError.writeFailed }
            try Self.write(attributed, options: options, to: consumer) { progress($0 * 0.98) }
            progress(1)
            return ToolOutput(directory: folder, files: [url])
        }
    }
}

enum TextFileReader {
    /// Reads a .txt file. Order matters: automatic detection would happily "succeed" with
    /// the wrong encoding, so the likely ones are tried explicitly:
    /// UTF-16 (byte-order mark) → UTF-8 → Windows Arabic (cp1256, old Arabic files) → Latin-1.
    static func read(_ url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]),
           let text = String(data: data, encoding: .utf16) {
            return text
        }
        if var text = String(data: data, encoding: .utf8) {
            if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
            return text
        }
        let arabic = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.windowsArabic.rawValue)))
        if let text = String(data: data, encoding: arabic) {
            return text
        }
        if let text = String(data: data, encoding: .isoLatin1) {
            return text
        }
        throw ToolError.unsupportedFormat(fileName: url.lastPathComponent)
    }
}
