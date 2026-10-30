import Foundation
import Observation

@MainActor
@Observable
final class ResizeImageViewModel {
    enum ModeKind: Hashable {
        case percent
        case longestSide
    }

    static let sidePresets = [1080, 1280, 1920, 2560, 3840]

    let files: FileListModel
    let runner = ToolRunner()
    var modeKind: ModeKind = .percent
    var percent = 50
    var longestSide = 1920
    var removeLocation = true
    private let engine = ResizeImageEngine()

    init(initialFiles: [ImportedFile]) {
        files = FileListModel(accepts: [.image], allowsMultiple: true, initial: initialFiles)
    }

    var isReady: Bool { !files.files.isEmpty }

    var mode: ResizeImageEngine.Mode {
        modeKind == .percent ? .percent(percent) : .longestSide(longestSide)
    }

    /// "4032 × 3024 → 2016 × 1512" for the first image, so the effect is clear before running.
    var firstImagePreview: (before: String, after: String)? {
        guard let file = files.files.first, let opened = try? ImageReader.open(file) else { return nil }
        let info = opened.info
        let target = ResizeImageEngine.targetLongestSide(for: info, mode: mode)
        let scale = Double(target) / Double(info.longestSide)
        let newWidth = max(1, Int((Double(info.width) * scale).rounded()))
        let newHeight = max(1, Int((Double(info.height) * scale).rounded()))
        return ("\(info.width) × \(info.height)", "\(newWidth) × \(newHeight)")
    }

    func run() {
        runner.run(engine, input: files.input, options: .init(mode: mode, removeLocation: removeLocation))
    }
}
