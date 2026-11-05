import Foundation
import Observation

@MainActor
@Observable
final class ImagesToPDFViewModel {
    let files: FileListModel
    let runner = ToolRunner()
    var options = ImagesToPDFEngine.Options()
    private let engine = ImagesToPDFEngine()

    init(initialFiles: [ImportedFile]) {
        files = FileListModel(accepts: [.image], allowsMultiple: true, initial: initialFiles)
    }

    var isReady: Bool { !files.files.isEmpty }

    func move(_ file: ImportedFile, by offset: Int) {
        guard let index = files.files.firstIndex(of: file) else { return }
        files.move(file.id, toIndex: index + offset)
    }

    func run() {
        runner.run(engine, input: files.input, options: options)
    }
}
