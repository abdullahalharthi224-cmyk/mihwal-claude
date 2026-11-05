import CoreGraphics
import Foundation
import PDFKit
import Vision

struct PageText: Sendable, Equatable {
    let index: Int
    let text: String
    /// The page had no text layer, so its text was read from the page image.
    let usedOCR: Bool
}

/// Reads the text of a PDF: the text layer when a page has one, otherwise OCR on the page
/// image with Vision (Arabic and English, on device).
enum PDFTextExtractor {
    /// Languages for OCR on this device, Arabic first when the OS supports it.
    static func ocrLanguages() -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        let supported = (try? request.supportedRecognitionLanguages()) ?? ["en-US"]
        let chosen = ["ar-SA", "ars-SA", "en-US"].filter { supported.contains($0) }
        return chosen.isEmpty ? ["en-US"] : chosen
    }

    static var supportsArabicOCR: Bool {
        ocrLanguages().contains { $0.hasPrefix("ar") }
    }

    /// A page "has text" when its text layer holds at least one letter or digit.
    static func hasText(_ text: String) -> Bool {
        text.contains { $0.isLetter || $0.isNumber }
    }

    static func extract(from document: PDFDocument, forceOCR: Bool = false,
                        progress: (Int) -> Void = { _ in }) throws -> [PageText] {
        var pages: [PageText] = []
        var languages: [String]?
        for index in 0..<document.pageCount {
            try Task.checkCancellation()
            guard let page = document.page(at: index) else { continue }
            let layer = normalize(page.string ?? "")
            if !forceOCR && hasText(layer) {
                pages.append(PageText(index: index, text: layer.trimmingCharacters(in: .whitespacesAndNewlines),
                                      usedOCR: false))
            } else {
                let chosen = languages ?? ocrLanguages()
                languages = chosen
                let text = try autoreleasepool { try recognize(page: page, languages: chosen) }
                pages.append(PageText(index: index, text: text, usedOCR: true))
            }
            progress(index + 1)
        }
        return pages
    }

    static func recognize(page: PDFPage, languages: [String]) throws -> String {
        let size = PDFRedraw.displaySize(of: page)
        // About 200 dpi for a normal page, capped so huge pages don't use too much memory.
        let scale = min(2.8, 2800 / max(size.width, size.height, 1))
        guard let image = PDFRasterizer.image(of: page, scale: scale) else { return "" }
        return try recognize(image, languages: languages)
    }

    static func recognize(_ image: CGImage, languages: [String]) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = languages
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
        let observations = request.results ?? []
        // Vision's y axis points up: read lines from the top of the page down.
        let lines = observations
            .sorted { $0.boundingBox.midY > $1.boundingBox.midY }
            .compactMap { $0.topCandidates(1).first?.string }
        return normalize(lines.joined(separator: "\n"))
    }

    /// Some PDFs store Arabic as "presentation forms" (one code per letter shape); turn them
    /// back into normal letters so the text can be searched and edited.
    static func normalize(_ text: String) -> String {
        let hasPresentationForms = text.unicodeScalars.contains {
            (0xFB50...0xFDFF).contains($0.value) || (0xFE70...0xFEFE).contains($0.value)
        }
        return hasPresentationForms ? text.precomposedStringWithCompatibilityMapping : text
    }

    /// "2, 5, 7" (1-based) for the pages that used OCR.
    static func pageList(_ pages: [PageText]) -> String {
        pages.filter(\.usedOCR).map { String($0.index + 1) }.joined(separator: ", ")
    }

    /// Notes for the result screen about OCR.
    static func notes(for pages: [PageText]) -> [String] {
        guard pages.contains(where: \.usedOCR) else { return [] }
        var notes = [String(localized: "These pages had no text, so it was read from the page image (OCR): \(pageList(pages)). Check them for mistakes.")]
        if !supportsArabicOCR {
            notes.append(String(localized: "Arabic OCR isn't available on this iOS version, so Arabic on those pages may be missing."))
        }
        return notes
    }
}
