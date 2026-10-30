import Foundation

/// Makes photos smaller: lossy re-encoding, optionally a smaller maximum size.
/// A result that would be bigger than the original is replaced by the original.
struct CompressImageEngine: FileTool {
    enum Format: String, Hashable, Sendable, CaseIterable {
        case jpeg
        case heic
        /// Keep each image's own format (PNG stays lossless: only resizing helps).
        case original
    }

    struct Options: Sendable, Hashable {
        var quality: Double = 0.7
        var format: Format = .jpeg
        /// Longest side in pixels; nil keeps the original size.
        var maxPixelSize: Int? = nil
        var removeLocation = true
    }

    func run(input: ToolInput, options: Options,
             progress: @escaping @Sendable (Double) -> Void) async throws -> ToolOutput {
        var keptOriginals = 0
        var output = try ImageBatch.run(input, progress: progress) { file, folder in
            let (source, info) = try ImageReader.open(file)
            guard let image = ImageReader.uprightImage(from: source, info: info, maxPixelSize: options.maxPixelSize) else {
                throw ToolError.corruptedFile(fileName: file.name)
            }
            let format = Self.targetFormat(options.format, for: file, hasAlpha: info.hasAlpha)
            let url = ImageBatch.outputURL(for: file, in: folder, suffix: String(localized: "compressed"), format: format)
            try ImageWriter.write(image, to: url, format: format, quality: options.quality,
                                  sourceProperties: info.properties, removeLocation: options.removeLocation)

            // Never hand back a bigger file than the user started with.
            guard FileStore.byteCount(of: url) >= file.byteCount else { return url }
            FileStore.remove(url)
            keptOriginals += 1
            let originalCopy = FileStore.outputURL(in: folder, baseName: file.baseName,
                                                   suffix: String(localized: "compressed"),
                                                   pathExtension: file.url.pathExtension)
            try FileManager.default.copyItem(at: file.url, to: originalCopy)
            return originalCopy
        }
        output.inputBytes = input.files.reduce(0) { $0 + $1.byteCount }
        if keptOriginals > 0 {
            output.notes.append(String(localized: "\(keptOriginals) images were already small, so they were kept as they were."))
        }
        return output
    }

    static func targetFormat(_ choice: Format, for file: ImportedFile, hasAlpha: Bool) -> ImageFormat {
        switch choice {
        case .jpeg:
            return .jpeg
        case .heic:
            return ImageFormat.heic.canEncode ? .heic : .jpeg
        case .original:
            return ImageFormat.preserving(file.contentType, hasAlpha: hasAlpha)
        }
    }
}
