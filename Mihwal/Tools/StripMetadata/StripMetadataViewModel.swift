import Foundation
import Observation
import PDFKit

@MainActor
@Observable
final class StripMetadataViewModel {
    let files: FileListModel
    let runner = ToolRunner()
    private let engine = StripMetadataEngine()

    init(initialFiles: [ImportedFile]) {
        files = FileListModel(accepts: [.pdf], allowsMultiple: false, initial: initialFiles)
    }

    var file: ImportedFile? { files.files.first }
    var isReady: Bool { file != nil }

    struct Report {
        let fields: [(field: StripMetadataEngine.Field, value: String)]
        let hasXMP: Bool
    }

    /// What is inside the PDF now, so the user sees what will be removed. Nil while locked.
    var report: Report? {
        guard let file, let document = PDFDocument(url: file.url) else { return nil }
        if document.isLocked {
            guard let password = files.input.password(for: file), document.unlock(withPassword: password) else {
                return nil
            }
        }
        return Report(fields: StripMetadataEngine.foundMetadata(in: document),
                      hasXMP: StripMetadataEngine.hasXMP(document))
    }

    func run() {
        runner.run(engine, input: files.input, options: .init())
    }
}
