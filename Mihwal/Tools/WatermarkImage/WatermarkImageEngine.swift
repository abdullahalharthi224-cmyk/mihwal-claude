import Foundation

struct WatermarkImageEngine: FileTool {
    struct Options: Sendable, Hashable {
        var style = WatermarkStyle()
        var removeLocation = true
    }

    func run(input: ToolInput, options: Options,
             progress: @escaping @Sendable (Double) -> Void) async throws -> ToolOutput {
        guard !options.style.trimmedText.isEmpty else {
            throw ToolError.nothingToDo(reason: String(localized: "Type the watermark text first."))
        }
        return try ImageBatch.run(input, progress: progress) { file, folder in
            let (source, info) = try ImageReader.open(file)
            guard let upright = ImageReader.uprightImage(from: source, info: info),
                  let image = WatermarkRenderer.render(upright, style: options.style) else {
                throw ToolError.corruptedFile(fileName: file.name)
            }
            let format = ImageFormat.preserving(file.contentType, hasAlpha: info.hasAlpha)
            let url = ImageBatch.outputURL(for: file, in: folder, suffix: String(localized: "watermarked"), format: format)
            try ImageWriter.write(image, to: url, format: format, quality: 0.92,
                                  sourceProperties: info.properties, removeLocation: options.removeLocation)
            return url
        }
    }
}
