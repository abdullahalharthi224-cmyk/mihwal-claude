import Foundation
import PDFKit

enum SplitMode: Hashable, Sendable {
    /// One file per page.
    case everyPage
    /// A new file every N pages.
    case everyN(Int)
    /// A new file starts at each of these page indices (page 0 always starts the first file).
    case custom(starts: Set<Int>)
}

/// Turns a split mode into groups of page indices. Pure, so the UI preview and the
/// engine always agree.
enum SplitPlan {
    static func groups(pageCount: Int, mode: SplitMode) -> [[Int]] {
        guard pageCount > 0 else { return [] }
        switch mode {
        case .everyPage:
            return (0..<pageCount).map { [$0] }
        case .everyN(let size):
            let step = max(1, size)
            return stride(from: 0, to: pageCount, by: step).map { start in
                Array(start..<min(start + step, pageCount))
            }
        case .custom(let starts):
            let boundaries = [0] + starts.filter { $0 > 0 && $0 < pageCount }.sorted()
            return boundaries.indices.map { position -> [Int] in
                let start = boundaries[position]
                let end = position + 1 < boundaries.count ? boundaries[position + 1] : pageCount
                return Array(start..<end)
            }
        }
    }
}

/// Splits one PDF into several. Each part is a copy of its pages (text and links kept).
struct SplitPDFEngine: FileTool {
    struct Options: Sendable {
        var groups: [[Int]]
    }

    /// "page 4" or "pages 1–3", used in the output file names.
    static func partName(for group: [Int]) -> String {
        guard let first = group.first, let last = group.last else { return "" }
        if first == last {
            return String(localized: "page \(first + 1)")
        }
        return String(localized: "pages \(first + 1)–\(last + 1)")
    }

    func run(input: ToolInput, options: Options,
             progress: @escaping @Sendable (Double) -> Void) async throws -> ToolOutput {
        guard let file = input.files.first else { throw ToolError.noInput }
        let source = try PDFLoader.open(file, password: input.password(for: file))
        let valid = 0..<source.pageCount
        let groups = options.groups
            .map { $0.filter { valid.contains($0) } }
            .filter { !$0.isEmpty }
        guard groups.count > 1 else {
            throw ToolError.nothingToDo(reason: String(localized: "This would make only one file. Choose where to split."))
        }

        let totalPages = groups.reduce(0) { $0 + $1.count }
        try StorageGuard.ensureSpace(for: file.byteCount * 2)
        return try FileStore.withOutputDirectory { folder -> ToolOutput in
            var urls: [URL] = []
            var pagesDone = 0
            for group in groups {
                try Task.checkCancellation()
                let part = try PDFLoader.copyPages(group, from: source, fileName: file.name)
                let url = FileStore.outputURL(in: folder, baseName: file.baseName,
                                              suffix: Self.partName(for: group), pathExtension: "pdf")
                guard part.write(to: url) else { throw ToolError.writeFailed }
                urls.append(url)
                pagesDone += group.count
                progress(Double(pagesDone) / Double(totalPages))
            }
            return ToolOutput(directory: folder, files: urls)
        }
    }
}
