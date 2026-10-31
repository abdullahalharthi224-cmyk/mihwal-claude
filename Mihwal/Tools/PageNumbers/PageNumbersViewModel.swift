import CoreGraphics
import Foundation
import Observation
import PDFKit

@MainActor
@Observable
final class PageNumbersViewModel {
    let files: FileListModel
    let runner = ToolRunner()
    var options = PageNumbersEngine.Options()
    private(set) var preview: CGImage?
    private(set) var hasInteractiveContent = false
    private let engine = PageNumbersEngine()

    init(initialFiles: [ImportedFile]) {
        files = FileListModel(accepts: [.pdf], allowsMultiple: false, initial: initialFiles)
    }

    var file: ImportedFile? { files.files.first }
    var isReady: Bool { file != nil }
    var isLocked: Bool { file.map { $0.isLocked && files.input.password(for: $0) == nil } ?? false }

    struct PreviewKey: Hashable {
        let fileID: UUID?
        let password: String?
        let options: PageNumbersEngine.Options
    }

    var previewKey: PreviewKey {
        PreviewKey(fileID: file?.id, password: file.flatMap { files.input.password(for: $0) }, options: options)
    }

    func refreshPreview() async {
        guard let file else {
            preview = nil
            return
        }
        let password = files.input.password(for: file)
        let options = self.options
        let result = await Task.detached(priority: .userInitiated) { () -> (CGImage?, Bool) in
            let document = try? PDFLoader.open(file, password: password)
            let interactive = document.map(PDFLoader.hasInteractiveContent) ?? false
            return (PageNumbersEngine.previewImage(file: file, password: password, options: options), interactive)
        }.value
        guard !Task.isCancelled else { return }
        preview = result.0
        hasInteractiveContent = result.1
    }

    func run() {
        runner.run(engine, input: files.input, options: options)
    }
}
