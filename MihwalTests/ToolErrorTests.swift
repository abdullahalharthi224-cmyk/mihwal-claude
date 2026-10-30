import XCTest
@testable import Mihwal

final class ToolErrorTests: XCTestCase {
    func testToolErrorPassesThrough() {
        XCTAssertEqual(ToolError(ToolError.writeFailed), .writeFailed)
    }

    func testOutOfSpaceBecomesNotEnoughStorage() {
        let cocoa = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError)
        XCTAssertEqual(ToolError(cocoa), .notEnoughStorage)
        let posix = NSError(domain: NSPOSIXErrorDomain, code: Int(ENOSPC))
        XCTAssertEqual(ToolError(posix), .notEnoughStorage)
    }

    func testOtherErrorsKeepTheirMessage() {
        let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Boom"])
        XCTAssertEqual(ToolError(error), .unknown(message: "Boom"))
    }

    func testEveryCaseHasTitleAndMessage() {
        let id = UUID()
        let cases: [ToolError] = [
            .noInput, .passwordRequired(fileID: id, fileName: "a.pdf"), .wrongPassword(fileID: id, fileName: "a.pdf"),
            .corruptedFile(fileName: "a.pdf"), .unsupportedFormat(fileName: "a.xyz"), .notEnoughStorage,
            .photosAccessDenied, .nothingToDo(reason: "x"), .writeFailed, .resultUnavailable, .unknown(message: "y"),
        ]
        for error in cases {
            XCTAssertFalse(error.title.isEmpty, "\(error)")
            XCTAssertFalse(error.message.isEmpty, "\(error)")
        }
        XCTAssertTrue(ToolError.passwordRequired(fileID: id, fileName: "a.pdf").message.contains("a.pdf"))
    }

    func testPasswordProblems() {
        let id = UUID()
        XCTAssertTrue(ToolError.passwordRequired(fileID: id, fileName: "a").isPasswordProblem)
        XCTAssertTrue(ToolError.wrongPassword(fileID: id, fileName: "a").isPasswordProblem)
        XCTAssertFalse(ToolError.writeFailed.isPasswordProblem)
    }
}
