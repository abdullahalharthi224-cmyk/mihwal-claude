import PDFKit
import XCTest
@testable import Mihwal

/// Rotate, delete, extract, split and merge. Sample PDFs use a different width per page,
/// so page order can be checked exactly.
final class PageToolEngineTests: XCTestCase {
    private func pdf(_ widths: [CGFloat], name: String = "doc.pdf") throws -> ImportedFile {
        try TestFixtures.imported(try TestFixtures.makePDF(pageWidths: widths, name: name))
    }

    private func widths(of url: URL) throws -> [CGFloat] {
        let document = try XCTUnwrap(PDFDocument(url: url))
        return (0..<document.pageCount).compactMap { document.page(at: $0)?.bounds(for: .mediaBox).width }
    }

    private func expectNothingToDo(_ work: () async throws -> ToolOutput,
                                   file: StaticString = #filePath, line: UInt = #line) async {
        do {
            _ = try await work()
            XCTFail("Expected nothingToDo", file: file, line: line)
        } catch let error as ToolError {
            guard case .nothingToDo = error else {
                return XCTFail("Got \(error)", file: file, line: line)
            }
        } catch {
            XCTFail("Unexpected \(error)", file: file, line: line)
        }
    }

    // MARK: Rotate

    func testRotationNormalization() {
        XCTAssertEqual(RotatePagesEngine.normalized(-90), 270)
        XCTAssertEqual(RotatePagesEngine.normalized(450), 90)
        XCTAssertEqual(RotatePagesEngine.normalized(360), 0)
    }

    func testRotatesOnlyChosenPages() async throws {
        let file = try pdf([100, 200, 300])
        let output = try await RotatePagesEngine().run(
            input: ToolInput(files: [file]), options: .init(rotations: [0: 90, 2: -90])) { _ in }
        let document = try XCTUnwrap(PDFDocument(url: try XCTUnwrap(output.files.first)))
        XCTAssertEqual(document.page(at: 0)?.rotation, 90)
        XCTAssertEqual(document.page(at: 1)?.rotation, 0)
        XCTAssertEqual(document.page(at: 2)?.rotation, 270)
    }

    func testRotateWithoutChangesIsNothingToDo() async throws {
        let file = try pdf([100, 200])
        await expectNothingToDo {
            try await RotatePagesEngine().run(input: ToolInput(files: [file]),
                                              options: .init(rotations: [0: 360, 1: 0])) { _ in }
        }
    }

    // MARK: Delete

    func testDeletesSelectedPages() async throws {
        let file = try pdf([100, 200, 300, 400])
        let output = try await DeletePagesEngine().run(
            input: ToolInput(files: [file]), options: .init(pages: [1, 3])) { _ in }
        XCTAssertEqual(try widths(of: try XCTUnwrap(output.files.first)), [100, 300])
    }

    func testCannotDeleteEveryPage() async throws {
        let file = try pdf([100, 200])
        await expectNothingToDo {
            try await DeletePagesEngine().run(input: ToolInput(files: [file]), options: .init(pages: [0, 1])) { _ in }
        }
    }

    func testDeleteWithNoSelectionIsNothingToDo() async throws {
        let file = try pdf([100, 200])
        await expectNothingToDo {
            try await DeletePagesEngine().run(input: ToolInput(files: [file]), options: .init(pages: [])) { _ in }
        }
    }

    // MARK: Extract

    func testExtractsInPageOrder() async throws {
        let file = try pdf([100, 200, 300, 400])
        let output = try await ExtractPagesEngine().run(
            input: ToolInput(files: [file]), options: .init(pages: [3, 0, 2])) { _ in }
        XCTAssertEqual(try widths(of: try XCTUnwrap(output.files.first)), [100, 300, 400])
    }

    func testExtractIgnoresPagesOutOfRange() async throws {
        let file = try pdf([100, 200])
        await expectNothingToDo {
            try await ExtractPagesEngine().run(input: ToolInput(files: [file]), options: .init(pages: [7, 9])) { _ in }
        }
    }

    // MARK: Split

    func testSplitPlans() {
        XCTAssertEqual(SplitPlan.groups(pageCount: 3, mode: .everyPage), [[0], [1], [2]])
        XCTAssertEqual(SplitPlan.groups(pageCount: 5, mode: .everyN(2)), [[0, 1], [2, 3], [4]])
        XCTAssertEqual(SplitPlan.groups(pageCount: 5, mode: .custom(starts: [3, 1])), [[0], [1, 2], [3, 4]])
        XCTAssertEqual(SplitPlan.groups(pageCount: 3, mode: .custom(starts: [0, 9])), [[0, 1, 2]],
                       "Start 0 and out-of-range starts are ignored")
        XCTAssertEqual(SplitPlan.groups(pageCount: 0, mode: .everyPage), [])
        XCTAssertEqual(SplitPlan.groups(pageCount: 3, mode: .everyN(0)), [[0], [1], [2]], "N is at least 1")
    }

    func testSplitWritesOneFilePerGroup() async throws {
        let file = try pdf([100, 200, 300, 400, 500], name: "book.pdf")
        let output = try await SplitPDFEngine().run(
            input: ToolInput(files: [file]), options: .init(groups: [[0, 1], [2], [3, 4]])) { _ in }

        XCTAssertEqual(output.files.count, 3)
        XCTAssertEqual(try output.files.map(widths(of:)), [[100, 200], [300], [400, 500]])
        let names = output.files.map(\.lastPathComponent)
        XCTAssertEqual(names[0], "book (\(SplitPDFEngine.partName(for: [0, 1]))).pdf")
        XCTAssertEqual(names[1], "book (\(SplitPDFEngine.partName(for: [2]))).pdf")
        XCTAssertEqual(Set(names).count, 3, "Every part has its own name")
    }

