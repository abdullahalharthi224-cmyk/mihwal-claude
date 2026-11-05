import CoreGraphics
import Foundation
import PDFKit

/// Saves PDF pages as JPG or PNG pictures.
struct PDFToImagesEngine: FileTool {
    enum Resolution: String, Hashable, Sendable, CaseIterable {
        case screen, standard, print

        var dpi: CGFloat {
            switch self {
            case .screen: return 72
            case .standard: return 150
            case .print: return 300
            }
        }
    }

    struct Options: Sendable, Hashable {
        var format: ImageFormat = .jpeg
        var resolution: Resolution = .standard
        var quality: Double = 0.85
        /// Pages to save; empty means every page.
        var pages: Set<Int> = []
    }

    /// "page 4", used in the file names.
    static func pageLabel(_ number: Int) -> String {
        String(localized: "page \(number)")
    }

    /// Pixels per point, capped so a poster-sized page never exceeds 8000 pixels.
    static func scale(for page: PDFPage, resolution: Resolution) -> CGFloat {
        let size = PDFRedraw.displaySize(of: page)
        return min(resolution.dpi / 72, 8000 / max(size.width, size.height, 1))
    }

    func run(input: ToolInput, options: Options,
             progress: @escaping @Sendable (Double) -> Void) async throws -> ToolOutput {
        guard let file = input.files.first else { throw ToolError.noInput }
        let document = try PDFLoader.open(file, password: input.password(for: file))
        let all = Array(0..<document.pageCount)
        let chosen = options.pages.isEmpty ? all : all.filter { options.pages.contains($0) }
        guard !chosen.isEmpty else {
            throw ToolError.nothingToDo(reason: String(localized: "Select the pages you want to save as pictures."))
        }

        return try FileStore.withOutputDirectory { folder -> ToolOutput in
            var urls: [URL] = []
            for (done, index) in chosen.enumerated() {
                try Task.checkCancellation()
                let url = try autoreleasepool { () -> URL in
                    guard let page = document.page(at: index),
                          let image = PDFRasterizer.image(of: page, scale: Self.scale(for: page, resolution: options.resolution)) else {
                        throw ToolError.corruptedFile(fileName: file.name)
                    }
                    let url = FileStore.outputURL(in: folder, baseName: file.baseName,
                                                  suffix: Self.pageLabel(index + 1),
                                                  pathExtension: options.format.fileExtension)
                    try ImageWriter.write(image, to: url, format: options.format, quality: options.quality,
                                          sourceProperties: [:], removeLocation: true)
                    return url
                }
                urls.append(url)
                progress(Double(done + 1) / Double(chosen.count))
            }
            return ToolOutput(directory: folder, files: urls)
        }
    }
}
