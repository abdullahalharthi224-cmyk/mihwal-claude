import XCTest
@testable import Mihwal

final class FileStoreTests: XCTestCase {
    func testImportCopiesAndInspectsPDF() throws {
        let source = try TestFixtures.makePDF(pageWidths: [100, 200, 300], name: "report.pdf")
        let file = try TestFixtures.imported(source)

        XCTAssertNotEqual(file.url, source, "The app must work on its own copy")
        XCTAssertTrue(file.url.path.hasPrefix(FileStore.inputsDirectory.path))
        XCTAssertEqual(file.name, "report.pdf")
        XCTAssertEqual(file.baseName, "report")
        XCTAssertTrue(file.isPDF)
        XCTAssertEqual(file.pageCount, 3)
        XCTAssertFalse(file.isLocked)
        XCTAssertGreaterThan(file.byteCount, 0)
    }

    func testImportDetectsLockedPDF() throws {
        let file = try TestFixtures.imported(try TestFixtures.makeEncryptedPDF(password: "1234"))
        XCTAssertTrue(file.isLocked)
        XCTAssertNil(file.pageCount)
    }

    func testImportDetectsImage() throws {
        let file = try TestFixtures.imported(try TestFixtures.makePNG(width: 10, height: 10))
        XCTAssertTrue(file.isImage)
        XCTAssertFalse(file.isPDF)
        XCTAssertTrue(file.accepted(by: [.image]))
        XCTAssertFalse(file.accepted(by: [.pdf]))
    }

    func testOutputURLAvoidsOverwriting() throws {
        let folder = try FileStore.makeOutputDirectory()
        let first = FileStore.outputURL(in: folder, baseName: "doc", suffix: "reversed", pathExtension: "pdf")
        XCTAssertEqual(first.lastPathComponent, "doc (reversed).pdf")
        try Data().write(to: first)
        let second = FileStore.outputURL(in: folder, baseName: "doc", suffix: "reversed", pathExtension: "pdf")
        XCTAssertEqual(second.lastPathComponent, "doc (reversed) 2.pdf")
    }

    func testOutputDirectoryIsRemovedWhenWorkFails() throws {
        var createdFolder: URL?
        XCTAssertThrowsError(try FileStore.withOutputDirectory { folder -> Void in
            createdFolder = folder
            throw ToolError.writeFailed
        })
        let folder = try XCTUnwrap(createdFolder)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
    }

    func testInboxDetection() {
        XCTAssertTrue(FileStore.isInboxFile(URL(fileURLWithPath: "/var/app/Documents/Inbox/a.pdf")))
        XCTAssertFalse(FileStore.isInboxFile(URL(fileURLWithPath: "/var/app/tmp/Inputs/x/a.pdf")))
    }
}
