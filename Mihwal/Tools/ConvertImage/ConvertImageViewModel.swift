import Foundation
import Observation

@MainActor
@Observable
final class ConvertImageViewModel {
    let files: FileListModel
    let runner = ToolRunner()
    var options = ConvertImageEngine.Options()
    private let engine = ConvertImageEngine()

    init(initialFiles: [ImportedFile]) {
        files = FileListModel(accepts: [.image], allowsMultiple: true, initial: initialFiles)
    }

    var isReady: Bool { !files.files.isEmpty }

    func run() {
        runner.run(engine, input: files.input, options: options)
    }
}
