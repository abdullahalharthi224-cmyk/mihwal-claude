import Foundation
import PDFKit

/// Turns chosen pages by multiples of 90°. Only the page's /Rotate value changes,
/// so nothing is re-drawn and quality is untouched.
struct RotatePagesEngine: FileTool {
    struct Options: Sendable {
        /// Page index → degrees to add (multiples of 90, any sign).
        var rotations: [Int: Int]
    }

    static func normalized(_ degrees: Int) -> Int {
        ((degrees % 360) + 360) % 360
    }

    func run(input: ToolInput, options: Options,
             progress: @escaping @Sendable (Double) -> Void) async throws -> ToolOutput {
        guard let file = input.files.first else { throw ToolError.noInput }
        let changes = options.rotations
            .mapValues(Self.normalized)
            .filter { $0.value != 0 }
            .sorted { $0.key < $1.key }
        guard !changes.isEmpty else {
            throw ToolError.nothingToDo(reason: String(localized: "Choose pages and a direction to rotate."))
        }

        let document = try PDFLoader.open(file, password: input.password(for: file))
        for (done, change) in changes.enumerated() {
            try Task.checkCancellation()
            guard let page = document.page(at: change.key) else { continue }
            page.rotation = Self.normalized(page.rotation + change.value)
            progress(Double(done + 1) / Double(changes.count) * 0.8)
        }

        try Task.checkCancellation()
        return try FileStore.withOutputDirectory { folder -> ToolOutput in
            let url = FileStore.outputURL(in: folder, baseName: file.baseName,
                                          suffix: String(localized: "rotated"), pathExtension: "pdf")
            try PDFLoader.write(document, to: url, estimatedBytes: file.byteCount)
            progress(1)
            return ToolOutput(directory: folder, files: [url])
        }
    }
}
