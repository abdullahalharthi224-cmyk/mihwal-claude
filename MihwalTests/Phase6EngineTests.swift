import CoreText
import PDFKit
import XCTest
@testable import Mihwal

final class Phase6EngineTests: XCTestCase {
    private func imported(_ url: URL) throws -> ImportedFile {
        try TestFixtures.imported(url)
    }

    // MARK: Word (.docx)

    func testParagraphsJoinWrappedLinesAndKeepTitles() {
        let text = """
        Introduction
        This is a long line of a paragraph that wraps onto the next
        line and ends here.
        Second paragraph starts on its own line.

        1. First item
        2. Second item
        """
        XCTAssertEqual(DocxWriter.paragraphs(from: text), [
            "Introduction",
            "This is a long line of a paragraph that wraps onto the next line and ends here.",
            "Second paragraph starts on its own line.",
            "1. First item",
            "2. Second item",
        ])
    }

    func testDirectionAndRuns() {
        XCTAssertTrue(DocxWriter.isRightToLeft("  2026 مرحبا Mihwal"))
        XCTAssertFalse(DocxWriter.isRightToLeft("Mihwal مرحبا"))
        let runs = DocxWriter.runs("مرحبا 2026 Mihwal app")
        XCTAssertEqual(runs.map(\.rtl), [true, false])
        XCTAssertEqual(runs.first?.text, "مرحبا 2026 ", "Digits and spaces stay with the Arabic run")
        XCTAssertEqual(DocxWriter.escape("a<b>&\u{0007}\"c'"), "a&lt;b&gt;&amp;&quot;c&apos;", "Control characters are dropped")
    }

    func testDocxPackageIsCompleteAndWellFormed() throws {
        let url = try TestFixtures.scratchDirectory().appendingPathComponent("t.docx")
        try DocxWriter.write(pages: [["مرحبا بكم في Mihwal", "Hello & welcome"], ["Page two"]], to: url)
        let entries = TestFixtures.zipEntries(try Data(contentsOf: url))
        XCTAssertEqual(Set(entries.keys), ["[Content_Types].xml", "_rels/.rels", "word/_rels/document.xml.rels",
                                           "word/styles.xml", "word/document.xml"])
        for (name, data) in entries {
            let parser = XMLParser(data: data)
            XCTAssertTrue(parser.parse(), "\(name) is not well-formed XML: \(String(describing: parser.parserError))")
        }
        let document = String(decoding: try XCTUnwrap(entries["word/document.xml"]), as: UTF8.self)
        XCTAssertTrue(document.contains("<w:p><w:pPr><w:bidi/></w:pPr><w:r><w:rPr><w:rtl/></w:rPr>"),
                      "The Arabic paragraph is right-to-left")
        XCTAssertTrue(document.contains("Hello &amp; welcome"))
        XCTAssertEqual(document.components(separatedBy: "w:type=\"page\"").count - 1, 1, "One page break between two pages")
    }

    func testPDFToWordConvertsTheSampleText() async throws {
        let file = try imported(try TestFixtures.sample("1-metadata.pdf"))
        let output = try await PDFToWordEngine().run(input: ToolInput(files: [file]), options: .init()) { _ in }
        let url = try XCTUnwrap(output.files.first)
        XCTAssertEqual(url.pathExtension, "docx")
        let entries = TestFixtures.zipEntries(try Data(contentsOf: url))
        let document = String(decoding: try XCTUnwrap(entries["word/document.xml"]), as: UTF8.self)
        XCTAssertTrue(document.contains("Mihwal sample - page 1 of 3"))
        XCTAssertTrue(document.contains("Mihwal sample - page 3 of 3"))
        XCTAssertEqual(document.components(separatedBy: "w:type=\"page\"").count - 1, 2)
    }

    // MARK: Text (with OCR)

    func testPDFToTextUsesTheTextLayerWithoutOCR() async throws {
        let file = try imported(try TestFixtures.sample("6-ten-pages.pdf"))
        let output = try await PDFToTextEngine().run(input: ToolInput(files: [file]), options: .init()) { _ in }
        let text = try String(contentsOf: try XCTUnwrap(output.files.first), encoding: .utf8)
        XCTAssertTrue(text.contains("Mihwal sample - page 10 of 10"))
        XCTAssertTrue(output.notes.isEmpty, "No OCR was needed: \(output.notes)")
        XCTAssertEqual(output.copyableText, text)
    }

