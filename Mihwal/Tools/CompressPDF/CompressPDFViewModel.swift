import Foundation
import Observation

@MainActor
@Observable
final class CompressPDFViewModel {
    let files: FileListModel
    let runner = ToolRunner()
    var options = CompressPDFEngine.Options()
    private let engine = CompressPDFEngine()

    init(initialFiles: [ImportedFile]) {
        files = FileListModel(accepts: [.pdf], allowsMultiple: false, initial: initialFiles)
    }

    var isReady: Bool { !files.files.isEmpty }

    func run() {
        runner.run(engine, input: files.input, options: options)
    }
}
