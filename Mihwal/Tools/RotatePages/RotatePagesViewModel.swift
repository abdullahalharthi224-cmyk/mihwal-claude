import Foundation
import Observation

@MainActor
@Observable
final class RotatePagesViewModel {
    let files: FileListModel
    let runner = ToolRunner()
    var selection = PageSelection()
    /// Page index → degrees added by the user (0, 90, 180 or 270).
    private(set) var rotations: [Int: Int] = [:]
    private let engine = RotatePagesEngine()

    init(initialFiles: [ImportedFile]) {
        files = FileListModel(accepts: [.pdf], allowsMultiple: false, initial: initialFiles)
    }

    var file: ImportedFile? { files.files.first }
    var pageCount: Int { file?.pageCount ?? 0 }
    var password: String? { file.flatMap { files.input.password(for: $0) } }
    var isReady: Bool { rotations.values.contains { $0 != 0 } }

    func rotation(of page: Int) -> Int {
        rotations[page] ?? 0
    }

    /// Rotates the selected pages, or every page when nothing is selected.
    func rotate(by degrees: Int) {
        let targets = selection.isEmpty ? Array(0..<pageCount) : selection.sorted
        for page in targets {
            rotations[page] = RotatePagesEngine.normalized(rotation(of: page) + degrees)
        }
    }

    func resetForNewFile() {
        rotations = [:]
        selection.clear()
    }

    func run() {
        runner.run(engine, input: files.input, options: .init(rotations: rotations))
    }
}
