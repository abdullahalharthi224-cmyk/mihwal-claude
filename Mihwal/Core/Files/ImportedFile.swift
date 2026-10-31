import Foundation
import UniformTypeIdentifiers

/// A file the app owns a private copy of (in tmp/Inputs), ready for any tool.
struct ImportedFile: Identifiable, Hashable, Sendable {
    let id: UUID
    let url: URL
    let contentType: UTType
    let byteCount: Int64
    /// Number of pages for PDFs that are open (or unlocked); nil otherwise.
    let pageCount: Int?
    /// A PDF that needs a password to open.
    let isLocked: Bool
    /// A PDF with any protection: an open password or owner restrictions.
    var isEncrypted = false

    var name: String { url.lastPathComponent }
    var baseName: String { url.deletingPathExtension().lastPathComponent }
    var isPDF: Bool { contentType.conforms(to: .pdf) }
    var isImage: Bool { contentType.conforms(to: .image) }

    func accepted(by types: [UTType]) -> Bool {
        types.contains { contentType.conforms(to: $0) }
    }
}
