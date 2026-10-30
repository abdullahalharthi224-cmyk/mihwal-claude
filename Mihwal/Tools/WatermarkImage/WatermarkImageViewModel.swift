import CoreGraphics
import Foundation
import Observation

@MainActor
@Observable
final class WatermarkImageViewModel {
    let files: FileListModel
    let runner = ToolRunner()
    var options = WatermarkImageEngine.Options()
    /// The first photo with the mark, drawn by the same renderer as the final result.
    private(set) var preview: CGImage?
    private let engine = WatermarkImageEngine()

    init(initialFiles: [ImportedFile]) {
        files = FileListModel(accepts: [.image], allowsMultiple: true, initial: initialFiles)
    }

    var isReady: Bool { !files.files.isEmpty && !options.style.trimmedText.isEmpty }

    struct PreviewKey: Hashable {
        let fileID: UUID?
        let style: WatermarkStyle
    }

    var previewKey: PreviewKey {
        PreviewKey(fileID: files.files.first?.id, style: options.style)
    }

    func refreshPreview() async {
        guard let file = files.files.first, !options.style.trimmedText.isEmpty else {
            preview = nil
            return
        }
        let style = options.style
        let rendered = await Task.detached(priority: .userInitiated) { () -> CGImage? in
            guard let opened = try? ImageReader.open(file),
                  let small = ImageReader.uprightImage(from: opened.source, info: opened.info, maxPixelSize: 1000) else {
                return nil
            }
            return WatermarkRenderer.render(small, style: style)
        }.value
        guard !Task.isCancelled else { return }
        preview = rendered
    }

    func run() {
        runner.run(engine, input: files.input, options: options)
    }
}
