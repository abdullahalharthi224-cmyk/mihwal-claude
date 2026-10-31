import CoreText
import PDFKit
import XCTest
@testable import Mihwal

final class Phase5EngineTests: XCTestCase {
    private func imported(_ url: URL) throws -> ImportedFile {
        try TestFixtures.imported(url)
    }

    private func expectNothingToDo(_ work: () async throws -> ToolOutput,
                                   file: StaticString = #filePath, line: UInt = #line) async {
        do {
            _ = try await work()
            XCTFail("Expected nothingToDo", file: file, line: line)
        } catch let error as ToolError {
            guard case .nothingToDo = error else { return XCTFail("Got \(error)", file: file, line: line) }
        } catch {
            XCTFail("Unexpected \(error)", file: file, line: line)
        }
    }

    // MARK: Redraw pipeline

    /// What the user sees must not change when pages are redrawn, also for rotated pages.
    func testRedrawKeepsWhatTheUserSeesForEveryRotation() throws {
        for rotation in [0, 90, 180, 270] {
            let source = try XCTUnwrap(PDFDocument(url: try TestFixtures.makeColoredPDF(rotation: rotation,
                                                                                      name: "r\(rotation).pdf")))
            let out = try TestFixtures.scratchDirectory().appendingPathComponent("redrawn.pdf")
            try PDFRedraw.write(source, to: out, fileName: "x") { _, _, _ in }
            let redrawn = try XCTUnwrap(PDFDocument(url: out))
            let before = try XCTUnwrap(source.page(at: 0))
            let after = try XCTUnwrap(redrawn.page(at: 0))

            XCTAssertEqual(PDFRedraw.displaySize(of: before), PDFRedraw.displaySize(of: after), "rotation \(rotation)")
            XCTAssertEqual(after.rotation, 0, "Rotation is baked into the new page")

            let beforeImage = try XCTUnwrap(PDFRasterizer.image(of: before, scale: 0.5))
            let afterImage = try XCTUnwrap(PDFRasterizer.image(of: after, scale: 0.5))
            for (fx, fy) in [(0.2, 0.2), (0.8, 0.2), (0.2, 0.8), (0.8, 0.8)] {
                let x = Int(Double(beforeImage.width) * fx)
                let y = Int(Double(beforeImage.height) * fy)
                let a = try ImageFixtures.pixel(beforeImage, x: x, y: y)
                let b = try ImageFixtures.pixel(afterImage, x: x, y: y)
                XCTAssertEqual(ImageFixtures.isRed(a), ImageFixtures.isRed(b), "rotation \(rotation) at \(fx),\(fy)")
                XCTAssertEqual(ImageFixtures.isBlue(a), ImageFixtures.isBlue(b), "rotation \(rotation) at \(fx),\(fy)")
            }
        }
    }

    // MARK: Page numbers

    func testPageNumberLabels() {
        var options = PageNumbersEngine.Options()
        options.format = .numberOfTotal
        XCTAssertEqual(PageNumbersEngine.label(forPage: 0, pageCount: 10, options: options), "1 / 10")
        options.arabicDigits = true
        XCTAssertEqual(PageNumbersEngine.label(forPage: 2, pageCount: 10, options: options), "٣ / ١٠")
        options.format = .pageOfTotalArabic
        XCTAssertEqual(PageNumbersEngine.label(forPage: 0, pageCount: 3, options: options), "صفحة ١ من ٣")
        options.format = .pageOfTotalEnglish
        XCTAssertEqual(PageNumbersEngine.label(forPage: 1, pageCount: 3, options: options), "Page 2 of 3")

        options.format = .number
        options.arabicDigits = false
        options.skipFirstPage = true
        XCTAssertNil(PageNumbersEngine.label(forPage: 0, pageCount: 5, options: options), "Cover has no number")
        XCTAssertEqual(PageNumbersEngine.label(forPage: 1, pageCount: 5, options: options), "1")
        options.startNumber = 7
        XCTAssertEqual(PageNumbersEngine.label(forPage: 4, pageCount: 5, options: options), "10")
    }

