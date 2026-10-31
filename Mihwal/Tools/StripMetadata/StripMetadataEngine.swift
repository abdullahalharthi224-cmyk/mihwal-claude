import CoreGraphics
import Foundation
import PDFKit

/// Removes the document information (title, author, dates, software…) and the XMP
/// metadata stream by copying the pages into a fresh document.
struct StripMetadataEngine: FileTool {
    struct Options: Sendable, Hashable {}

    enum Field: String, CaseIterable, Sendable {
        case title, author, subject, keywords, creator, producer, creationDate, modificationDate

        var attribute: PDFDocumentAttribute {
            switch self {
            case .title: return .titleAttribute
            case .author: return .authorAttribute
            case .subject: return .subjectAttribute
            case .keywords: return .keywordsAttribute
            case .creator: return .creatorAttribute
            case .producer: return .producerAttribute
            case .creationDate: return .creationDateAttribute
            case .modificationDate: return .modificationDateAttribute
            }
        }
    }

    /// The metadata a user would care about, as readable text.
    static func foundMetadata(in document: PDFDocument) -> [(field: Field, value: String)] {
        let attributes = document.documentAttributes ?? [:]
        return Field.allCases.compactMap { field in
            guard let raw = attributes[field.attribute.rawValue] else { return nil }
            let text: String
            switch raw {
            case let date as Date:
                text = date.formatted(date: .abbreviated, time: .shortened)
            case let list as [String]:
                text = list.joined(separator: ", ")
            default:
                text = "\(raw)"
            }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : (field, trimmed)
        }
    }

    /// Whether the catalog has an XMP /Metadata stream (often holds the same personal data).
    static func hasXMP(_ document: PDFDocument) -> Bool {
        guard let catalog = document.documentRef?.catalog else { return false }
        var stream: CGPDFStreamRef?
        return CGPDFDictionaryGetStream(catalog, "Metadata", &stream)
    }

    func run(input: ToolInput, options: Options,
             progress: @escaping @Sendable (Double) -> Void) async throws -> ToolOutput {
        guard let file = input.files.first else { throw ToolError.noInput }
        let source = try PDFLoader.open(file, password: input.password(for: file))
        guard !Self.foundMetadata(in: source).isEmpty || Self.hasXMP(source) else {
            throw ToolError.nothingToDo(reason: String(localized: "This PDF has no metadata to remove."))
        }
        let count = source.pageCount
        let result = try PDFLoader.copyPages(Array(0..<count), from: source, fileName: file.name) { done in
            progress(Double(done) / Double(max(1, count)) * 0.85)
        }
        result.documentAttributes = [:]

        try Task.checkCancellation()
        return try FileStore.withOutputDirectory { folder -> ToolOutput in
            let url = FileStore.outputURL(in: folder, baseName: file.baseName,
                                          suffix: String(localized: "clean"), pathExtension: "pdf")
            try PDFLoader.write(result, to: url, estimatedBytes: file.byteCount)
            progress(1)
            return ToolOutput(directory: folder, files: [url])
        }
    }
}
