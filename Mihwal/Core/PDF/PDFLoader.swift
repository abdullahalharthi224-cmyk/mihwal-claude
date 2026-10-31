import Foundation
import PDFKit

enum PDFLoader {
    /// Opens a PDF, unlocking it with `password` when it is protected.
    ///
    /// Every tool writes a new, unprotected PDF. So a PDF whose owner blocked changes
    /// (printing, copying, editing…) is only opened with the owner password: Mihwal never
    /// removes protection without the correct password.
    static func open(_ file: ImportedFile, password: String?) throws -> PDFDocument {
        guard let document = PDFDocument(url: file.url) else {
            throw ToolError.corruptedFile(fileName: file.name)
        }
        let hasPassword = !(password ?? "").isEmpty
        if document.isLocked {
            guard let password, hasPassword else {
                throw ToolError.passwordRequired(fileID: file.id, fileName: file.name)
            }
            guard document.unlock(withPassword: password) else {
                throw ToolError.wrongPassword(fileID: file.id, fileName: file.name)
            }
        } else if let password, hasPassword, document.isEncrypted {
            // Opens without a password; the owner password raises access to "owner".
            _ = document.unlock(withPassword: password)
        }
        if hasRestrictions(document) {
            throw ToolError.ownerPasswordRequired(fileID: file.id, fileName: file.name, afterAttempt: hasPassword)
        }
        return document
    }

    /// True when the owner blocked something and we don't have owner access.
    static func hasRestrictions(_ document: PDFDocument) -> Bool {
        guard document.isEncrypted, document.permissionsStatus != .owner else { return false }
        return !(document.allowsPrinting && document.allowsCopying && document.allowsDocumentChanges
                 && document.allowsDocumentAssembly && document.allowsCommenting && document.allowsFormFieldEntry)
    }

    /// Whether any page has links, form fields or comments (they get flattened by redrawing).
    static func hasInteractiveContent(_ document: PDFDocument) -> Bool {
        (0..<document.pageCount).contains { document.page(at: $0)?.annotations.isEmpty == false }
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
