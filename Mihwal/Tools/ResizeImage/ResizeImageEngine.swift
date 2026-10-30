import Foundation

/// Scales photos down by a percentage or to a longest side. Aspect ratio is always kept
/// and images are never scaled up.
struct ResizeImageEngine: FileTool {
    enum Mode: Hashable, Sendable {
        case percent(Int)
        case longestSide(Int)
    }

    struct Options: Sendable, Hashable {
        var mode: Mode = .percent(50)
        var removeLocation = true
    }

    /// The new longest side for an image, never larger than the original.
    static func targetLongestSide(for info: ImageInfo, mode: Mode) -> Int {
        switch mode {
        case .percent(let percent):
            let clamped = min(100, max(1, percent))
            return max(1, Int((Double(info.longestSide) * Double(clamped) / 100).rounded()))
        case .longestSide(let side):
            return max(1, min(side, info.longestSide))
        }
    }

    func run(input: ToolInput, options: Options,
             progress: @escaping @Sendable (Double) -> Void) async throws -> ToolOutput {
        var unchanged = 0
        var output = try ImageBatch.run(input, progress: progress) { file, folder in
            let (source, info) = try ImageReader.open(file)
            let target = Self.targetLongestSide(for: info, mode: options.mode)
            if target >= info.longestSide {
                unchanged += 1
            }
            guard let image = ImageReader.uprightImage(from: source, info: info, maxPixelSize: target) else {
                throw ToolError.corruptedFile(fileName: file.name)
            }
            let format = ImageFormat.preserving(file.contentType, hasAlpha: info.hasAlpha)
            let url = ImageBatch.outputURL(for: file, in: folder, suffix: String(localized: "resized"), format: format)
            try ImageWriter.write(image, to: url, format: format, quality: 0.92,
                                  sourceProperties: info.properties, removeLocation: options.removeLocation)
            return url
        }
        if unchanged > 0 {
            output.notes.append(String(localized: "\(unchanged) images were already that small, so their size was kept."))
        }
        return output
    }
}
