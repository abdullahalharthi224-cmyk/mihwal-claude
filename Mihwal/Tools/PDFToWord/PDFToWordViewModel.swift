import Foundation
import Observation

@MainActor
@Observable
final class PDFToWordViewModel {
    let files: FileListModel
    let runner = ToolRunner()
    var options = PDFToWordEngine.Options()
    private let engine = PDFToWordEngine()

    init(initialFiles: [ImportedFile]) {
        files = FileListModel(accepts: [.pdf], allowsMultiple: false, initial: initialFiles)
    }

    var isReady: Bool { !files.files.isEmpty }

    func run() {
        runner.run(engine, input: files.input, options: options)
    }
}
