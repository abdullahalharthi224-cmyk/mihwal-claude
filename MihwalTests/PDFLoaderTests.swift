import XCTest
@testable import Mihwal

final class PDFLoaderTests: XCTestCase {
    func testOpensPlainPDF() throws {
        let file = try TestFixtures.imported(try TestFixtures.makePDF(pageWidths: [100, 200]))
        XCTAssertEqual(try PDFLoader.open(file, password: nil).pageCount, 2)
    }

    func testLockedPDFWithoutPasswordAsksForIt() throws {
        let file = try TestFixtures.imported(try TestFixtures.makeEncryptedPDF(password: "1234"))
        XCTAssertThrowsError(try PDFLoader.open(file, password: nil)) { error in
            XCTAssertEqual(error as? ToolError, .passwordRequired(fileID: file.id, fileName: file.name))
        }
    }

    func testWrongPasswordIsReported() throws {
        let file = try TestFixtures.imported(try TestFixtures.makeEncryptedPDF(password: "1234"))
        XCTAssertThrowsError(try PDFLoader.open(file, password: "0000")) { error in
            XCTAssertEqual(error as? ToolError, .wrongPassword(fileID: file.id, fileName: file.name))
        }
    }

    func testCorrectPasswordUnlocks() throws {
        let file = try TestFixtures.imported(try TestFixtures.makeEncryptedPDF(password: "1234"))
        let document = try PDFLoader.open(file, password: "1234")
        XCTAssertFalse(document.isLocked)
        XCTAssertEqual(document.pageCount, 2)
    }

    func testGarbageIsReportedAsCorrupted() throws {
        let file = try TestFixtures.imported(try TestFixtures.makeGarbage(name: "broken.pdf"))
        XCTAssertThrowsError(try PDFLoader.open(file, password: nil)) { error in
            XCTAssertEqual(error as? ToolError, .corruptedFile(fileName: "broken.pdf"))
        }
    }
}
