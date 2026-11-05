import Foundation
import Observation

@MainActor
@Observable
final class PDFToTextViewModel {
    let files: FileListModel
    let runner = ToolRunner()
    var options = PDFToTextEngine.Options()
    private let engine = PDFToTextEngine()

    init(initialFiles: [ImportedFile]) {
        files = FileListModel(accepts: [.pdf], allowsMultiple: false, initial: initialFiles)
    }

    var isReady: Bool { !files.files.isEmpty }

    func run() {
        runner.run(engine, input: files.input, options: options)
    }
}
