import CoreGraphics
import Foundation
import Observation

@MainActor
@Observable
final class RotateImageViewModel {
    let files: FileListModel
    let runner = ToolRunner()
    /// Clockwise quarter turns, not wrapped, so the preview always animates the short way.
    private(set) var rotationSteps = 0
    var flipHorizontal = false
    var flipVertical = false
    var removeLocation = true
    /// The first photo drawn by the engine itself (ImageTransform), so the preview is
    /// exactly what will be saved.
    private(set) var preview: CGImage?
    private let engine = RotateImageEngine()

    init(initialFiles: [ImportedFile]) {
        files = FileListModel(accepts: [.image], allowsMultiple: true, initial: initialFiles)
    }

    var options: RotateImageEngine.Options {
        .init(quarterTurns: ((rotationSteps % 4) + 4) % 4, flipHorizontal: flipHorizontal,
              flipVertical: flipVertical, removeLocation: removeLocation)
    }

    var isReady: Bool { !files.files.isEmpty && options.hasChanges }

    func rotateCounterclockwise() { rotationSteps -= 1 }
    func rotateClockwise() { rotationSteps += 1 }

    struct PreviewKey: Hashable {
        let fileID: UUID?
        let options: RotateImageEngine.Options
    }

    var previewKey: PreviewKey {
        PreviewKey(fileID: files.files.first?.id, options: options)
    }

    func refreshPreview() async {
        guard let file = files.files.first else {
            preview = nil
            return
        }
        let options = self.options
        let rendered = await Task.detached(priority: .userInitiated) { () -> CGImage? in
            guard let opened = try? ImageReader.open(file),
                  let small = ImageReader.uprightImage(from: opened.source, info: opened.info, maxPixelSize: 800) else {
                return nil
            }
            return ImageTransform.apply(small, quarterTurns: options.quarterTurns,
                                        flipHorizontal: options.flipHorizontal, flipVertical: options.flipVertical)
        }.value
        guard !Task.isCancelled else { return }
        preview = rendered
    }

    func reset() {
        rotationSteps = 0
        flipHorizontal = false
        flipVertical = false
    }

    func run() {
        runner.run(engine, input: files.input, options: options)
    }
}
