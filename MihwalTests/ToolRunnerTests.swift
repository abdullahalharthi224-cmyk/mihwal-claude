import XCTest
@testable import Mihwal

@MainActor
final class ToolRunnerTests: XCTestCase {
    func testSuccessfulRunEndsInSuccess() async throws {
        let runner = ToolRunner()
        let file = try TestFixtures.imported(try TestFixtures.makePDF(pageWidths: [100, 200]))
        runner.run(ReversePagesEngine(), input: ToolInput(files: [file]), options: .init())
        XCTAssertTrue(runner.isProcessing)

        try await waitUntil { !runner.isProcessing }
        let output = try XCTUnwrap(runner.output)
        XCTAssertEqual(runner.successCount, 1)
        XCTAssertEqual(runner.progress, 1)

        runner.reset()
        XCTAssertFalse(FileManager.default.fileExists(atPath: output.directory.path), "reset() deletes results")
    }

    func testRunWithoutFilesFailsWithNoInput() {
        let runner = ToolRunner()
        runner.run(ReversePagesEngine(), input: ToolInput(files: []), options: .init())
        XCTAssertEqual(runner.error, .noInput)
    }

    func testLockedFileFailsWithPasswordRequired() async throws {
        let runner = ToolRunner()
        let file = try TestFixtures.imported(try TestFixtures.makeEncryptedPDF(password: "pw"))
        runner.run(ReversePagesEngine(), input: ToolInput(files: [file]), options: .init())
        try await waitUntil { !runner.isProcessing }
        XCTAssertEqual(runner.error, .passwordRequired(fileID: file.id, fileName: file.name))
    }
}
