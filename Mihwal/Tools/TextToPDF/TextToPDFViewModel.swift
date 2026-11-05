import Foundation
import Observation

@MainActor
@Observable
final class TextToPDFViewModel {
    let files: FileListModel
    let runner = ToolRunner()
    var options = TextToPDFEngine.Options()
    private(set) var loadedFileID: UUID?
    var loadError: ToolError?
    private let engine = TextToPDFEngine()

    init(initialFiles: [ImportedFile]) {
        files = FileListModel(accepts: [.plainText], allowsMultiple: false, initial: initialFiles)
        loadImportedText()
    }

    var isReady: Bool { !options.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// Puts an imported .txt file into the editor (once per file).
    func loadImportedText() {
        guard let file = files.files.first, file.id != loadedFileID else { return }
        loadedFileID = file.id
        do {
            options.text = try TextFileReader.read(file.url)
        } catch {
            files.importError = .corruptedFile(fileName: file.name)
        }
    }

    func run() {
        runner.run(engine, input: files.input, options: options, requiresFiles: false)
    }
}
