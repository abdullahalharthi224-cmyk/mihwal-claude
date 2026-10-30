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
    private let engine = RotateImageEngine()

    init(initialFiles: [ImportedFile]) {
        files = FileListModel(accepts: [.image], allowsMultiple: true, initial: initialFiles)
    }

    var options: RotateImageEngine.Options {
        .init(quarterTurns: ((rotationSteps % 4) + 4) % 4, flipHorizontal: flipHorizontal,
              flipVertical: flipVertical, removeLocation: removeLocation)
    }

    var isReady: Bool { !files.files.isEmpty && options.hasChanges }

    func rotateLeft() { rotationSteps -= 1 }
    func rotateRight() { rotationSteps += 1 }

    func reset() {
        rotationSteps = 0
        flipHorizontal = false
        flipVertical = false
    }

    func run() {
        runner.run(engine, input: files.input, options: options)
    }
}