    func testPageNumbersKeepPagesAndTextAndAddTheNumber() async throws {
        let file = try imported(try TestFixtures.makePDF(pageWidths: [300, 300, 300], name: "doc.pdf"))
        var options = PageNumbersEngine.Options()
        options.format = .numberOfTotal
        let output = try await PageNumbersEngine().run(input: ToolInput(files: [file]), options: options) { _ in }
        let document = try XCTUnwrap(PDFDocument(url: try XCTUnwrap(output.files.first)))
        XCTAssertEqual(document.pageCount, 3)
        let text = document.page(at: 1)?.string ?? ""
        // The fixture page says "Page 2"; only the stamp adds "2 / 3".
        XCTAssertTrue(text.contains("Page 2"), "Original text stays selectable: \(text)")
        XCTAssertTrue(text.contains("/ 3"), "The page number is added: \(text)")
    }

    func testPreviewIsMadeByTheSamePipeline() throws {
        let file = try imported(try TestFixtures.makePDF(pageWidths: [300], name: "p.pdf"))
        let image = try XCTUnwrap(PageNumbersEngine.previewImage(file: file, password: nil, options: .init()))
        XCTAssertGreaterThan(image.height, image.width, "Portrait page stays portrait")
    }

    // MARK: Watermark

    func testPDFWatermarkIsWrittenOnEveryPage() async throws {
        let file = try imported(try TestFixtures.makePDF(pageWidths: [300, 400], name: "w.pdf"))
        var options = WatermarkPDFEngine.Options()
        options.style.text = "سري CONFIDENTIAL"
        let output = try await WatermarkPDFEngine().run(input: ToolInput(files: [file]), options: options) { _ in }
        let document = try XCTUnwrap(PDFDocument(url: try XCTUnwrap(output.files.first)))
        XCTAssertEqual(document.pageCount, 2)
        for index in 0..<2 {
            XCTAssertTrue(document.page(at: index)?.string?.contains("CONFIDENTIAL") == true, "page \(index)")
        }
    }

    func testPDFWatermarkNeedsText() async throws {
        let file = try imported(try TestFixtures.makePDF(pageWidths: [300]))
        await expectNothingToDo {
            try await WatermarkPDFEngine().run(input: ToolInput(files: [file]), options: .init()) { _ in }
        }
    }

    // MARK: Metadata

    func testMetadataIsFoundAndRemoved() async throws {
        let file = try imported(try TestFixtures.makePDFWithMetadata())
        let source = try XCTUnwrap(PDFDocument(url: file.url))
        let found = StripMetadataEngine.foundMetadata(in: source)
        XCTAssertTrue(found.contains { $0.field == .author && $0.value == "Abdullah" })
        XCTAssertTrue(found.contains { $0.field == .title && $0.value == "Secret plan" })

        let output = try await StripMetadataEngine().run(input: ToolInput(files: [file]), options: .init()) { _ in }
        let url = try XCTUnwrap(output.files.first)
        let clean = try XCTUnwrap(PDFDocument(url: url))
        let after = StripMetadataEngine.foundMetadata(in: clean).map(\.field)
        for field in [StripMetadataEngine.Field.title, .author, .subject, .keywords] {
            XCTAssertFalse(after.contains(field), "\(field) must be gone")
        }
        XCTAssertFalse(StripMetadataEngine.hasXMP(clean), "No XMP metadata stream")
        XCTAssertEqual(clean.pageCount, 1)

        // Read the raw file too: the values must not be anywhere in it.
        let raw = String(decoding: try Data(contentsOf: url), as: UTF8.self)
        XCTAssertFalse(raw.contains("Abdullah"))
        XCTAssertFalse(raw.contains("Secret plan"))
    }

    // MARK: Owner restrictions & unlock

    func testRestrictedPDFNeedsTheOwnerPasswordInEveryTool() async throws {
        let file = try imported(try TestFixtures.makeRestrictedPDF(ownerPassword: "owner"))
        XCTAssertTrue(file.isEncrypted)
        XCTAssertFalse(file.isLocked, "It opens without a password")

        XCTAssertThrowsError(try PDFLoader.open(file, password: nil)) { error in
            XCTAssertEqual(error as? ToolError, .ownerPasswordRequired(fileID: file.id, fileName: file.name, afterAttempt: false))
        }
        XCTAssertThrowsError(try PDFLoader.open(file, password: "guess")) { error in
            XCTAssertEqual(error as? ToolError, .ownerPasswordRequired(fileID: file.id, fileName: file.name, afterAttempt: true))
        }
        XCTAssertNoThrow(try PDFLoader.open(file, password: "owner"))

        // Even a simple tool refuses without the owner password.
        do {
            _ = try await ReversePagesEngine().run(input: ToolInput(files: [file]), options: .init()) { _ in }
            XCTFail("A restricted PDF must not be processed without the owner password")
        } catch let error as ToolError {
            XCTAssertTrue(error.isPasswordProblem)
        }
    }

