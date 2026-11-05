import CoreGraphics
import Foundation

/// Photos to one PDF, one photo per page, in the chosen order. Photos are drawn upright
/// (EXIF orientation applied) and embedded as JPEG, so the PDF stays a reasonable size.
struct ImagesToPDFEngine: FileTool {
    enum PageSize: String, Hashable, Sendable, CaseIterable {
        /// The page takes the photo's shape.
        case fitImage
        case a4
        case letter

        var paperSize: CGSize? {
            switch self {
            case .fitImage: return nil
            case .a4: return CGSize(width: 595.28, height: 841.89)
            case .letter: return CGSize(width: 612, height: 792)
            }
        }
    }

    enum Margin: String, Hashable, Sendable, CaseIterable {
        case none, small, large

        var points: CGFloat {
            switch self {
            case .none: return 0
            case .small: return 18
            case .large: return 40
            }
        }
    }

    struct Options: Sendable, Hashable {
        var pageSize: PageSize = .a4
        var margin: Margin = .small
        var quality: Double = 0.85
    }

    /// Photos are placed at about 200 dpi: sharp in print, without huge files.
    static let pixelsPerPoint: CGFloat = 200 / 72
    /// "Fit to image" pages show the photo at 150 dpi.
    static let pointsPerPixelForFit: CGFloat = 72 / 150

    /// Page size for one photo. Paper sizes turn landscape for landscape photos.
    static func pageSize(for imageSize: CGSize, options: Options) -> CGSize {
        let margin = options.margin.points * 2
        guard let paper = options.pageSize.paperSize else {
            return CGSize(width: imageSize.width * pointsPerPixelForFit + margin,
                          height: imageSize.height * pointsPerPixelForFit + margin)
        }
        let landscape = imageSize.width > imageSize.height
        return landscape ? CGSize(width: paper.height, height: paper.width) : paper
    }

    /// The largest rectangle with the photo's shape that fits in `area`, centered.
    static func aspectFit(_ size: CGSize, in area: CGRect) -> CGRect {
        guard size.width > 0, size.height > 0 else { return area }
        let scale = min(area.width / size.width, area.height / size.height)
        let fitted = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(x: area.midX - fitted.width / 2, y: area.midY - fitted.height / 2,
                      width: fitted.width, height: fitted.height)
    }

    func run(input: ToolInput, options: Options,
             progress: @escaping @Sendable (Double) -> Void) async throws -> ToolOutput {
        guard let first = input.files.first else { throw ToolError.noInput }
        try StorageGuard.ensureSpace(for: input.files.reduce(0) { $0 + $1.byteCount } * 2)

        return try FileStore.withOutputDirectory { folder -> ToolOutput in
            let url = FileStore.outputURL(in: folder, baseName: first.baseName, suffix: "PDF", pathExtension: "pdf")
            var defaultBox = CGRect(x: 0, y: 0, width: 612, height: 792)
            guard let consumer = CGDataConsumer(url: url as CFURL),
                  let context = CGContext(consumer: consumer, mediaBox: &defaultBox, nil) else {
                throw ToolError.writeFailed
            }
            for (index, file) in input.files.enumerated() {
                try Task.checkCancellation()
                try autoreleasepool {
                    let (source, info) = try ImageReader.open(file)
                    let imageSize = CGSize(width: info.width, height: info.height)
                    var mediaBox = CGRect(origin: .zero, size: Self.pageSize(for: imageSize, options: options))
                    let area = mediaBox.insetBy(dx: options.margin.points, dy: options.margin.points)
                    let placement = Self.aspectFit(imageSize, in: area)
                    let pixels = Int(max(placement.width, placement.height) * Self.pixelsPerPoint)
                    guard let upright = ImageReader.uprightImage(from: source, info: info, maxPixelSize: pixels) else {
                        throw ToolError.corruptedFile(fileName: file.name)
                    }
                    // JPEG has no transparency: put transparent images on white first.
                    let opaque = upright.hasAlpha ? (ImageCanvas.flattened(upright) ?? upright) : upright
                    guard let image = ImageEncoding.jpegImage(opaque, quality: options.quality) else {
                        throw ToolError.corruptedFile(fileName: file.name)
                    }
                    let boxData = withUnsafeBytes(of: &mediaBox) { Data($0) } as CFData
                    context.beginPDFPage([kCGPDFContextMediaBox: boxData] as CFDictionary)
                    context.draw(image, in: placement)
                    context.endPDFPage()
                }
                progress(Double(index + 1) / Double(input.files.count))
            }
            context.closePDF()
            return ToolOutput(directory: folder, files: [url])
        }
    }
}
