import Foundation
import Observation

@MainActor
@Observable
final class ExtractPagesViewModel {
    let files: FileListModel
    let runner = ToolRunner()
    var selection = PageSelection()
    private let engine = ExtractPagesEngine()

    init(initialFiles: [ImportedFile]) {
        files = FileListModel(accepts: [.pdf], allowsMultiple: false, initial: initialFiles)
    }

    var file: ImportedFile? { files.files.first }
    var pageCount: Int { file?.pageCount ?? 0 }
    var password: String? { file.flatMap { files.input.password(for: $0) } }
    var isReady: Bool { !selection.isEmpty }

    func run() {
        runner.run(engine, input: files.input, options: .init(pages: selection.pages))
    }
}
