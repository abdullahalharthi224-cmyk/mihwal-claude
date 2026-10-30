import Foundation
import Observation

@MainActor
@Observable
final class ReversePagesViewModel {
    let files: FileListModel
    let runner = ToolRunner()
    private let engine = ReversePagesEngine()

    init(initialFiles: [ImportedFile]) {
        files = FileListModel(accepts: [.pdf], allowsMultiple: false, initial: initialFiles)
    }

    /// One page can't be reversed; locked PDFs are checked when running (password prompt).
    var isReady: Bool {
        guard let file = files.files.first else { return false }
        return (file.pageCount ?? 2) > 1
    }

    var pageCount: Int? {
        files.files.first?.pageCount
    }

    func run() {
        runner.run(engine, input: files.input, options: .init())
    }
}
