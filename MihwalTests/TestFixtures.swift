import PDFKit
import UIKit
import XCTest
@testable import Mihwal

/// Builds small sample files on the fly, so the repo has no binary test fixtures.
enum TestFixtures {
    static func scratchDirectory() throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("MihwalTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// A PDF whose pages have the given widths, so tests can tell pages apart by size.
    static func makePDF(pageWidths: [CGFloat], name: String = "sample.pdf") throws -> URL {
        let url = try scratchDirectory().appendingPathComponent(name)
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 200, height: 300))
        let data = renderer.pdfData { context in
            for (index, width) in pageWidths.enumerated() {
                context.beginPage(withBounds: CGRect(x: 0, y: 0, width: width, height: 300), pageInfo: [:])
                ("Page \(index + 1)" as NSString).draw(at: CGPoint(x: 10, y: 10), withAttributes: nil)
            }
        }
        try data.write(to: url)
        return url
    }

    static func makeEncryptedPDF(password: String) throws -> URL {
        let plain = try makePDF(pageWidths: [200, 250])
        let document = try XCTUnwrap(PDFDocument(url: plain))
        let url = plain.deletingLastPathComponent().appendingPathComponent("locked.pdf")
        let written = document.write(to: url, withOptions: [
            .userPasswordOption: password,
            .ownerPasswordOption: password,
        ])
        XCTAssertTrue(written)
        return url
    }

    static func makePNG(width: Int, height: Int, name: String = "image.png") throws -> URL {
        let url = try scratchDirectory().appendingPathComponent(name)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        try XCTUnwrap(image.pngData()).write(to: url)
        return url
    }

    static func makeGarbage(name: String) throws -> URL {
        let url = try scratchDirectory().appendingPathComponent(name)
        try Data("this is not a real file".utf8).write(to: url)
        return url
    }

    static func imported(_ url: URL) throws -> ImportedFile {
        try FileStore.importCopy(of: url, coordinated: false)
    }
}

extension XCTestCase {
    /// Polls until `condition` is true (async work such as importing or running a tool).
    @MainActor
    func waitUntil(timeout: TimeInterval = 10, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline {
                XCTFail("Timed out waiting for condition")
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }
    }
}
