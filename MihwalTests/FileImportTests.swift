import UIKit
import XCTest
@testable import Mihwal

/// The import path from the Files picker into a tool. These tests exist because importing
/// once failed silently on device: every outcome must either add the file or set `importError`.
@MainActor
final class FileImportTests: XCTestCase {
    func testDocumentPickerForwardsPickedURLsAndCancel() {
        var received: [URL]?
        let picker = DocumentPicker(contentTypes: [.pdf], allowsMultipleSelection: false) { received = $0 }
        let coordinator = picker.makeCoordinator()
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf], asCopy: true)
        let url = URL(fileURLWithPath: "/tmp/picked.pdf")

        coordinator.documentPicker(controller, didPickDocumentsAt: [url])
        XCTAssertEqual(received, [url])

        coordinator.documentPickerWasCancelled(controller)
        XCTAssertEqual(received, [])
    }

    func testPickedPDFIsAddedToTheTool() async throws {
        let model = FileListModel(accepts: [.pdf], allowsMultiple: false)
        model.importURLs([try TestFixtures.makePDF(pageWidths: [100, 200], name: "picked.pdf")], deleteSources: true)
        XCTAssertTrue(model.isImporting)

        try await waitUntil { !model.isImporting }
        XCTAssertNil(model.importError)
        XCTAssertEqual(model.files.count, 1)
        XCTAssertEqual(model.files.first?.name, "picked.pdf")
        XCTAssertEqual(model.files.first?.pageCount, 2)
    }

    func testPickerCopyIsDeletedButImportedFileStays() async throws {
        let source = try TestFixtures.makePDF(pageWidths: [100], name: "copy.pdf")
        let model = FileListModel(accepts: [.pdf], allowsMultiple: false)
        model.importURLs([source], deleteSources: true)
        try await waitUntil { !model.isImporting }

        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path), "Picker copy should be cleaned up")
        let imported = try XCTUnwrap(model.files.first)
        XCTAssertTrue(FileManager.default.fileExists(atPath: imported.url.path))
    }

    func testMissingFileReportsAnErrorInsteadOfFailingSilently() async throws {
        let model = FileListModel(accepts: [.pdf], allowsMultiple: false)
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).pdf")
        model.importURLs([missing])
        try await waitUntil { !model.isImporting }

        XCTAssertTrue(model.files.isEmpty)
        XCTAssertNotNil(model.importError, "A failed copy must be reported")
    }

    func testWrongFileTypeIsReported() async throws {
        let model = FileListModel(accepts: [.pdf], allowsMultiple: false)
        model.importURLs([try TestFixtures.makePNG(width: 4, height: 4, name: "photo.png")])
        try await waitUntil { !model.isImporting }

        XCTAssertTrue(model.files.isEmpty)
        XCTAssertEqual(model.importError, .unsupportedFormat(fileName: "photo.png"))
    }

    func testSingleFileToolReplacesThePreviousFile() async throws {
        let model = FileListModel(accepts: [.pdf], allowsMultiple: false)
        model.importURLs([try TestFixtures.makePDF(pageWidths: [100], name: "first.pdf")])
        try await waitUntil { !model.isImporting }
        model.importURLs([try TestFixtures.makePDF(pageWidths: [100], name: "second.pdf")])
        try await waitUntil { !model.isImporting }

        XCTAssertEqual(model.files.map(\.name), ["second.pdf"])
    }

    func testMultiFileToolKeepsOrderAndCanReorder() async throws {
        let model = FileListModel(accepts: [.pdf], allowsMultiple: true)
        let urls = try ["a.pdf", "b.pdf", "c.pdf"].map { try TestFixtures.makePDF(pageWidths: [100], name: $0) }
        model.importURLs(urls)
        try await waitUntil { !model.isImporting }
        XCTAssertEqual(model.files.map(\.name), ["a.pdf", "b.pdf", "c.pdf"])

        model.move(fromOffsets: IndexSet(integer: 2), toOffset: 0)
        XCTAssertEqual(model.files.map(\.name), ["c.pdf", "a.pdf", "b.pdf"])
    }

    func testLockedPDFCanBeUnlockedWithItsPassword() async throws {
        let model = FileListModel(accepts: [.pdf], allowsMultiple: false)
        model.importURLs([try TestFixtures.makeEncryptedPDF(password: "1234")])
        try await waitUntil { !model.isImporting }
        let file = try XCTUnwrap(model.files.first)
        XCTAssertFalse(model.isUnlocked(file))

        XCTAssertEqual(model.unlock(file.id, password: "0000"), .wrongPassword)
        XCTAssertEqual(model.unlock(file.id, password: "1234"), .unlocked)
        let unlocked = try XCTUnwrap(model.files.first)
        XCTAssertTrue(model.isUnlocked(unlocked))
        XCTAssertEqual(unlocked.pageCount, 2)
        XCTAssertEqual(model.input.password(for: unlocked), "1234")
    }

    func testOpenPasswordThenOwnerPasswordAreAskedInTurn() async throws {
        let model = FileListModel(accepts: [.pdf], allowsMultiple: false)
        model.importURLs([try TestFixtures.makeLockedAndRestrictedPDF(open: "1111", owner: "2222")])
        try await waitUntil { !model.isImporting }
        let file = try XCTUnwrap(model.files.first)
        XCTAssertTrue(file.isLocked)

        XCTAssertEqual(model.unlock(file.id, password: "0000"), .wrongPassword)
        XCTAssertEqual(model.unlock(file.id, password: "1111"), .needsOwnerPassword,
                       "Opens, but changing it needs the owner password")
        XCTAssertEqual(model.input.password(for: file), "1111", "Kept so thumbnails can show")
        XCTAssertEqual(model.unlock(file.id, password: "1111"), .needsOwnerPassword)
        XCTAssertEqual(model.unlock(file.id, password: "2222"), .unlocked)
        XCTAssertEqual(model.input.password(for: file), "2222")
        XCTAssertNoThrow(try PDFLoader.open(file, password: "2222"))
    }

    func testRestrictedOnlyPDFAsksForTheOwnerPassword() async throws {
        let model = FileListModel(accepts: [.pdf], allowsMultiple: false)
        model.importURLs([try TestFixtures.makeRestrictedPDF(ownerPassword: "owner")])
        try await waitUntil { !model.isImporting }
        let file = try XCTUnwrap(model.files.first)
        XCTAssertEqual(model.unlock(file.id, password: "nope"), .needsOwnerPassword)
        XCTAssertNil(model.input.password(for: file))
        XCTAssertEqual(model.unlock(file.id, password: "owner"), .unlocked)
    }
}
