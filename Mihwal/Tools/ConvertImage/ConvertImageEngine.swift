import Foundation

/// Converts any readable image (HEIC, WebP, PNG, JPEG, GIF, TIFF…) to JPG, PNG or HEIC.
struct ConvertImageEngine: FileTool {
    struct Options: Sendable, Hashable {
        var format: ImageFormat = .jpeg
        var quality: Double = 0.9
        var removeLocation = true
    }

    func run(input: ToolInput, options: Options,
             progress: @escaping @Sendable (Double) -> Void) async throws -> ToolOutput {
        try ImageBatch.run(input, progress: progress) { file, folder in
            let (source, info) = try ImageReader.open(file)
            guard let image = ImageReader.uprightImage(from: source, info: info) else {
                throw ToolError.corruptedFile(fileName: file.name)
            }
            let url = ImageBatch.outputURL(for: file, in: folder, suffix: String(localized: "converted"),
                                           format: options.format)
            try ImageWriter.write(image, to: url, format: options.format, quality: options.quality,
                                  sourceProperties: info.properties, removeLocation: options.removeLocation)
            return url
        }
    }
}