    func testOCRIsUsedOnlyForPagesWithoutTextAndThoseAreNamed() throws {
        // Page 1 has real text, page 2 is a picture of text.
        let url = try TestFixtures.makeScannedPDF(text: "HELLO MIHWAL", pages: 2, textPages: [0])
        let document = try XCTUnwrap(PDFDocument(url: url))
        let pages = try PDFTextExtractor.extract(from: document)
        XCTAssertEqual(pages.map(\.usedOCR), [false, true])
        XCTAssertTrue(pages[0].text.contains("Real text layer"))
        XCTAssertTrue(pages[1].text.uppercased().contains("HELLO"), "OCR read: \(pages[1].text)")
        XCTAssertEqual(PDFTextExtractor.pageList(pages), "2")
        XCTAssertTrue(PDFTextExtractor.notes(for: pages).first?.contains("2") == true)
    }

    func testPresentationFormsBecomeNormalArabic() {
        // "سلام" stored as presentation forms (letter shapes), as some PDFs do.
        let shapes = "\u{FEB3}\u{FEE0}\u{FE8E}\u{FEE1}"
        XCTAssertEqual(PDFTextExtractor.normalize(shapes), "سلام")
    }

    // MARK: Text to PDF

    private func lineOrigins(_ text: String, width: CGFloat = 500) -> (lines: [CTLine], origins: [CGPoint]) {
        let attributed = TextToPDFEngine.attributedText(text, fontSize: 20)
        let framesetter = CTFramesetterCreateWithAttributedString(attributed as CFAttributedString)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0),
                                             CGPath(rect: CGRect(x: 0, y: 0, width: width, height: 400), transform: nil), nil)
        let lines = (CTFrameGetLines(frame) as? [CTLine]) ?? []
        var origins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &origins)
        return (lines, origins)
    }

    private func runX(_ line: CTLine, isArabic: Bool, in text: String) -> CGFloat? {
        let characters = Array(text.utf16)
        for run in (CTLineGetGlyphRuns(line) as? [CTRun]) ?? [] {
            let start = CTRunGetStringRange(run).location
            guard start < characters.count else { continue }
            let arabic = (0x0600...0x06FF).contains(Int(characters[start]))
            guard arabic == isArabic else { continue }
            var position = CGPoint.zero
            CTRunGetPositions(run, CFRange(location: 0, length: 1), &position)
            return position.x
        }
        return nil
    }

    func testArabicParagraphsAreRightAlignedAndEnglishLeftAligned() {
        let arabic = lineOrigins("مرحبا")
        let english = lineOrigins("Hello")
        let arabicWidth = CTLineGetTypographicBounds(arabic.lines[0], nil, nil, nil)
        XCTAssertEqual(Double(arabic.origins[0].x) + arabicWidth, 500, accuracy: 2, "Arabic line ends at the right edge")
        XCTAssertEqual(Double(english.origins[0].x), 0, accuracy: 2, "English line starts at the left edge")
    }

    func testMixedLinesKeepTheRightOrder() {
        // Arabic first: the paragraph is right-to-left, so the Arabic word is on the right.
        let arabicFirst = "مرحبا Mihwal"
        let line1 = lineOrigins(arabicFirst).lines[0]
        let arabicX1 = runX(line1, isArabic: true, in: arabicFirst) ?? -1
        let latinX1 = runX(line1, isArabic: false, in: arabicFirst) ?? -1
        XCTAssertGreaterThan(arabicX1, latinX1)

        // English first: left-to-right, so the English word is on the left.
        let englishFirst = "Mihwal مرحبا"
        let line2 = lineOrigins(englishFirst).lines[0]
        let arabicX2 = runX(line2, isArabic: true, in: englishFirst) ?? -1
        let latinX2 = runX(line2, isArabic: false, in: englishFirst) ?? -1
        XCTAssertLessThan(latinX2, arabicX2)
    }

    func testLongArabicTextFlowsAcrossPagesWithoutLosingAnything() async throws {
        let paragraph = "هذه فقرة عربية طويلة لاختبار التفاف النص من سطر إلى سطر ومن صفحة إلى صفحة في مِحوَل، ومعها كلمات English في الوسط."
        var options = TextToPDFEngine.Options()
        options.text = "START\n" + Array(repeating: paragraph, count: 60).joined(separator: "\n") + "\nEND"
        let output = try await TextToPDFEngine().run(input: ToolInput(files: []), options: options) { _ in }
        let document = try XCTUnwrap(PDFDocument(url: try XCTUnwrap(output.files.first)))
        XCTAssertGreaterThan(document.pageCount, 1)
        XCTAssertTrue(document.page(at: 0)?.string?.contains("START") == true)
        XCTAssertTrue(document.page(at: document.pageCount - 1)?.string?.contains("END") == true, "Last line is not lost")
        let raw = document.page(at: 0)?.string ?? ""
        let firstPage = PDFTextExtractor.normalize(raw)
        // On failure, show exactly what PDFKit extracted (code points too), to see why.
        let sample = String(firstPage.prefix(120))
        let codes = raw.unicodeScalars.prefix(40).map { String(format: "%04X", $0.value) }.joined(separator: " ")
        XCTAssertTrue(firstPage.contains("فقرة"),
                      "Arabic should be real, searchable text. Extracted: «\(sample)» codes: \(codes)")
    }

    func testTextToPDFNeedsText() async throws {
        do {
            _ = try await TextToPDFEngine().run(input: ToolInput(files: []), options: .init()) { _ in }
            XCTFail("Expected nothingToDo")
        } catch let error as ToolError {
            guard case .nothingToDo = error else { return XCTFail("Got \(error)") }
        }
    }

    func testTextFileReaderHandlesUTF8AndWindowsArabic() throws {
        let folder = try TestFixtures.scratchDirectory()
        let utf8 = folder.appendingPathComponent("u.txt")
        try "مرحبا Mihwal".write(to: utf8, atomically: true, encoding: .utf8)
        XCTAssertEqual(try TextFileReader.read(utf8), "مرحبا Mihwal")

        let cp1256 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.windowsArabic.rawValue)))
        let legacy = folder.appendingPathComponent("w.txt")
        try XCTUnwrap("مرحبا".data(using: cp1256)).write(to: legacy)
        XCTAssertEqual(try TextFileReader.read(legacy), "مرحبا")
    }

    // MARK: Images to PDF

    func testImagesToPDFKeepsOrderOrientationAndPaper() async throws {
        let landscape = try imported(try ImageFixtures.write(try ImageFixtures.splitCGImage(width: 400, height: 200),
                                                             type: .png, name: "wide.png"))
        // Stored sideways (EXIF 6): upright it is portrait with red on top.
        let camera = try imported(try ImageFixtures.write(try ImageFixtures.splitCGImage(width: 400, height: 200),
                                                          type: .jpeg, name: "camera.jpg", orientation: 6))
        let output = try await ImagesToPDFEngine().run(input: ToolInput(files: [landscape, camera]),
                                                       options: .init(pageSize: .a4, margin: .none)) { _ in }
        let document = try XCTUnwrap(PDFDocument(url: try XCTUnwrap(output.files.first)))
        XCTAssertEqual(document.pageCount, 2)
        let first = try XCTUnwrap(document.page(at: 0)).bounds(for: .mediaBox).size
        let second = try XCTUnwrap(document.page(at: 1)).bounds(for: .mediaBox).size
        XCTAssertEqual(first.width, 841.89, accuracy: 1, "Landscape photo → landscape A4")
        XCTAssertEqual(second.height, 841.89, accuracy: 1, "Portrait photo → portrait A4")

        let picture = try XCTUnwrap(PDFRasterizer.image(of: try XCTUnwrap(document.page(at: 1)), scale: 0.5))
        XCTAssertTrue(ImageFixtures.isRed(try ImageFixtures.pixel(picture, x: picture.width / 2, y: picture.height / 4)),
                      "Camera photo is upright: red on top")
    }

    func testFitPhotoPagesTakeThePhotoShapeWithMargins() async throws {
        let wide = try imported(try ImageFixtures.write(try ImageFixtures.splitCGImage(width: 600, height: 300),
                                                        type: .png, name: "w.png"))
        let output = try await ImagesToPDFEngine().run(input: ToolInput(files: [wide]),
                                                       options: .init(pageSize: .fitImage, margin: .small)) { _ in }
        let page = try XCTUnwrap(PDFDocument(url: try XCTUnwrap(output.files.first))?.page(at: 0))
        let size = page.bounds(for: .mediaBox).size
        let margin = ImagesToPDFEngine.Margin.small.points * 2
        XCTAssertEqual((size.width - margin) / (size.height - margin), 2, accuracy: 0.02)
    }

    // MARK: PDF to images

    func testPDFToImagesSizesFormatsAndSelection() async throws {
        let file = try imported(try TestFixtures.makePDF(pageWidths: [200, 250, 300], name: "book.pdf"))
        let all = try await PDFToImagesEngine().run(input: ToolInput(files: [file]),
                                                    options: .init(format: .jpeg, resolution: .standard)) { _ in }
        XCTAssertEqual(all.files.count, 3)
        XCTAssertTrue(all.isAllImages)
        let first = try ImageFixtures.read(all.files[0]).image
        XCTAssertEqual(first.width, Int((200.0 * 150 / 72).rounded()), "Width at 150 dpi")
        XCTAssertEqual(first.height, Int((300.0 * 150 / 72).rounded()))

        let one = try await PDFToImagesEngine().run(input: ToolInput(files: [file]),
                                                    options: .init(format: .png, resolution: .screen, pages: [1])) { _ in }
        XCTAssertEqual(one.files.count, 1)
        XCTAssertEqual(one.files[0].pathExtension, "png")
        XCTAssertTrue(one.files[0].lastPathComponent.contains(PDFToImagesEngine.pageLabel(2)))
        XCTAssertEqual(try ImageFixtures.read(one.files[0]).image.width, 250)
    }
}