    func testUnlockNeedsTheRightPasswordAndRemovesProtection() async throws {
        let file = try imported(try TestFixtures.makeRestrictedPDF(ownerPassword: "owner"))
        do {
            _ = try await UnlockPDFEngine().run(input: ToolInput(files: [file]), options: .init()) { _ in }
            XCTFail("Must not unlock without the password")
        } catch let error as ToolError {
            XCTAssertTrue(error.isPasswordProblem)
        }

        let output = try await UnlockPDFEngine().run(input: ToolInput(files: [file], passwords: [file.id: "owner"]),
                                                     options: .init()) { _ in }
        let unlocked = try XCTUnwrap(PDFDocument(url: try XCTUnwrap(output.files.first)))
        XCTAssertFalse(unlocked.isEncrypted)
        XCTAssertTrue(unlocked.allowsCopying)
        XCTAssertTrue(unlocked.allowsPrinting)
        XCTAssertTrue(output.removedProtection)
    }

    func testUnlockOpenPasswordPDF() async throws {
        let file = try imported(try TestFixtures.makeEncryptedPDF(password: "1234"))
        let output = try await UnlockPDFEngine().run(input: ToolInput(files: [file], passwords: [file.id: "1234"]),
                                                     options: .init()) { _ in }
        let unlocked = try XCTUnwrap(PDFDocument(url: try XCTUnwrap(output.files.first)))
        XCTAssertFalse(unlocked.isLocked)
        XCTAssertFalse(unlocked.isEncrypted)
        XCTAssertEqual(unlocked.pageCount, 2)
    }

    func testUnlockingAnUnprotectedPDFIsNothingToDo() async throws {
        let file = try imported(try TestFixtures.makePDF(pageWidths: [100]))
        await expectNothingToDo {
            try await UnlockPDFEngine().run(input: ToolInput(files: [file]), options: .init()) { _ in }
        }
    }

    @MainActor
    func testRunnerFlagsResultsOfProtectedInputs() async throws {
        let runner = ToolRunner()
        let file = try imported(try TestFixtures.makeEncryptedPDF(password: "pw"))
        runner.run(ReversePagesEngine(), input: ToolInput(files: [file], passwords: [file.id: "pw"]), options: .init())
        try await waitUntil { !runner.isProcessing }
        XCTAssertEqual(runner.output?.removedProtection, true, "The result screen must warn before saving")

        let plain = try imported(try TestFixtures.makePDF(pageWidths: [100, 200]))
        runner.run(ReversePagesEngine(), input: ToolInput(files: [plain]), options: .init())
        try await waitUntil { !runner.isProcessing }
        XCTAssertEqual(runner.output?.removedProtection, false)
    }

    // MARK: Compress

    func testStrongCompressionShrinksAScanAndReportsSizes() async throws {
        let file = try imported(try TestFixtures.makeImageHeavyPDF())
        let output = try await CompressPDFEngine().run(input: ToolInput(files: [file]),
                                                       options: .init(level: .strong)) { _ in }
        XCTAssertEqual(output.inputBytes, file.byteCount)
        XCTAssertLessThan(output.outputBytes, file.byteCount)
        XCTAssertFalse(output.notes.isEmpty, "User is told text is no longer selectable")
        XCTAssertEqual(PDFDocument(url: try XCTUnwrap(output.files.first))?.pageCount, 1)
    }

    func testBalancedCompressionNeverReturnsABiggerFile() async throws {
        let file = try imported(try TestFixtures.makeImageHeavyPDF())
        do {
            let output = try await CompressPDFEngine().run(input: ToolInput(files: [file]),
                                                           options: .init(level: .balanced)) { _ in }
            XCTAssertLessThan(output.outputBytes, file.byteCount)
            let text = PDFDocument(url: try XCTUnwrap(output.files.first))?.pageCount
            XCTAssertEqual(text, 1)
        } catch let error as ToolError {
            guard case .nothingToDo = error else { return XCTFail("Got \(error)") }
        }
    }

    func testCompressingATinyTextPDFKeepsTheOriginal() async throws {
        // A text-only PDF is already tiny; turning pages into pictures would make it bigger.
        let file = try imported(try TestFixtures.makePDF(pageWidths: [612], name: "text.pdf"))
        await expectNothingToDo {
            try await CompressPDFEngine().run(input: ToolInput(files: [file]), options: .init(level: .strong)) { _ in }
        }
    }
}
