import CoreGraphics
import Foundation
import PDFKit

/// Re-draws PDF pages into a new PDF and lets a tool draw on top (page numbers, watermark).
/// Text stays vector and selectable. Links, form fields and comments become part of the
/// page drawing (flattened), which the tools tell the user before running.
enum PDFRedraw {
    /// The page size as the user sees it (a 90° rotated page is landscape).
    static func displaySize(of page: PDFPage) -> CGSize {
        let box = page.bounds(for: .mediaBox)
        return page.rotation % 180 == 0 ? box.size : CGSize(width: box.height, height: box.width)
    }

    /// Draws a page so that it fills (0, 0, displaySize) in `context`, rotation applied.
    /// PDFPage.draw doesn't apply the page's rotation or box origin itself;
    /// transform(_:for:) does, the same way PDFView prepares a page.
    static func drawPage(_ page: PDFPage, in context: CGContext) {
        context.saveGState()
        page.transform(context, for: .mediaBox)
        page.draw(with: .mediaBox, to: context)
        context.restoreGState()
    }

    /// Writes `pages` of `document` to a new PDF. `decorate` draws on each page; it gets
    /// the context (origin bottom-left), the page size and the page's index in `document`.
    static func write(_ document: PDFDocument, pages: [Int], to consumer: CGDataConsumer, fileName: String,
                      progress: (Int) -> Void = { _ in },
                      decorate: (CGContext, CGSize, Int) -> Void) throws {
        var defaultBox = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(consumer: consumer, mediaBox: &defaultBox, nil) else {
            throw ToolError.writeFailed
        }
        for (done, index) in pages.enumerated() {
            try Task.checkCancellation()
            guard let page = document.page(at: index) else {
                throw ToolError.corruptedFile(fileName: fileName)
            }
            autoreleasepool {
                let size = displaySize(of: page)
                var mediaBox = CGRect(origin: .zero, size: size)
                let boxData = withUnsafeBytes(of: &mediaBox) { Data($0) } as CFData
                context.beginPDFPage([kCGPDFContextMediaBox: boxData] as CFDictionary)
                drawPage(page, in: context)
                context.saveGState()
                decorate(context, size, index)
                context.restoreGState()
                context.endPDFPage()
            }
            progress(done + 1)
        }
        context.closePDF()
    }

    static func write(_ document: PDFDocument, to url: URL, fileName: String,
                      progress: (Int) -> Void = { _ in },
                      decorate: (CGContext, CGSize, Int) -> Void) throws {
        guard let consumer = CGDataConsumer(url: url as CFURL) else { throw ToolError.writeFailed }
        try write(document, pages: Array(0..<document.pageCount), to: consumer, fileName: fileName,
                  progress: progress, decorate: decorate)
    }

    /// One page run through the exact same pipeline, then turned into an image: the live
    /// preview is what the tool will write.
    static func previewImage(of document: PDFDocument, pageIndex: Int, maxPixelSize: CGFloat,
                             decorate: (CGContext, CGSize, Int) -> Void) -> CGImage? {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              (try? write(document, pages: [pageIndex], to: consumer, fileName: "", decorate: decorate)) != nil,
              let preview = PDFDocument(data: data as Data),
              let page = preview.page(at: 0) else { return nil }
        let size = displaySize(of: page)
        return PDFRasterizer.image(of: page, scale: maxPixelSize / max(size.width, size.height, 1))
    }
}

enum PDFRasterizer {
    /// A page as an opaque bitmap (white paper), `scale` pixels per point.
    static func image(of page: PDFPage, scale: CGFloat) -> CGImage? {
        let size = PDFRedraw.displaySize(of: page)
        let width = Int((size.width * scale).rounded())
        let height = Int((size.height * scale).rounded())
        guard width > 0, height > 0,
              let context = ImageCanvas.context(width: width, height: height, like: nil, opaque: true) else { return nil }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.scaleBy(x: scale, y: scale)
        PDFRedraw.drawPage(page, in: context)
        return context.makeImage()
    }
}