    func testSplitIntoOneFileIsNothingToDo() async throws {
        let file = try pdf([100, 200])
        await expectNothingToDo {
            try await SplitPDFEngine().run(input: ToolInput(files: [file]), options: .init(groups: [[0, 1]])) { _ in }
        }
    }

    // MARK: Merge

    func testMergeKeepsFileAndPageOrder() async throws {
        let first = try pdf([100, 200], name: "a.pdf")
        let second = try pdf([300], name: "b.pdf")
        let third = try pdf([400, 500], name: "c.pdf")
        let output = try await MergePDFEngine().run(
            input: ToolInput(files: [third, first, second]), options: .init()) { _ in }
        XCTAssertEqual(try widths(of: try XCTUnwrap(output.files.first)), [400, 500, 100, 200, 300])
    }

    func testMergeNeedsTwoFiles() async throws {
        let only = try pdf([100])
        await expectNothingToDo {
            try await MergePDFEngine().run(input: ToolInput(files: [only]), options: .init()) { _ in }
        }
    }

    func testMergeAsksForMissingPassword() async throws {
        let plain = try pdf([100])
        let locked = try TestFixtures.imported(try TestFixtures.makeEncryptedPDF(password: "pw"))
        do {
            _ = try await MergePDFEngine().run(input: ToolInput(files: [plain, locked]), options: .init()) { _ in }
            XCTFail("Expected passwordRequired")
        } catch let error as ToolError {
            XCTAssertEqual(error, .passwordRequired(fileID: locked.id, fileName: locked.name))
        }

        let output = try await MergePDFEngine().run(
            input: ToolInput(files: [plain, locked], passwords: [locked.id: "pw"]), options: .init()) { _ in }
        XCTAssertEqual(try widths(of: try XCTUnwrap(output.files.first)), [100, 200, 250])
    }
}

final class PageSelectionTests: XCTestCase {
    func testToggleSelectAllAndClear() {
        var selection = PageSelection()
        selection.toggle(2)
        selection.toggle(0)
        XCTAssertEqual(selection.sorted, [0, 2])
        selection.toggle(2)
        XCTAssertEqual(selection.sorted, [0])
        selection.selectAll(pageCount: 3)
        XCTAssertEqual(selection.count, 3)
        selection.clear()
        XCTAssertTrue(selection.isEmpty)
    }
}

@MainActor
final class PageToolViewModelTests: XCTestCase {
    private func loaded<T>(_ make: @MainActor ([ImportedFile]) -> T, widths: [CGFloat]) throws -> T {
        make([try TestFixtures.imported(try TestFixtures.makePDF(pageWidths: widths))])
    }

    func testRotateAppliesToSelectionOrEveryPage() throws {
        let model = try loaded({ RotatePagesViewModel(initialFiles: $0) }, widths: [100, 200, 300])
        XCTAssertFalse(model.isReady)
        model.rotate(by: 90)
        XCTAssertEqual([0, 1, 2].map { model.rotation(of: $0) }, [90, 90, 90])
        model.selection.toggle(1)
        model.rotate(by: -90)
        XCTAssertEqual([0, 1, 2].map { model.rotation(of: $0) }, [90, 0, 90])
        XCTAssertTrue(model.isReady)
    }

    func testDeleteIsNotReadyWhenEveryPageIsSelected() throws {
        let model = try loaded({ DeletePagesViewModel(initialFiles: $0) }, widths: [100, 200])
        model.selection.toggle(0)
        XCTAssertTrue(model.isReady)
        model.selection.toggle(1)
        XCTAssertFalse(model.isReady)
        XCTAssertTrue(model.deletesEverything)
    }

    func testSplitCustomStartsBuildGroups() throws {
        let model = try loaded({ SplitPDFViewModel(initialFiles: $0) }, widths: [100, 200, 300, 400])
        XCTAssertFalse(model.isReady)
        model.toggleStart(at: 0)
        XCTAssertFalse(model.isReady, "Page 1 always starts the first file")
        model.toggleStart(at: 2)
        XCTAssertEqual(model.groups, [[0, 1], [2, 3]])
        XCTAssertEqual(model.groupNumber(of: 3), 2)
        model.mode = .everyPage
        XCTAssertEqual(model.groups.count, 4)
    }

    func testMergeReorderHelpers() async throws {
        let model = MergePDFViewModel(initialFiles: [])
        let urls = try ["a.pdf", "b.pdf", "c.pdf"].map { try TestFixtures.makePDF(pageWidths: [100], name: $0) }
        model.files.importURLs(urls)
        try await waitUntil { !model.files.isImporting }
        XCTAssertEqual(model.totalPages, 3)

        let c = try XCTUnwrap(model.files.files.last)
        model.files.move(c.id, toIndex: 0)
        XCTAssertEqual(model.files.files.map(\.name), ["c.pdf", "a.pdf", "b.pdf"])
        model.moveLater(c)
        XCTAssertEqual(model.files.files.map(\.name), ["a.pdf", "c.pdf", "b.pdf"])
        model.moveEarlier(c)
        model.moveEarlier(c)
        XCTAssertEqual(model.files.files.first?.name, "c.pdf", "Moving past the start is clamped")
    }
}
