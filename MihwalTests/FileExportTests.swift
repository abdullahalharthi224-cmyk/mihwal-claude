import UIKit
import XCTest
@testable import Mihwal

/// "Save to Files" once opened a picker whose Save button never worked, and its result
/// was ignored. These tests pin down that every outcome is reported.
@MainActor
final class FileExportTests: XCTestCase {
    func testMissingResultFileFailsWithoutOpeningAPicker() {
        let exporter = FileExportCoordinator()
        var outcome: FileExportCoordinator.Outcome?
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).pdf")

        exporter.export([missing]) { outcome = $0 }
        XCTAssertEqual(outcome, .failed(.resultUnavailable))
    }

    func testEmptyExportFails() {
        let exporter = FileExportCoordinator()
        if case .success = exporter.makePicker(for: [], completion: { _ in }) {
            XCTFail("Exporting nothing must fail")
        }
    }

    func testPickerIsBuiltForExistingFilesAndReportsSave() throws {
        let exporter = FileExportCoordinator()
        let file = try TestFixtures.makePDF(pageWidths: [100])
        var outcome: FileExportCoordinator.Outcome?

        let picker = try exporter.makePicker(for: [file]) { outcome = $0 }.get()
        XCTAssertTrue(picker.delegate === exporter, "The picker must report back to the exporter")

        exporter.documentPicker(picker, didPickDocumentsAt: [file])
        XCTAssertEqual(outcome, .saved(count: 1))
    }

    func testCancelIsReported() throws {
        let exporter = FileExportCoordinator()
        let file = try TestFixtures.makePDF(pageWidths: [100])
        var outcome: FileExportCoordinator.Outcome?

        let picker = try exporter.makePicker(for: [file]) { outcome = $0 }.get()
        exporter.documentPickerWasCancelled(picker)
        XCTAssertEqual(outcome, .cancelled)
    }

    func testOutcomeIsReportedOnlyOnce() throws {
        let exporter = FileExportCoordinator()
        let file = try TestFixtures.makePDF(pageWidths: [100])
        var calls = 0

        let picker = try exporter.makePicker(for: [file]) { _ in calls += 1 }.get()
        exporter.documentPicker(picker, didPickDocumentsAt: [file])
        exporter.documentPickerWasCancelled(picker)
        XCTAssertEqual(calls, 1)
    }
}
