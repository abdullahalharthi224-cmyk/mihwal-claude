import Foundation

/// Rotates by quarter turns and/or mirrors. Lossy formats are re-encoded at high quality
/// (lossless JPEG rotation isn't available on iOS).
struct RotateImageEngine: FileTool {
    struct Options: Sendable, Hashable {
        /// Clockwise quarter turns (0–3).
        var quarterTurns = 0
        var flipHorizontal = false
        var flipVertical = false
        var removeLocation = true

        var hasChanges: Bool {
            quarterTurns % 4 != 0 || flipHorizontal || flipVertical
        }
    }

    func run(input: ToolInput, options: Options,
             progress: @escaping @Sendable (Double) -> Void) async throws -> ToolOutput {
        guard options.hasChanges else {
            throw ToolError.nothingToDo(reason: String(localized: "Choose a rotation or a flip first."))
        }
        return try ImageBatch.run(input, progress: progress) { file, folder in
            let (source, info) = try ImageReader.open(file)
            guard let upright = ImageReader.uprightImage(from: source, info: info),
                  let image = ImageTransform.apply(upright, quarterTurns: options.quarterTurns,
                                                   flipHorizontal: options.flipHorizontal,
                                                   flipVertical: options.flipVertical) else {
                throw ToolError.corruptedFile(fileName: file.name)
            }
            let format = ImageFormat.preserving(file.contentType, hasAlpha: info.hasAlpha)
            let url = ImageBatch.outputURL(for: file, in: folder, suffix: String(localized: "rotated"), format: format)
            try ImageWriter.write(image, to: url, format: format, quality: 0.95,
                                  sourceProperties: info.properties, removeLocation: options.removeLocation)
            return url
        }
    }
}
