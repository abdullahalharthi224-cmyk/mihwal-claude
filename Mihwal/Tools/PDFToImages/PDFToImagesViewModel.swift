import Foundation
import Observation

@MainActor
@Observable
final class PDFToImagesViewModel {
    let files: FileListModel
    let runner = ToolRunner()
    var options = PDFToImagesEngine.Options()
    var selection = PageSelection()
    private let engine = PDFToImagesEngine()

    init(initialFiles: [ImportedFile]) {
        files = FileListModel(accepts: [.pdf], allowsMultiple: false, initial: initialFiles)
    }

    var file: ImportedFile? { files.files.first }
    var pageCount: Int { file?.pageCount ?? 0 }
    var password: String? { file.flatMap { files.input.password(for: $0) } }
    var isReady: Bool { file != nil }

    /// How many pictures will be made (no selection = every page).
    var pictureCount: Int { selection.isEmpty ? pageCount : selection.count }

    func run() {
        var options = self.options
        options.pages = selection.pages
        runner.run(engine, input: files.input, options: options)
    }
}
