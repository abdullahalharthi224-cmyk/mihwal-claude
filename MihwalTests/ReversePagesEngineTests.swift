import PDFKit
import XCTest
@testable import Mihwal

final class ReversePagesEngineTests: XCTestCase {
    func testPagesAreReversed() async throws {
        let file = try TestFixtures.imported(try TestFixtures.makePDF(pageWidths: [100, 200, 300], name: "doc.pdf"))
        let output = try await ReversePagesEngine().run(input: ToolInput(files: [file]), options: .init()) { _ in }

        XCTAssertEqual(output.files.count, 1)
        let url = try XCTUnwrap(output.files.first)
        XCTAssertEqual(url.lastPathComponent, "doc (\(String(localized: "reversed"))).pdf")
        let document = try XCTUnwrap(PDFDocument(url: url))
        let widths = (0..<document.pageCount).compactMap { document.page(at: $0)?.bounds(for: .mediaBox).width }
        XCTAssertEqual(widths, [300, 200, 100])
    }

    func testReportsProgressUpToOne() async throws {
        let file = try TestFixtures.imported(try TestFixtures.makePDF(pageWidths: [100, 200]))
        let recorder = ProgressRecorder()
        _ = try await ReversePagesEngine().run(input: ToolInput(files: [file]), options: .init()) { recorder.record($0) }
        XCTAssertEqual(recorder.values.last, 1)
    }

    func testSinglePageIsNothingToDo() async throws {
        let file = try TestFixtures.imported(try TestFixtures.makePDF(pageWidths: [100]))
        do {
            _ = try await ReversePagesEngine().run(input: ToolInput(files: [file]), options: .init()) { _ in }
            XCTFail("Expected nothingToDo")
        } catch let error as ToolError {
            guard case .nothingToDo = error else { return XCTFail("Got \(error)") }
        }
    }

    func testLockedPDFUsesPassword() async throws {
        let file = try TestFixtures.imported(try TestFixtures.makeEncryptedPDF(password: "pw"))
        let input = ToolInput(files: [file], passwords: [file.id: "pw"])
        let output = try await ReversePagesEngine().run(input: input, options: .init()) { _ in }
        XCTAssertEqual(output.files.count, 1)
    }
}

/// Collects progress values from any thread.
final class ProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Double] = []

    var values: [Double] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func record(_ value: Double) {
        lock.lock()
        storage.append(value)
        lock.unlock()
    }
}
