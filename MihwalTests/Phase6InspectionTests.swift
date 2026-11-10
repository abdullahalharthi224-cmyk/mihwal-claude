import CoreGraphics
import PDFKit
import UIKit
import XCTest
@testable import Mihwal

/// Runs the Phase 6 tools on realistic Arabic/English input and saves the real outputs
/// (plus pictures of the pages as iOS draws them) to build/test-outputs, which CI uploads,
/// so they can be inspected outside the simulator with independent tools.
final class Phase6InspectionTests: XCTestCase {
    private static var outputFolder: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("build/test-outputs", isDirectory: true)
    }

    private var report: [String: Any] = [:]

    private func keep(_ url: URL, as name: String) throws {
        try FileManager.default.createDirectory(at: Self.outputFolder, withIntermediateDirectories: true)
        let destination = Self.outputFolder.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.copyItem(at: url, to: destination)
    }

    private func keepPicture(of document: PDFDocument, page: Int, as name: String) throws {
        let pdfPage = try XCTUnwrap(document.page(at: page))
        let image = try XCTUnwrap(PDFRasterizer.image(of: pdfPage, scale: 1.5))
        let url = try TestFixtures.scratchDirectory().appendingPathComponent(name)
        try ImageWriter.write(image, to: url, format: .png, quality: 1, sourceProperties: [:], removeLocation: true)
        try keep(url, as: name)
    }

    private static let arabicText = """
    مِحوَل: أدوات PDF والصور على جهازك
    هذا نص عربي طويل لاختبار التفاف الأسطر من سطر إلى سطر داخل الصفحة، وفيه كلمات إنجليزية مثل iPhone و PDF في وسط الجملة، وأرقام مثل 2026 و١٤٤٨، وعلامات ترقيم: (قوسان) و«علامتا تنصيص» وفاصلة، ونقطة.
    Mihwal is an iPhone app. This English paragraph should run left to right, with Arabic words like مرحبا inside it.
    • نقطة أولى في قائمة
    • نقطة ثانية فيها رقم 3.5 ونسبة 50%
    """

    func testWritePhase6OutputsForInspection() async throws {
        let long = Self.arabicText + "\n" + Array(repeating: Self.arabicText, count: 6).joined(separator: "\n")

        // 1) Text to PDF
        var textOptions = TextToPDFEngine.Options()
        textOptions.text = long
        let textPDF = try await TextToPDFEngine().run(input: ToolInput(files: []), options: textOptions) { _ in }
        let textPDFURL = try XCTUnwrap(textPDF.files.first)
        let textDocument = try XCTUnwrap(PDFDocument(url: textPDFURL))
        try keep(textPDFURL, as: "1-text-to-pdf.pdf")
        try keepPicture(of: textDocument, page: 0, as: "1-text-to-pdf-page1.png")
        report["textToPDF.pages"] = textDocument.pageCount
        report["textToPDF.page1.pdfkitText"] = String(PDFTextExtractor.normalize(textDocument.page(at: 0)?.string ?? "").prefix(400))

        // 2) PDF to Word, from that Arabic PDF
        let source = try TestFixtures.imported(textPDFURL)
        let word = try await PDFToWordEngine().run(input: ToolInput(files: [source]), options: .init()) { _ in }
        try keep(try XCTUnwrap(word.files.first), as: "2-pdf-to-word.docx")
        report["pdfToWord.notes"] = word.notes

        // 3) PDF to Text, same PDF
        let text = try await PDFToTextEngine().run(input: ToolInput(files: [source]), options: .init()) { _ in }
        try keep(try XCTUnwrap(text.files.first), as: "3-pdf-to-text.txt")
        report["pdfToText.notes"] = text.notes

        // 4) OCR on a page that is only a picture of Arabic + English text
        let scanned = try TestFixtures.makeScannedPDF(text: "مرحبا بكم Mihwal 2026", pages: 1)
        let scannedDocument = try XCTUnwrap(PDFDocument(url: scanned))
        try keep(scanned, as: "4-ocr-input.pdf")
        try keepPicture(of: scannedDocument, page: 0, as: "4-ocr-input-page1.png")
        let ocr = try await PDFToTextEngine().run(input: ToolInput(files: [try TestFixtures.imported(scanned)]),
                                                  options: .init()) { _ in }
        try keep(try XCTUnwrap(ocr.files.first), as: "4-ocr-output.txt")
        report["ocr.languages"] = PDFTextExtractor.ocrLanguages()
        report["ocr.notes"] = ocr.notes

        // 5) Images to PDF (camera photo stored sideways + transparent PNG)
        let photos = try ["photo.jpg", "logo.png"].map { try TestFixtures.imported(try TestFixtures.sample($0)) }
        let imagesPDF = try await ImagesToPDFEngine().run(input: ToolInput(files: photos), options: .init()) { _ in }
        let imagesURL = try XCTUnwrap(imagesPDF.files.first)
        let imagesDocument = try XCTUnwrap(PDFDocument(url: imagesURL))
        try keep(imagesURL, as: "5-images-to-pdf.pdf")
        try keepPicture(of: imagesDocument, page: 0, as: "5-images-to-pdf-page1.png")
        try keepPicture(of: imagesDocument, page: 1, as: "5-images-to-pdf-page2.png")
        report["imagesToPDF.pageSizes"] = (0..<imagesDocument.pageCount).compactMap {
            imagesDocument.page(at: $0).map { "\(Int($0.bounds(for: .mediaBox).width))x\(Int($0.bounds(for: .mediaBox).height))" }
        }

        // 6) PDF to Images (first page of the Arabic PDF, and a sample)
        let pictures = try await PDFToImagesEngine().run(input: ToolInput(files: [source]),
                                                         options: .init(format: .jpeg, resolution: .standard, pages: [0])) { _ in }
        try keep(try XCTUnwrap(pictures.files.first), as: "6-pdf-to-images-page1.jpg")

        let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        let reportURL = try TestFixtures.scratchDirectory().appendingPathComponent("report.json")
        try data.write(to: reportURL)
        try keep(reportURL, as: "report.json")
    }
}
