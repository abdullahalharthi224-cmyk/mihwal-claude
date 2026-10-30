import Foundation
import PDFKit

enum PDFLoader {
    /// Opens a PDF, unlocking it with `password` when it is protected.
    static func open(_ file: ImportedFile, password: String?) throws -> PDFDocument {
        guard let document = PDFDocument(url: file.url) else {
            throw ToolError.corruptedFile(fileName: file.name)
        }
        if document.isLocked {
            guard let password, !password.isEmpty else {
                throw ToolError.passwordRequired(fileID: file.id, fileName: file.name)
            }
            guard document.unlock(withPassword: password) else {
                throw ToolError.wrongPassword(fileID: file.id, fileName: file.name)
            }
        }
        return document
    }

    /// A new document with copies of the pages at `indices`, in that order.
    /// Copies keep text, links and annotations. Calls `progress` after each page.
    static func copyPages(_ indices: [Int], from source: PDFDocument, fileName: String,
                          progress: (Int) -> Void = { _ in }) throws -> PDFDocument {
        let result = PDFDocument()
        for (position, index) in indices.enumerated() {
            try Task.checkCancellation()
            guard let page = source.page(at: index)?.copy() as? PDFPage else {
                throw ToolError.corruptedFile(fileName: fileName)
            }
            result.insert(page, at: position)
            progress(position + 1)
        }
        return result
    }

    /// Writes `document`, checking free space first and mapping failures to ToolError.
    static func write(_ document: PDFDocument, to url: URL, estimatedBytes: Int64) throws {
        try StorageGuard.ensureSpace(for: estimatedBytes)
        guard document.write(to: url) else {
            throw ToolError.writeFailed
        }
    }
}
