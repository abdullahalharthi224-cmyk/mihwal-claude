import PDFKit
import XCTest
@testable import Mihwal

/// The PDFs in samples/ are what the owner tries on the iPhone (made with pypdf, AES-128).
/// These tests run every Phase 5 case on exactly those files.
final class SampleFilesTests: XCTestCase {
    private func sample(_ name: String) throws -> ImportedFile {
        try TestFixtures.imported(try TestFixtures.sample(name))
    }

    func testStripMetadataLeavesNothingOnSample1() async throws {
        let file = try sample("1-metadata.pdf")
        let before = StripMetadataEngine.foundMetadata(in: try XCTUnwrap(PDFDocument(url: file.url)))
        XCTAssertTrue(before.contains { $0.field == .author && $0.value == "Abdullah" }, "\(before)")

        let output = try await StripMetadataEngine().run(input: ToolInput(files: [file]), options: .init()) { _ in }
        let url = try XCTUnwrap(output.files.first)
        let after = try XCTUnwrap(PDFDocument(url: url))
        XCTAssertEqual(StripMetadataEngine.foundMetadata(in: after).map { "\($0.field.rawValue)=\($0.value)" }, [])
        XCTAssertFalse(StripMetadataEngine.hasXMP(after))
        XCTAssertEqual(after.pageCount, 3)
        XCTAssertTrue(after.page(at: 0)?.string?.contains("Mihwal sample") == true, "Text unchanged")

        let raw = String(decoding: try Data(contentsOf: url), as: UTF8.self)
        for secret in ["Abdullah", "Secret plan", "Private notes", "Microsoft Word", "Sample maker"] {
            XCTAssertFalse(raw.contains(secret), "\(secret) is still in the file")
        }
    }

    func testSample2NeedsItsOpenPassword() throws {
        let file = try sample("2-password-1234.pdf")
        XCTAssertTrue(file.isLocked)
        XCTAssertThrowsError(try PDFLoader.open(file, password: "0000"))
        XCTAssertEqual(try PDFLoader.open(file, password: "1234").pageCount, 3)
    }

    func testSample3NeedsTheOwnerPassword() throws {
        let file = try sample("3-restricted-owner-5678.pdf")
        XCTAssertFalse(file.isLocked)
        XCTAssertTrue(file.isEncrypted)
        XCTAssertThrowsError(try PDFLoader.open(file, password: nil)) { error in
            XCTAssertEqual(error as? ToolError, .ownerPasswordRequired(fileID: file.id, fileName: file.name, afterAttempt: false))
        }
        XCTAssertNoThrow(try PDFLoader.open(file, password: "5678"))
    }

    func testSample4NeedsBothPasswordsInTurn() throws {
        let file = try sample("4-both-open-1111-owner-2222.pdf")
        XCTAssertTrue(file.isLocked)
        XCTAssertThrowsError(try PDFLoader.open(file, password: "1111")) { error in
            XCTAssertEqual(error as? ToolError, .ownerPasswordRequired(fileID: file.id, fileName: file.name, afterAttempt: true))
        }
        XCTAssertNoThrow(try PDFLoader.open(file, password: "2222"))
    }

    func testUnlockSamplesGivesUnprotectedCopies() async throws {
        for (name, password) in [("2-password-1234.pdf", "1234"), ("3-restricted-owner-5678.pdf", "5678"),
                                 ("4-both-open-1111-owner-2222.pdf", "2222")] {
            let file = try sample(name)
            let output = try await UnlockPDFEngine().run(input: ToolInput(files: [file], passwords: [file.id: password]),
                                                         options: .init()) { _ in }
            let copy = try XCTUnwrap(PDFDocument(url: try XCTUnwrap(output.files.first)), name)
            XCTAssertFalse(copy.isEncrypted, name)
            XCTAssertEqual(copy.pageCount, 3, name)
        }
    }

    func testSample5LinkIsDetected() throws {
        let document = try XCTUnwrap(PDFDocument(url: try TestFixtures.sample("5-with-link.pdf")))
        XCTAssertTrue(PDFLoader.hasInteractiveContent(document))
        let plain = try XCTUnwrap(PDFDocument(url: try TestFixtures.sample("6-ten-pages.pdf")))
        XCTAssertFalse(PDFLoader.hasInteractiveContent(plain))
        XCTAssertEqual(plain.pageCount, 10)
    }
}
