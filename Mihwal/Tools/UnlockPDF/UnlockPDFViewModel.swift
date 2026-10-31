import Foundation
import Observation
import PDFKit

@MainActor
@Observable
final class UnlockPDFViewModel {
    let files: FileListModel
    let runner = ToolRunner()
    private let engine = UnlockPDFEngine()

    init(initialFiles: [ImportedFile]) {
        files = FileListModel(accepts: [.pdf], allowsMultiple: false, initial: initialFiles)
    }

    var file: ImportedFile? { files.files.first }
    var isReady: Bool { file?.isEncrypted == true }

    struct Protection {
        let needsPasswordToOpen: Bool
        /// Things the owner blocked, e.g. printing or copying (only known once the file opens).
        let blocked: [LocalizedStringResource]
    }

    var protection: Protection? {
        guard let file, file.isEncrypted, let document = PDFDocument(url: file.url) else { return nil }
        if document.isLocked {
            return Protection(needsPasswordToOpen: true, blocked: [])
        }
        var blocked: [LocalizedStringResource] = []
        if !document.allowsPrinting { blocked.append("Printing") }
        if !document.allowsCopying { blocked.append("Copying text") }
        if !document.allowsDocumentChanges { blocked.append("Editing") }
        if !document.allowsDocumentAssembly { blocked.append("Adding or removing pages") }
        if !document.allowsCommenting { blocked.append("Comments") }
        if !document.allowsFormFieldEntry { blocked.append("Filling forms") }
        return Protection(needsPasswordToOpen: false, blocked: blocked)
    }

    func run() {
        runner.run(engine, input: files.input, options: .init())
    }
}
