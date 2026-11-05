import SwiftUI
import UniformTypeIdentifiers

/// The single list of tools. Adding a tool = one entry here + its own folder in Tools/.
enum ToolRegistry {
    static let all: [ToolDescriptor] = [
        // MARK: Organize PDF
        ToolDescriptor(id: .merge, title: "Merge PDF", subtitle: "Combine several PDFs into one",
                       symbol: "doc.on.doc", category: .organize, accepts: [.pdf], allowsMultipleFiles: true,
                       makeView: { AnyView(MergePDFView(initialFiles: $0)) }),
        ToolDescriptor(id: .split, title: "Split PDF", subtitle: "Turn pages into separate files",
                       symbol: "scissors", category: .organize, accepts: [.pdf],
                       makeView: { AnyView(SplitPDFView(initialFiles: $0)) }),
        ToolDescriptor(id: .compressPDF, title: "Compress PDF", subtitle: "Make the file smaller",
                       symbol: "arrow.down.right.and.arrow.up.left", category: .organize, accepts: [.pdf],
                       makeView: { AnyView(CompressPDFView(initialFiles: $0)) }),
        ToolDescriptor(id: .rotatePDF, title: "Rotate Pages", subtitle: "Turn pages the right way",
                       symbol: "rotate.right", category: .organize, accepts: [.pdf],
                       makeView: { AnyView(RotatePagesView(initialFiles: $0)) }),
        ToolDescriptor(id: .deletePages, title: "Delete Pages", subtitle: "Remove the pages you don't need",
                       symbol: "trash", category: .organize, accepts: [.pdf],
                       makeView: { AnyView(DeletePagesView(initialFiles: $0)) }),
        ToolDescriptor(id: .extractPages, title: "Extract Pages", subtitle: "Save chosen pages as a new PDF",
                       symbol: "arrow.up.doc", category: .organize, accepts: [.pdf],
                       makeView: { AnyView(ExtractPagesView(initialFiles: $0)) }),
        ToolDescriptor(id: .reversePages, title: "Reverse Order", subtitle: "Put the last page first",
                       symbol: "arrow.up.arrow.down", category: .organize, accepts: [.pdf],
                       makeView: { AnyView(ReversePagesView(initialFiles: $0)) }),
        ToolDescriptor(id: .pageNumbers, title: "Page Numbers", subtitle: "Add numbers to every page",
                       symbol: "number", category: .organize, accepts: [.pdf],
                       makeView: { AnyView(PageNumbersView(initialFiles: $0)) }),
        ToolDescriptor(id: .watermarkPDF, title: "Watermark PDF", subtitle: "Stamp text across your pages",
                       symbol: "drop", category: .organize, accepts: [.pdf],
                       makeView: { AnyView(WatermarkPDFView(initialFiles: $0)) }),
        ToolDescriptor(id: .stripMetadata, title: "Remove Metadata", subtitle: "Erase author, dates and hidden info",
                       symbol: "eye.slash", category: .organize, accepts: [.pdf],
                       makeView: { AnyView(StripMetadataView(initialFiles: $0)) }),
        ToolDescriptor(id: .removeRestrictions, title: "Unlock PDF", subtitle: "Remove protection with your password",
                       symbol: "lock.open", category: .organize, accepts: [.pdf],
                       makeView: { AnyView(UnlockPDFView(initialFiles: $0)) }),

        // MARK: Convert
        ToolDescriptor(id: .pdfToWord, title: "PDF to Word", subtitle: "Get the text as a Word document",
                       symbol: "doc.richtext", category: .convert, accepts: [.pdf],
                       makeView: { AnyView(PDFToWordView(initialFiles: $0)) }),
        ToolDescriptor(id: .pdfToText, title: "PDF to Text", subtitle: "Copy text, even from scans",
                       symbol: "doc.plaintext", category: .convert, accepts: [.pdf],
                       makeView: { AnyView(PDFToTextView(initialFiles: $0)) }),
        ToolDescriptor(id: .textToPDF, title: "Text to PDF", subtitle: "Write Arabic or English, get a PDF",
                       symbol: "text.badge.plus", category: .convert, accepts: [.plainText],
                       makeView: { AnyView(TextToPDFView(initialFiles: $0)) }),
        ToolDescriptor(id: .imagesToPDF, title: "Images to PDF", subtitle: "Turn photos into one PDF",
                       symbol: "photo.on.rectangle", category: .convert, accepts: [.image], allowsMultipleFiles: true,
                       makeView: { AnyView(ImagesToPDFView(initialFiles: $0)) }),
        ToolDescriptor(id: .pdfToImages, title: "PDF to Images", subtitle: "Save every page as a picture",
                       symbol: "photo.on.rectangle.angled", category: .convert, accepts: [.pdf],
                       makeView: { AnyView(PDFToImagesView(initialFiles: $0)) }),

        // MARK: Images
        ToolDescriptor(id: .convertImage, title: "Convert Image", subtitle: "JPG, PNG or HEIC from any photo",
                       symbol: "arrow.triangle.2.circlepath", category: .images, accepts: [.image], allowsMultipleFiles: true,
                       makeView: { AnyView(ConvertImageView(initialFiles: $0)) }),
        ToolDescriptor(id: .compressImage, title: "Compress Images", subtitle: "Smaller photos, same look",
                       symbol: "rectangle.compress.vertical", category: .images, accepts: [.image], allowsMultipleFiles: true,
                       makeView: { AnyView(CompressImageView(initialFiles: $0)) }),
        ToolDescriptor(id: .resizeImage, title: "Resize Images", subtitle: "Change width and height",
                       symbol: "arrow.up.left.and.arrow.down.right", category: .images, accepts: [.image], allowsMultipleFiles: true,
                       makeView: { AnyView(ResizeImageView(initialFiles: $0)) }),
        ToolDescriptor(id: .rotateImage, title: "Rotate & Flip", subtitle: "Turn or mirror your photos",
                       symbol: "rotate.left", category: .images, accepts: [.image], allowsMultipleFiles: true,
                       makeView: { AnyView(RotateImageView(initialFiles: $0)) }),
        ToolDescriptor(id: .watermarkImage, title: "Watermark Images", subtitle: "Add your text on top of photos",
                       symbol: "textformat", category: .images, accepts: [.image], allowsMultipleFiles: true,
                       makeView: { AnyView(WatermarkImageView(initialFiles: $0)) }),
    ]

    static func descriptor(for id: ToolID) -> ToolDescriptor? {
        all.first { $0.id == id }
    }

    /// The descriptor of a tool that is known to be registered (tests check all are).
    static func tool(_ id: ToolID) -> ToolDescriptor {
        descriptor(for: id) ?? all[0]
    }

    static func tools(in category: ToolCategory) -> [ToolDescriptor] {
        all.filter { $0.category == category }
    }

    /// Tools that can open a file of this type (used by "Open in").
    static func tools(accepting type: UTType) -> [ToolDescriptor] {
        all.filter { tool in tool.accepts.contains { type.conforms(to: $0) } }
    }

    /// Matches the localized title/subtitle and the English title, ignoring case and
    /// Arabic diacritics (so "محول" finds "مِحوَل").
    static func search(_ query: String) -> [ToolDescriptor] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        return all.filter { tool in
            let haystacks = [String(localized: tool.title), String(localized: tool.subtitle), tool.title.key]
            return haystacks.contains { $0.range(of: trimmed, options: options) != nil }
        }
    }
}
