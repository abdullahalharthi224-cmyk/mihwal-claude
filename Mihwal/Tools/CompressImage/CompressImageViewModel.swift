import Foundation
import Observation

@MainActor
@Observable
final class CompressImageViewModel {
    let files: FileListModel
    let runner = ToolRunner()
    var options = CompressImageEngine.Options()
    private let engine = CompressImageEngine()

    init(initialFiles: [ImportedFile]) {
        files = FileListModel(accepts: [.image], allowsMultiple: true, initial: initialFiles)
    }

    var isReady: Bool { !files.files.isEmpty }

    var formats: [CompressImageEngine.Format] {
        CompressImageEngine.Format.allCases.filter { $0 != .heic || ImageFormat.heic.canEncode }
    }

    func run() {
        runner.run(engine, input: files.input, options: options)
    }
}
