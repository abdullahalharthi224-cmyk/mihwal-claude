import Foundation
import Observation

@MainActor
@Observable
final class MergePDFViewModel {
    let files: FileListModel
    let runner = ToolRunner()
    private let engine = MergePDFEngine()

    init(initialFiles: [ImportedFile]) {
        files = FileListModel(accepts: [.pdf], allowsMultiple: true, initial: initialFiles)
    }

    var isReady: Bool { files.files.count >= 2 }

    /// Total pages, when every file is unlocked (otherwise unknown until merging).
    var totalPages: Int? {
        let counts = files.files.map(\.pageCount)
        guard !counts.contains(where: { $0 == nil }) else { return nil }
        return counts.reduce(0) { $0 + ($1 ?? 0) }
    }

    func moveEarlier(_ file: ImportedFile) {
        guard let index = files.files.firstIndex(of: file) else { return }
        files.move(file.id, toIndex: index - 1)
    }

    func moveLater(_ file: ImportedFile) {
        guard let index = files.files.firstIndex(of: file) else { return }
        files.move(file.id, toIndex: index + 1)
    }

    func run() {
        runner.run(engine, input: files.input, options: .init())
    }
}
