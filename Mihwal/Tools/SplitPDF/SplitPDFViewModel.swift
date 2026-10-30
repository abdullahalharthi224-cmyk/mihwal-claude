import Foundation
import Observation

@MainActor
@Observable
final class SplitPDFViewModel {
    enum Mode: Hashable, CaseIterable {
        case everyPage
        case everyN
        case custom
    }

    let files: FileListModel
    let runner = ToolRunner()
    var mode: Mode = .custom
    var pagesPerFile = 2
    /// Custom mode: pages where a new file starts (page 0 always starts the first file).
    private(set) var customStarts: Set<Int> = []
    private let engine = SplitPDFEngine()

    init(initialFiles: [ImportedFile]) {
        files = FileListModel(accepts: [.pdf], allowsMultiple: false, initial: initialFiles)
    }

    var file: ImportedFile? { files.files.first }
    var pageCount: Int { file?.pageCount ?? 0 }
    var password: String? { file.flatMap { files.input.password(for: $0) } }

    var splitMode: SplitMode {
        switch mode {
        case .everyPage: return .everyPage
        case .everyN: return .everyN(pagesPerFile)
        case .custom: return .custom(starts: customStarts)
        }
    }

    /// The files that will be created, recomputed live for the preview.
    var groups: [[Int]] {
        SplitPlan.groups(pageCount: pageCount, mode: splitMode)
    }

    var isReady: Bool { groups.count > 1 }

    /// Index of the output file a page belongs to (for the colored badges).
    func groupNumber(of page: Int) -> Int {
        (groups.firstIndex { $0.contains(page) } ?? 0) + 1
    }

    func startsGroup(_ page: Int) -> Bool {
        groups.contains { $0.first == page }
    }

    /// Custom mode: tapping a page toggles "a new file starts here". Page 1 always starts one.
    func toggleStart(at page: Int) {
        guard mode == .custom, page > 0 else { return }
        if customStarts.contains(page) {
            customStarts.remove(page)
        } else {
            customStarts.insert(page)
        }
    }

    func resetForNewFile() {
        customStarts = []
        pagesPerFile = 2
    }

    func run() {
        runner.run(engine, input: files.input, options: .init(groups: groups))
    }
}
