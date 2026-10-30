import Foundation
import Observation

@MainActor
@Observable
final class DeletePagesViewModel {
    let files: FileListModel
    let runner = ToolRunner()
    var selection = PageSelection()
    private let engine = DeletePagesEngine()

    init(initialFiles: [ImportedFile]) {
        files = FileListModel(accepts: [.pdf], allowsMultiple: false, initial: initialFiles)
    }

    var file: ImportedFile? { files.files.first }
    var pageCount: Int { file?.pageCount ?? 0 }
    var password: String? { file.flatMap { files.input.password(for: $0) } }
    var deletesEverything: Bool { pageCount > 0 && selection.count >= pageCount }
    var isReady: Bool { !selection.isEmpty && !deletesEverything }

    func run() {
        runner.run(engine, input: files.input, options: .init(pages: selection.pages))
    }
}
